import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/ms_sd_record_model.dart';
import '../models/project_model.dart';
import '../models/user_model.dart';
import '../services/storage_service.dart';
import '../utils/image_upload_compress.dart';
import '../utils/ms_sd_file_limits.dart';
import '../utils/open_stored_attachment.dart';

/// MS-SD: Document Controller يرفع، الباقي يعرض فقط، المسؤول المحدد يعدّل/يحذف.
class MsSdScreen extends StatefulWidget {
  final UserModel currentUser;

  const MsSdScreen({super.key, required this.currentUser});

  @override
  State<MsSdScreen> createState() => _MsSdScreenState();
}

class _PickedFile {
  final String fileName;
  final String mime;
  final String dataUri;

  const _PickedFile({
    required this.fileName,
    required this.mime,
    required this.dataUri,
  });

  Map<String, String> toPayload() => {
        'fileName': fileName,
        'fileMime': mime,
        'fileData': dataUri,
      };
}

class _MsSdScreenState extends State<MsSdScreen> {
  final _db = getStorage();
  List<ProjectModel> _projects = [];
  ProjectModel? _project;
  String? _kind;
  List<MsSdRecordModel> _records = [];
  bool _loading = false;
  String? _loadError;

  bool get _canUpload => widget.currentUser.canUploadMsSd;
  bool get _showAudit => widget.currentUser.canManageMsSdRecords;

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
      _showError('تعذر تحميل المشاريع: $e');
    }
  }

  Future<void> _loadRecords() async {
    if (_project == null || _kind == null) {
      setState(() {
        _records = [];
        _loadError = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final list = await _db.listMsSdRecords(
        projectId: _project!.id,
        kind: _kind!,
        requesterEmail: widget.currentUser.email,
      ) as List<MsSdRecordModel>;
      if (!mounted) return;
      setState(() {
        _records = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _records = [];
        _loading = false;
        _loadError = e.toString();
      });
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  String _formatAuditDate(DateTime? dt) {
    if (dt == null) return '';
    return DateFormat('yyyy-MM-dd HH:mm', 'ar').format(dt.toLocal());
  }

  Future<List<_PickedFile>> _pickAttachments({List<_PickedFile>? existing}) async {
    final result = await FilePicker.pickFiles(
      type: FileType.any,
      withData: true,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) {
      return existing ?? [];
    }
    final out = <_PickedFile>[...(existing ?? [])];
    for (final f in result.files) {
      final bytes = f.bytes;
      if (bytes == null) continue;
      if (!msSdFileWithinLimit(bytes.length)) {
        _showError(
          'الملف "${f.name}" يتجاوز الحد الأقصى (${msSdMaxFileSizeLabel()})',
        );
        continue;
      }
      final prep = prepareImageForUpload(bytes: bytes, fileName: f.name);
      if (!msSdFileWithinLimit(prep.bytes.length)) {
        _showError(
          'الملف "${prep.fileName}" يتجاوز الحد الأقصى (${msSdMaxFileSizeLabel()})',
        );
        continue;
      }
      out.add(
        _PickedFile(
          fileName: prep.fileName,
          mime: prep.mime,
          dataUri: 'data:${prep.mime};base64,${base64Encode(prep.bytes)}',
        ),
      );
    }
    return out;
  }

  Future<void> _showAddRecordForm() async {
    if (_project == null || _kind == null) return;
    final nameC = TextEditingController();
    final notesC = TextEditingController();
    var picked = <_PickedFile>[];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'إضافة ${MsSdRecordModel.kindLabel(_kind!)} جديد',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameC,
                      decoration: const InputDecoration(
                        labelText: 'اسم الملف *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.attach_file),
                      label: Text(
                        picked.isEmpty
                            ? 'إرفاق ملف أو أكثر *'
                            : 'تم اختيار ${picked.length} ملف — إضافة المزيد',
                      ),
                      onPressed: () async {
                        final next = await _pickAttachments(existing: picked);
                        setSheet(() => picked = next);
                      },
                    ),
                    if (picked.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ...picked.asMap().entries.map(
                        (entry) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.insert_drive_file_outlined),
                          title: Text(
                            entry.value.fileName,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () {
                              setSheet(() {
                                picked = [
                                  for (var i = 0; i < picked.length; i++)
                                    if (i != entry.key) picked[i],
                                ];
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesC,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات (اختياري)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('حفظ'),
                      onPressed: () async {
                        final name = nameC.text.trim();
                        if (name.isEmpty) {
                          _showError('اسم الملف إلزامي');
                          return;
                        }
                        if (picked.isEmpty) {
                          _showError('يجب إرفاق ملف واحد على الأقل');
                          return;
                        }
                        Navigator.pop(ctx);
                        setState(() => _loading = true);
                        try {
                          await _db.addMsSdRecord(
                            projectId: _project!.id,
                            userId: widget.currentUser.id,
                            userName: widget.currentUser.name,
                            kind: _kind!,
                            recordName: name,
                            notes: notesC.text.trim().isEmpty
                                ? null
                                : notesC.text.trim(),
                            attachments: picked.map((e) => e.toPayload()).toList(),
                          );
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم الحفظ'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          await _loadRecords();
                        } catch (e) {
                          if (!mounted) return;
                          setState(() => _loading = false);
                          _showError('تعذر الحفظ: $e');
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteRecord(MsSdRecordModel record) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text(
          'هل تريد حذف السجل "${record.recordName}" وجميع مرفقاته نهائياً؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _loading = true);
    try {
      await _db.deleteMsSdRecord(
        record.id,
        requesterEmail: widget.currentUser.email,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم الحذف'), backgroundColor: Colors.green),
      );
      await _loadRecords();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('تعذر الحذف: $e');
    }
  }

  Future<void> _showEditRecordForm(MsSdRecordModel record) async {
    final nameC = TextEditingController(text: record.recordName);
    final notesC = TextEditingController(text: record.notes ?? '');
    final removeIds = <int>{};
    var newFiles = <_PickedFile>[];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final keptCount =
                record.attachments.where((a) => !removeIds.contains(a.id)).length;
            final totalCount = keptCount + newFiles.length;
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'تعديل السجل',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameC,
                      decoration: const InputDecoration(
                        labelText: 'اسم الملف',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'المرفقات الحالية',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    ...record.attachments.map((att) {
                      final marked = removeIds.contains(att.id);
                      return CheckboxListTile(
                        value: !marked,
                        onChanged: (v) {
                          setSheet(() {
                            if (v == true) {
                              removeIds.remove(att.id);
                            } else {
                              removeIds.add(att.id);
                            }
                          });
                        },
                        title: Text(
                          att.fileName,
                          style: TextStyle(
                            decoration:
                                marked ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        subtitle: marked ? const Text('سيُحذف عند الحفظ') : null,
                        secondary: const Icon(Icons.insert_drive_file_outlined),
                      );
                    }),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('إضافة مرفقات جديدة'),
                      onPressed: () async {
                        final next = await _pickAttachments(existing: newFiles);
                        setSheet(() => newFiles = next);
                      },
                    ),
                    if (newFiles.isNotEmpty)
                      ...newFiles.map(
                        (p) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.upload_file),
                          title: Text('جديد: ${p.fileName}'),
                        ),
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesC,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('حفظ التعديلات'),
                      onPressed: totalCount == 0
                          ? null
                          : () async {
                              final name = nameC.text.trim();
                              if (name.isEmpty) {
                                _showError('اسم الملف إلزامي');
                                return;
                              }
                              Navigator.pop(ctx);
                              setState(() => _loading = true);
                              try {
                                await _db.updateMsSdRecord(
                                  record.id,
                                  requesterEmail: widget.currentUser.email,
                                  recordName: name,
                                  notes: notesC.text.trim(),
                                  removeAttachmentIds:
                                      removeIds.isEmpty ? null : removeIds.toList(),
                                  addAttachments: newFiles.isEmpty
                                      ? null
                                      : newFiles.map((e) => e.toPayload()).toList(),
                                );
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('تم التحديث'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                await _loadRecords();
                              } catch (e) {
                                if (!mounted) return;
                                setState(() => _loading = false);
                                _showError('تعذر التحديث: $e');
                              }
                            },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openAttachment(MsSdAttachmentModel att) async {
    try {
      var data = att.fileData;
      Uint8List bytes;
      if (data.startsWith('data:')) {
        final comma = data.indexOf(',');
        final b64 = comma >= 0 ? data.substring(comma + 1) : data;
        bytes = base64Decode(b64);
      } else {
        bytes = base64Decode(data);
      }
      final err = await openStoredAttachment(
        bytes: bytes,
        fileName: att.fileName,
        dataUrl: att.fileData,
      );
      if (err != null && mounted) _showError(err);
    } catch (e) {
      _showError('تعذر فتح الملف: $e');
    }
  }

  Widget _buildRecordCard(MsSdRecordModel record) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  record.kind == MsSdRecordModel.kindSd
                      ? Icons.architecture_outlined
                      : Icons.inventory_2_outlined,
                  color: const Color(0xFF1B5E20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.recordName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (record.notes != null && record.notes!.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            record.notes!,
                            style: TextStyle(color: Colors.grey.shade800),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${record.attachments.length} مرفق',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (_showAudit) ...[
                        const SizedBox(height: 6),
                        Text(
                          'أضافه: ${record.userName ?? '—'} — ${_formatAuditDate(record.createdAt)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blueGrey.shade700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_showAudit)
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') _showEditRecordForm(record);
                      if (v == 'delete') _confirmDeleteRecord(record);
                    },
                    itemBuilder: (ctx) => const [
                      PopupMenuItem(value: 'edit', child: Text('تعديل')),
                      PopupMenuItem(value: 'delete', child: Text('حذف السجل')),
                    ],
                  ),
              ],
            ),
            const Divider(height: 20),
            Text(
              'المرفقات',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: record.attachments.map((att) {
                return ActionChip(
                  avatar: const Icon(Icons.attach_file, size: 18),
                  label: Text(
                    att.fileName,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: () => _openAttachment(att),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kindLabel =
        _kind != null ? MsSdRecordModel.kindLabel(_kind!) : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MS-SD'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: _canUpload && _project != null && _kind != null
          ? FloatingActionButton.extended(
              onPressed: _showAddRecordForm,
              icon: const Icon(Icons.add),
              label: Text('إضافة $kindLabel'),
              backgroundColor: const Color(0xFF1B5E20),
            )
          : null,
      body: _loading && _projects.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadRecords,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    _canUpload
                        ? 'تقديم الخامات والرسومات التنفيذية — إضافة سجلات جديدة'
                        : 'عرض سجلات MS-SD المرفوعة من Document Controller',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
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
                    onChanged: (p) {
                      setState(() {
                        _project = p;
                        _kind = null;
                        _records = [];
                      });
                    },
                  ),
                  if (_project != null) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(
                              child: Text(
                                'MS',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            selected: _kind == MsSdRecordModel.kindMs,
                            onSelected: (_) {
                              setState(() => _kind = MsSdRecordModel.kindMs);
                              _loadRecords();
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(
                              child: Text(
                                'SD',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            selected: _kind == MsSdRecordModel.kindSd,
                            onSelected: (_) {
                              setState(() => _kind = MsSdRecordModel.kindSd);
                              _loadRecords();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_project != null && _kind != null) ...[
                    const SizedBox(height: 16),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_loadError != null)
                      Card(
                        color: Colors.red.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'تعذر تحميل السجلات: $_loadError',
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      )
                    else if (_records.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Icon(
                                Icons.folder_open,
                                size: 48,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'لا توجد سجلات $kindLabel لهذا المشروع بعد',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                              if (_canUpload) ...[
                                const SizedBox(height: 8),
                                const Text(
                                  'اضغط «إضافة» لإنشاء أول سجل',
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    else
                      ..._records.map(_buildRecordCard),
                  ],
                ],
              ),
            ),
    );
  }
}
