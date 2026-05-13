import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/ir_mir_upload_model.dart';
import '../models/project_location_model.dart';
import '../models/project_model.dart';
import '../models/user_model.dart';
import '../services/storage_service.dart';
import '../utils/image_upload_compress.dart';

/// IR-MIR: مهندس موقع يرفع، المدير/المسؤول/مدير العمليات يعرضون.
class IrMirScreen extends StatefulWidget {
  final UserModel currentUser;

  const IrMirScreen({super.key, required this.currentUser});

  @override
  State<IrMirScreen> createState() => _IrMirScreenState();
}

class _IrMirScreenState extends State<IrMirScreen> {
  final _db = getStorage();
  List<ProjectModel> _projects = [];
  ProjectModel? _project;
  String? _branch;

  List<ProjectLocationModel> _locations = [];
  final List<int> _folderPath = [];

  bool _loading = false;

  bool get _viewerMode =>
      !widget.currentUser.isSiteEngineer &&
      (widget.currentUser.isManager || widget.currentUser.isAdmin);

  int? get _currentParentId =>
      _folderPath.isEmpty ? null : _folderPath.last;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() => _loading = true);
    try {
      final list = await _db.getProjects() as List<ProjectModel>;
      if (!mounted) return;
      setState(() {
        _projects = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحميل المشاريع: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _onProjectChanged(ProjectModel? p) async {
    setState(() {
      _project = p;
      _branch = null;
      _folderPath.clear();
      _locations = [];
    });
    if (p == null) return;
    setState(() => _loading = true);
    try {
      final locs = await _db.getProjectLocations(p.id) as List<ProjectLocationModel>;
      if (!mounted) return;
      setState(() {
        _locations = locs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحميل الهيكلة: $e'), backgroundColor: Colors.red),
      );
    }
  }

  List<ProjectLocationModel> _childrenOf(int? parentId) {
    final c = _locations.where((e) => e.parentId == parentId).toList();
    c.sort((a, b) {
      final o = a.displayOrder.compareTo(b.displayOrder);
      if (o != 0) return o;
      return a.name.compareTo(b.name);
    });
    return c;
  }

  String _locationPath(ProjectLocationModel loc) {
    final path = <String>[loc.name];
    var current = loc;
    while (current.parentId != null) {
      final parents = _locations.where((e) => e.id == current.parentId).toList();
      if (parents.isEmpty) break;
      final parent = parents.first;
      path.insert(0, parent.name);
      current = parent;
    }
    return path.join(' / ');
  }

  String _mimeFromFileName(String name, {required bool imageOnly}) {
    final ext = name.split('.').last.toLowerCase();
    if (imageOnly) {
      switch (ext) {
        case 'png':
          return 'image/png';
        case 'gif':
          return 'image/gif';
        case 'webp':
          return 'image/webp';
        default:
          return 'image/jpeg';
      }
    }
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _maybeWarnExisting({
    required bool hasExisting,
    required String message,
  }) async {
    if (!hasExisting || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 4),
        backgroundColor: const Color(0xFF5D4037),
      ),
    );
  }

  Future<void> _saveMir({
    required String mirName,
    required String fileDataUri,
    required String fileName,
    required String fileMime,
    String? notes,
  }) async {
    if (_project == null) return;
    final existing = await _db.listIrMirUploads(
      projectId: _project!.id,
      kind: IrMirUploadModel.kindMir,
      mirName: mirName,
    ) as List<IrMirUploadModel>;
    await _maybeWarnExisting(
      hasExisting: existing.isNotEmpty,
      message:
          'تنبيه: تم إرفاق ملف مسبقاً لهذا الـ MIR في هذا المشروع. سيتم إضافة الملف الحالي كإرفاق إضافي.',
    );
    await _db.addIrMirUpload(
      projectId: _project!.id,
      userId: widget.currentUser.id,
      userName: widget.currentUser.name,
      kind: IrMirUploadModel.kindMir,
      mirName: mirName.trim(),
      fileName: fileName,
      fileMime: fileMime,
      fileData: fileDataUri,
      notes: notes,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم الحفظ'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _saveIr({
    required ProjectLocationModel loc,
    required String phase,
    required String fileDataUri,
    required String fileName,
    required String fileMime,
    String? notes,
  }) async {
    if (_project == null) return;
    final existing = await _db.listIrMirUploads(
      projectId: _project!.id,
      kind: IrMirUploadModel.kindIr,
      locationId: loc.id,
      phase: phase,
    ) as List<IrMirUploadModel>;
    await _maybeWarnExisting(
      hasExisting: existing.isNotEmpty,
      message:
          'تنبيه: تم إرفاق ملف مسبقاً لهذا الموقع والمرحلة. سيتم إضافة الملف الحالي كإرفاق إضافي.',
    );
    await _db.addIrMirUpload(
      projectId: _project!.id,
      userId: widget.currentUser.id,
      userName: widget.currentUser.name,
      kind: IrMirUploadModel.kindIr,
      locationId: loc.id,
      phase: phase,
      fileName: fileName,
      fileMime: fileMime,
      fileData: fileDataUri,
      notes: notes,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم الحفظ'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _showMirForm() async {
    final nameC = TextEditingController();
    final notesC = TextEditingController();
    String? dataUri;
    String? pickedName;
    String? pickedMime;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('إرفاق MIR جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameC,
                  decoration: const InputDecoration(labelText: 'اسم الـ MIR'),
                  textDirection: TextDirection.ltr,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.attach_file),
                  label: Text(dataUri == null ? 'إرفاق مستند أو صورة (إلزامي)' : pickedName ?? 'تم اختيار ملف'),
                  onPressed: () async {
                    final result = await FilePicker.pickFiles(
                      type: FileType.any,
                      withData: true,
                      allowMultiple: false,
                    );
                    if (result == null || result.files.isEmpty) return;
                    final f = result.files.single;
                    final bytes = f.bytes;
                    if (bytes == null) return;
                    final prep = prepareImageForUpload(bytes: bytes, fileName: f.name);
                    final uri =
                        'data:${prep.mime};base64,${base64Encode(prep.bytes)}';
                    setD(() {
                      dataUri = uri;
                      pickedName = prep.fileName;
                      pickedMime = prep.mime;
                    });
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesC,
                  decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () async {
                final n = nameC.text.trim();
                if (n.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('أدخل اسم الـ MIR')),
                  );
                  return;
                }
                if (dataUri == null || dataUri!.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('إرفاق ملف إلزامي')),
                  );
                  return;
                }
                final fn = (pickedName ?? 'file').trim();
                final mime = pickedMime ?? _mimeFromFileName(fn, imageOnly: false);
                Navigator.pop(ctx);
                try {
                  await _saveMir(
                    mirName: n,
                    fileDataUri: dataUri!,
                    fileName: fn,
                    fileMime: mime,
                    notes: notesC.text.trim().isEmpty ? null : notesC.text.trim(),
                  );
                  if (mounted) setState(() {});
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('فشل الحفظ: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openIrUploadDialog(ProjectLocationModel loc) async {
    String? phase = IrMirUploadModel.phaseFirstFix;
    String? dataUri;
    String? pickedName;
    String? pickedMime;
    final notesC = TextEditingController();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('IR — ${_locationPath(loc)}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('المرحلة', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: IrMirUploadModel.irPhases.map((p) {
                    final sel = phase == p;
                    return ChoiceChip(
                      label: Text(IrMirUploadModel.phaseLabelAr(p)),
                      selected: sel,
                      onSelected: (_) => setD(() => phase = p),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  icon: const Icon(Icons.attach_file),
                  label: Text(dataUri == null ? 'إرفاق مستند أو صورة (إلزامي)' : (pickedName ?? 'ملف')),
                  onPressed: () async {
                    final result = await FilePicker.pickFiles(
                      type: FileType.any,
                      withData: true,
                      allowMultiple: false,
                    );
                    if (result == null || result.files.isEmpty) return;
                    final f = result.files.single;
                    final bytes = f.bytes;
                    if (bytes == null) return;
                    final prep = prepareImageForUpload(bytes: bytes, fileName: f.name);
                    final uri =
                        'data:${prep.mime};base64,${base64Encode(prep.bytes)}';
                    setD(() {
                      dataUri = uri;
                      pickedName = prep.fileName;
                      pickedMime = prep.mime;
                    });
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesC,
                  decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () async {
                if (phase == null || phase!.isEmpty) return;
                if (dataUri == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('إرفاق ملف إلزامي')),
                  );
                  return;
                }
                final fn = (pickedName ?? 'file').trim();
                final mime = pickedMime ?? _mimeFromFileName(fn, imageOnly: false);
                Navigator.pop(ctx);
                try {
                  await _saveIr(
                    loc: loc,
                    phase: phase!,
                    fileDataUri: dataUri!,
                    fileName: fn,
                    fileMime: mime,
                    notes: notesC.text.trim().isEmpty ? null : notesC.text.trim(),
                  );
                  if (mounted) setState(() {});
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('فشل الحفظ: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _engineerIrTree() {
    final children = _childrenOf(_currentParentId);
    if (children.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('لا توجد عناصر في هذا المستوى. تأكد من هيكلة المشروع.'),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: children.length,
      itemBuilder: (context, i) {
        final node = children[i];
        void openIr() => _openIrUploadDialog(node);
        if (node.isFolder) {
          return ListTile(
            leading: const Icon(Icons.folder),
            title: Text(node.name),
            subtitle: Text(
              '${_locationPath(node)}\nاضغط للدخول للمستوى الأدنى، أو زر «إرفاق» لرفع IR لهذا المستوى (مثل فيلا أو شيد).',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.attach_file),
              tooltip: 'إرفاق IR لهذا المستوى',
              onPressed: openIr,
            ),
            onTap: () => setState(() => _folderPath.add(node.id)),
          );
        }
        return ListTile(
          leading: const Icon(Icons.location_on),
          title: Text(node.name),
          subtitle: Text(_locationPath(node), maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: IconButton(
            icon: const Icon(Icons.attach_file),
            tooltip: 'إرفاق IR',
            onPressed: openIr,
          ),
          onTap: openIr,
        );
      },
    );
  }

  Widget _viewerMirList() {
    return FutureBuilder<List<IrMirUploadModel>>(
      future: _project == null
          ? Future.value(const [])
          : Future(() async {
              final raw = await _db.listIrMirUploads(
                projectId: _project!.id,
                kind: IrMirUploadModel.kindMir,
              );
              return List<IrMirUploadModel>.from(raw as List);
            }),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ));
        }
        final list = snap.data ?? [];
        if (list.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('لا توجد مرفقات MIR لهذا المشروع.'),
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: list.length,
          itemBuilder: (context, i) => _uploadCard(list[i]),
        );
      },
    );
  }

  bool _isImageAttachment(IrMirUploadModel u) {
    final d = u.fileData.trim();
    if (d.startsWith('data:image/')) return true;
    return u.fileMime.toLowerCase().startsWith('image/');
  }

  Uint8List? _bytesFromDataUrl(String data) {
    final i = data.indexOf(',');
    if (i < 0 || i >= data.length - 1) return null;
    try {
      return base64Decode(data.substring(i + 1));
    } catch (_) {
      return null;
    }
  }

  void _showImagePreview(IrMirUploadModel u, Uint8List bytes) {
    showDialog<void>(
      context: context,
      useSafeArea: true,
      barrierDismissible: true,
      builder: (ctx) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(
            u.fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            IconButton(
              tooltip: 'فتح خارج التطبيق',
              icon: const Icon(Icons.open_in_new),
              onPressed: () => _openAttachment(u),
            ),
            IconButton(
              tooltip: 'إغلاق',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        body: Center(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4,
            child: Image.memory(bytes, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteUpload(IrMirUploadModel u) async {
    if (!widget.currentUser.canDeleteIrMirAttachments) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المرفق'),
        content: Text(
          'حذف «${u.fileName}» نهائياً؟\nلا يمكن التراجع.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _db.deleteIrMirUpload(
        u.id,
        requesterEmail: widget.currentUser.email,
      );
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف المرفق'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر الحذف: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _uploadCard(IrMirUploadModel u) {
    final imageBytes =
        _isImageAttachment(u) ? _bytesFromDataUrl(u.fileData) : null;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (imageBytes != null)
            Material(
              color: Colors.grey.shade200,
              child: InkWell(
                onTap: () => _showImagePreview(u, imageBytes),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.memory(
                    imageBytes,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => const Center(
                      child: Icon(Icons.broken_image, size: 48),
                    ),
                  ),
                ),
              ),
            ),
          ListTile(
            title: Text(u.fileName, textDirection: TextDirection.ltr),
            subtitle: Text(
              '${u.userName} — ${u.createdAt.toString().substring(0, 16)}\n'
              '${u.kind == IrMirUploadModel.kindMir ? (u.mirName ?? '') : IrMirUploadModel.phaseLabelAr(u.phase ?? '')}'
              '${imageBytes != null ? '\nاضغط على الصورة للمعاينة والتكبير' : ''}',
            ),
            onTap: imageBytes != null
                ? () => _showImagePreview(u, imageBytes)
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.currentUser.canDeleteIrMirAttachments)
                  IconButton(
                    tooltip: 'حذف المرفق',
                    icon: Icon(Icons.delete_outline, color: Colors.red.shade700),
                    onPressed: () => _confirmDeleteUpload(u),
                  ),
                IconButton(
                  tooltip: 'فتح خارج التطبيق',
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () => _openAttachment(u),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAttachment(IrMirUploadModel u) async {
    final uri = Uri.tryParse(u.fileData);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, webOnlyWindowName: '_blank');
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح الملف')),
      );
    }
  }

  Widget _viewerIrAtWorkSite(ProjectLocationModel loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: IrMirUploadModel.irPhases.map((ph) {
        return FutureBuilder<List<IrMirUploadModel>>(
          future: Future(() async {
            final raw = await _db.listIrMirUploads(
              projectId: _project!.id,
              kind: IrMirUploadModel.kindIr,
              locationId: loc.id,
              phase: ph,
            );
            return List<IrMirUploadModel>.from(raw as List);
          }),
          builder: (context, snap) {
            final list = snap.data ?? [];
            return ExpansionTile(
              title: Text(IrMirUploadModel.phaseLabelAr(ph)),
              subtitle: Text('${list.length} مرفق'),
              children: list.isEmpty
                  ? [
                      const ListTile(
                        title: Text('لا مرفقات'),
                      ),
                    ]
                  : list.map((u) => _uploadCard(u)).toList(),
            );
          },
        );
      }).toList(),
    );
  }

  Widget _viewerIrTree() {
    final children = _childrenOf(_currentParentId);
    if (children.isEmpty) {
      return const Text('لا عناصر');
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: children.length,
      itemBuilder: (context, i) {
        final node = children[i];
        if (node.isFolder) {
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  leading: const Icon(Icons.folder),
                  title: Text(node.name),
                  subtitle: Text(
                    '${_locationPath(node)}\nاضغط للدخول إلى المستويات الأدنى',
                    maxLines: 3,
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => setState(() => _folderPath.add(node.id)),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: _viewerIrAtWorkSite(node),
                ),
              ],
            ),
          );
        }
        return ExpansionTile(
          leading: const Icon(Icons.location_on),
          title: Text(node.name),
          subtitle: Text(_locationPath(node), maxLines: 2),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _viewerIrAtWorkSite(node),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IR-MIR'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: _loading && _projects.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _viewerMode
                        ? 'عرض المرفقات من مهندسي المواقع'
                        : 'رفع MIR / IR (يمكن رفع IR لأي مستوى: فيلا، شيد، موقع عمل…)',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ProjectModel>(
                    value: _project,
                    decoration: const InputDecoration(
                      labelText: 'المشروع',
                      border: OutlineInputBorder(),
                    ),
                    items: _projects
                        .map(
                          (p) => DropdownMenuItem(
                            value: p,
                            child: Text(p.name, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: (p) => _onProjectChanged(p),
                  ),
                  if (_project != null) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('MIR'),
                          selected: _branch == 'mir',
                          onSelected: (_) => setState(() {
                            _branch = 'mir';
                            _folderPath.clear();
                          }),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('IR'),
                          selected: _branch == 'ir',
                          onSelected: (_) => setState(() {
                            _branch = 'ir';
                            _folderPath.clear();
                          }),
                        ),
                      ],
                    ),
                  ],
                  if (_project != null && _branch == 'mir') ...[
                    const SizedBox(height: 16),
                    if (_viewerMode)
                      _viewerMirList()
                    else
                      FilledButton.icon(
                        onPressed: _showMirForm,
                        icon: const Icon(Icons.add),
                        label: const Text('إرفاق MIR جديد'),
                      ),
                  ],
                  if (_project != null && _branch == 'ir') ...[
                    const SizedBox(height: 8),
                    if (_folderPath.isNotEmpty)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => setState(() => _folderPath.removeLast()),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('رجوع للمستوى الأعلى'),
                        ),
                      ),
                    if (_viewerMode)
                      _viewerIrTree()
                    else
                      _engineerIrTree(),
                  ],
                ],
              ),
            ),
    );
  }
}
