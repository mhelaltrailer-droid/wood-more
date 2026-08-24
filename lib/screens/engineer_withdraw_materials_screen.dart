import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../models/user_model.dart';
import '../models/project_model.dart';
import '../models/project_location_model.dart';
import '../models/location_material_model.dart';
import '../models/location_withdrawal_model.dart';
import '../models/project_stock_model.dart';
import '../models/withdrawal_request_model.dart';
import '../services/project_warehouse_loading.dart';
import '../services/storage_service.dart';
import '../services/withdrawal_stock_validation.dart';
import '../services/route_persistence.dart';
import '../utils/disbursement_note_pdf.dart';
import 'home_screen.dart';
import 'withdrawal_balance_review_screen.dart';

/// المخزن (سحب خامات) — لمهندس الموقع: عرض الخامات المتاحة لكل مكان فرعي وسحبها مرة واحدة مع أذن صرف وتسليم
class EngineerWithdrawMaterialsScreen extends StatefulWidget {
  final UserModel user;

  /// فتح الشاشة مباشرة على مشروع وموقع فرعي محددين (من إشعار الموافقة).
  final int? initialProjectId;
  final int? initialLocationId;

  const EngineerWithdrawMaterialsScreen({
    super.key,
    required this.user,
    this.initialProjectId,
    this.initialLocationId,
  });

  @override
  State<EngineerWithdrawMaterialsScreen> createState() => _EngineerWithdrawMaterialsScreenState();
}

class _EngineerWithdrawMaterialsScreenState extends State<EngineerWithdrawMaterialsScreen>
    with WidgetsBindingObserver {
  final _db = getStorage();
  List<ProjectModel> _projects = [];
  ProjectModel? _selectedProject;
  List<ProjectLocationModel> _allLocations = [];
  Map<String, List<LocationMaterialModel>> _materialsByLocationPhase = {};
  Map<String, LocationWithdrawalModel?> _withdrawalByLocationPhase = {};
  Map<String, WithdrawalRequestModel> _withdrawalRequestByKey = {};
  bool _loading = false;
  bool _warehouseLoading = false;
  String? _loadError;
  int _loadToken = 0;
  Timer? _pollTimer;
  final GlobalKey _targetLocationKey = GlobalKey();
  bool _didScrollToTarget = false;

  String _k(int locationId, String phase) =>
      warehouseLocationPhaseKey(locationId, phase);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadProjects();
    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (_selectedProject != null && mounted) {
        _refreshWithdrawalRequestsOnly();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _selectedProject == null) return;
    if (_warehouseLoading || _loadError == null) return;
    _loadLocationsAndMaterials();
  }

  WithdrawalRequestModel? _requestFor(int locationId, String phase) =>
      _withdrawalRequestByKey[_k(locationId, phase)];

  Future<void> _refreshWithdrawalRequestsOnly() async {
    if (_selectedProject == null) return;
    try {
      final reqs = await _db.getWithdrawalRequestsForEngineerProject(
        projectId: _selectedProject!.id,
        engineerUserId: widget.user.id,
      );
      final map = <String, WithdrawalRequestModel>{};
      for (final r in reqs) {
        final key = _k(r.locationId, r.phase);
        final ex = map[key];
        if (ex == null || r.id > ex.id) {
          map[key] = r;
        }
      }
      if (mounted) setState(() => _withdrawalRequestByKey = map);
    } catch (_) {}
  }

  String _engineerRequestStatusLine(WithdrawalRequestModel r) {
    if (r.isRejectedOverall) {
      if (r.semStatus == WithdrawalRequestModel.statusRejected) {
        return 'تم رفض طلبك من ${UserModel.siteEngineerManagerRoleLabel} بسبب: ${r.semReason ?? '—'}';
      }
      return 'تم رفض طلبك من مدير العمليات بسبب: ${r.omReason ?? '—'}';
    }
    if (r.isApprovedOverall) return '';
    final lines = <String>['في انتظار الرد على طلبكم'];
    if (r.semStatus == WithdrawalRequestModel.statusApproved &&
        r.omStatus == WithdrawalRequestModel.statusPending) {
      lines.add('تمت موافقة ${UserModel.siteEngineerManagerRoleLabel} — بانتظار موافقة مدير العمليات');
    } else if (r.omStatus == WithdrawalRequestModel.statusApproved &&
        r.semStatus == WithdrawalRequestModel.statusPending) {
      lines.add('تمت موافقة مدير العمليات — بانتظار موافقة ${UserModel.siteEngineerManagerRoleLabel}');
    }
    return lines.join('\n');
  }

  Future<void> _loadProjects() async {
    final list = await _db.getProjects();
    if (!mounted) return;
    final target = widget.initialProjectId;
    ProjectModel? preselected;
    if (target != null) {
      for (final p in list) {
        if (p.id == target) {
          preselected = p;
          break;
        }
      }
    }
    setState(() {
      _projects = list;
      if (preselected != null) _selectedProject = preselected;
    });
    if (preselected != null) await _loadLocationsAndMaterials();
  }

  void _scrollToTargetLocationOnce() {
    if (widget.initialLocationId == null || _didScrollToTarget) return;
    _didScrollToTarget = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _targetLocationKey.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 400),
        alignment: 0.1,
      );
    });
  }

  Future<void> _loadLocationsAndMaterials() async {
    if (_selectedProject == null) {
      setState(() {
        _allLocations = [];
        _materialsByLocationPhase = {};
        _withdrawalByLocationPhase = {};
        _withdrawalRequestByKey = {};
        _loadError = null;
      });
      return;
    }
    final loadToken = ++_loadToken;
    setState(() {
      _warehouseLoading = true;
      _loadError = null;
      _allLocations = [];
      _materialsByLocationPhase = {};
      _withdrawalByLocationPhase = {};
      _withdrawalRequestByKey = {};
    });
    try {
      final projectId = _selectedProject!.id;
      final snapshot = await loadProjectWarehouseSnapshot(_db, projectId);
      if (!mounted || loadToken != _loadToken) return;
      final Map<String, WithdrawalRequestModel> reqMap = {};
      try {
        final reqs = await _db.getWithdrawalRequestsForEngineerProject(
          projectId: projectId,
          engineerUserId: widget.user.id,
        );
        for (final r in reqs) {
          final key = _k(r.locationId, r.phase);
          final ex = reqMap[key];
          if (ex == null || r.id > ex.id) {
            reqMap[key] = r;
          }
        }
      } catch (_) {}
      if (!mounted || loadToken != _loadToken) return;
      setState(() {
        _allLocations = snapshot.locations;
        _materialsByLocationPhase = snapshot.materialsByLocationPhase;
        _withdrawalByLocationPhase = snapshot.withdrawalByLocationPhase;
        _withdrawalRequestByKey = reqMap;
        _warehouseLoading = false;
        _loadError = null;
      });
      _scrollToTargetLocationOnce();
    } catch (e) {
      if (!mounted || loadToken != _loadToken) return;
      final message = warehouseLoadErrorMessage(e);
      setState(() {
        _warehouseLoading = false;
        _loadError = message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  List<ProjectLocationModel> _locationsWithMaterials() {
    return _allLocations
        .where(
          (loc) => LocationMaterialModel.phases.any(
            (p) => (_materialsByLocationPhase[_k(loc.id, p)] ?? []).isNotEmpty,
          ),
        )
        .toList();
  }

  String _locationPath(ProjectLocationModel loc) {
    final path = <String>[loc.name];
    var current = loc;
    while (current.parentId != null) {
      final parents = _allLocations.where((e) => e.id == current.parentId).toList();
      if (parents.isEmpty) break;
      final parent = parents.first;
      path.insert(0, parent.name);
      current = parent;
    }
    return path.join(' / ');
  }

  /// رقم الفيلا في PDF: المسار الكامل بشرطة مائلة (مثل T01-101/B3-1)
  String _villaNumberForPdf(ProjectLocationModel loc) {
    final path = <String>[loc.name];
    var current = loc;
    while (current.parentId != null) {
      final parents =
          _allLocations.where((e) => e.id == current.parentId).toList();
      if (parents.isEmpty) break;
      final parent = parents.first;
      path.insert(0, parent.name);
      current = parent;
    }
    return path.join('/');
  }

  List<String> _parseImageJson(String? jsonStr) {
    if (jsonStr == null || jsonStr.trim().isEmpty) return [];
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
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

  void _showMaterialsDialog({
    required String title,
    required String phaseLabel,
    required String villaName,
    required List<LocationMaterialModel> materials,
  }) {
    DateTime exportDate = DateTime.now();
    var exporting = false;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'المرحلة: $phaseLabel',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: materials.isEmpty
                          ? const Text('لا توجد خامات')
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: materials.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final m = materials[i];
                                return ListTile(
                                  dense: true,
                                  title: Text(m.materialName),
                                  trailing: Text('${m.quantity} ${m.unit}'),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('تاريخ التصدير'),
                      subtitle: Text(
                        DateFormat('yyyy/MM/dd').format(exportDate),
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: exporting
                          ? null
                          : () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: exportDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setLocal(() => exportDate = picked);
                              }
                            },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: exporting ? null : () => Navigator.pop(ctx),
                  child: const Text('إغلاق'),
                ),
                FilledButton.icon(
                  onPressed: materials.isEmpty || exporting
                      ? null
                      : () async {
                          setLocal(() => exporting = true);
                          try {
                            await _exportMaterialsPdf(
                              materials: materials,
                              villaName: villaName,
                              phaseLabel: phaseLabel,
                              date: exportDate,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('تعذر تصدير PDF: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } finally {
                            if (ctx.mounted) {
                              setLocal(() => exporting = false);
                            }
                          }
                        },
                  icon: exporting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf),
                  label: Text(exporting ? 'جاري التصدير…' : 'تصدير PDF'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _exportMaterialsPdf({
    required List<LocationMaterialModel> materials,
    required String villaName,
    required String phaseLabel,
    required DateTime date,
  }) async {
    final project = _selectedProject;
    if (project == null) return;
    final requestNumber =
        await _db.nextDisbursementNoteNumber() as String;
    final bytes = await buildDisbursementNotePdf(
      requestNumber: requestNumber,
      villaNumber: villaName,
      projectName: project.name,
      contractorName: project.mainContractor,
      date: date,
      lines: materials.map(DisbursementNoteLine.fromMaterial).toList(),
    );
    final safeVilla = villaName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final filename =
        'اذن_صرف_${safeVilla}_${phaseLabel}_${DateFormat('yyyyMMdd').format(date)}.pdf';
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }

  void _showPermitImagesDialog(String title, List<String> dataUrls) {
    if (dataUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('لا توجد صور مرفقة لـ $title')),
      );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 520,
          height: 560,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 0, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: dataUrls.length,
                  itemBuilder: (_, i) {
                    final bytes = _bytesFromDataUrl(dataUrls[i]);
                    if (bytes == null) {
                      return ListTile(
                        title: Text('صورة ${i + 1} — تعذر العرض'),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 3,
                        child: Image.memory(bytes, fit: BoxFit.contain),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitWithdrawalRequest(ProjectLocationModel loc, String phase) async {
    try {
      final open = await _db.getOpenWithdrawalRequestForLocationPhase(
        locationId: loc.id,
        phase: phase,
      );
      if (open != null && open.engineerUserId != widget.user.id) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يوجد طلب سحب قيد المراجعة لهذا الموقع من مهندس آخر.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    } catch (_) {}
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('طلب سحب خامات'),
        content: Text(
          'إرسال طلب إلى مدير العمليات و${UserModel.siteEngineerManagerRoleLabel} للموافقة على السحب من:\n${_locationPath(loc)}\nالمرحلة: ${LocationMaterialModel.phaseLabel(phase)}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إرسال الطلب')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _db.createWithdrawalRequest(
        projectId: loc.projectId,
        locationId: loc.id,
        phase: phase,
        engineerUserId: widget.user.id,
        engineerUserName: widget.user.name,
        locationPathLabel: _locationPath(loc),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال الطلب'), backgroundColor: Colors.green),
      );
      await _loadLocationsAndMaterials();
    } catch (e) {
      final msg = '$e';
      if (!mounted) return;
      if (msg.contains('existing_request_other_engineer')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يوجد طلب آخر قيد المراجعة لهذا الموقع.'),
            backgroundColor: Colors.red,
          ),
        );
      } else if (msg.contains('already_approved_complete_flow')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('طلبك معتمد — استخدم «إكمال سحب الخامات».'),
            backgroundColor: Color(0xFF5D4037),
          ),
        );
        await _loadLocationsAndMaterials();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر إرسال الطلب: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showWithdrawDialog(
    ProjectLocationModel loc,
    String phase, {
    required int withdrawalRequestId,
  }) async {
    List<String> disbursementImages = [];
    List<String> deliveryImages = [];

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('إكمال سحب الخامات'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('إرفاق أذن الصرف (صورة أو صورتين كحد أقصى)', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add_photo_alternate),
                      label: Text(disbursementImages.isEmpty ? 'إرفاق' : 'إضافة أخرى'),
                      onPressed: disbursementImages.length >= 2
                          ? null
                          : () async {
                              final picked = await _pickImageBase64();
                              if (picked != null && ctx.mounted) {
                                setDialog(() => disbursementImages = [...disbursementImages, picked]);
                              }
                            },
                    ),
                    if (disbursementImages.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text('${disbursementImages.length} صورة', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ],
                ),
                if (disbursementImages.isNotEmpty)
                  Wrap(
                    spacing: 4,
                    children: List.generate(disbursementImages.length, (i) => Chip(
                      label: Text('${i + 1}'),
                      deleteIcon: const Icon(Icons.close, size: 18),
                      onDeleted: () => setDialog(() => disbursementImages = List.from(disbursementImages)..removeAt(i)),
                    )),
                  ),
                const SizedBox(height: 16),
                const Text('إرفاق أذن التسليم (صورة أو صورتين كحد أقصى)', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add_photo_alternate),
                      label: Text(deliveryImages.isEmpty ? 'إرفاق' : 'إضافة أخرى'),
                      onPressed: deliveryImages.length >= 2
                          ? null
                          : () async {
                              final picked = await _pickImageBase64();
                              if (picked != null && ctx.mounted) {
                                setDialog(() => deliveryImages = [...deliveryImages, picked]);
                              }
                            },
                    ),
                    if (deliveryImages.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text('${deliveryImages.length} صورة', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ],
                ),
                if (deliveryImages.isNotEmpty)
                  Wrap(
                    spacing: 4,
                    children: List.generate(deliveryImages.length, (i) => Chip(
                      label: Text('${i + 1}'),
                      deleteIcon: const Icon(Icons.close, size: 18),
                      onDeleted: () => setDialog(() => deliveryImages = List.from(deliveryImages)..removeAt(i)),
                    )),
                  ),
                const SizedBox(height: 16),
                if (disbursementImages.isEmpty || deliveryImages.isEmpty)
                  Text('أذن الصرف وأذن التسليم إلزاميان (صورة أو صورتين لكل منهما)', style: TextStyle(fontSize: 12, color: Colors.orange[800])),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () async {
                if (disbursementImages.isEmpty || deliveryImages.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('يجب إرفاق أذن الصرف وأذن التسليم (صورة أو صورتين لكل منهما)')));
                  return;
                }
                final locationMaterials =
                    _materialsByLocationPhase[_k(loc.id, phase)] ?? [];
                final projectStock = coerceProjectStockList(
                  await _db.getProjectStock(loc.projectId),
                );
                if (!hasSufficientStockForWithdrawal(
                  locationMaterials: locationMaterials,
                  projectStock: projectStock,
                )) {
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text(withdrawalInsufficientStockMessage),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                if (!ctx.mounted) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('متابعة المراجعة والسحب'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);
    try {
      final locationMaterials = _materialsByLocationPhase[_k(loc.id, phase)] ?? [];
      final projectStock = coerceProjectStockList(await _db.getProjectStock(loc.projectId));
      if (!hasSufficientStockForWithdrawal(
        locationMaterials: locationMaterials,
        projectStock: projectStock,
      )) {
        if (!mounted) return;
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(withdrawalInsufficientStockMessage),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      final previewRows = buildWithdrawalPreviewRows(
        locationMaterials: locationMaterials,
        projectStock: projectStock,
      );

      if (!mounted) return;
      setState(() => _loading = false);

      final committed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => WithdrawalBalanceReviewScreen(
            withdrawnSnapshots: previewRows,
            projectId: loc.projectId,
            projectName: _selectedProject?.name ?? '',
            locationId: loc.id,
            phase: phase,
            userId: widget.user.id,
            userName: widget.user.name,
            disbursementPermitImagesJson: jsonEncode(disbursementImages),
            deliveryPermitImagesJson: jsonEncode(deliveryImages),
            withdrawalRequestId: withdrawalRequestId,
          ),
        ),
      );
      if (!mounted) return;
      if (committed == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم سحب الخامات وتسجيل العملية بنجاح'), backgroundColor: Colors.green),
        );
      }
      await _loadLocationsAndMaterials();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
    }
  }

  Future<String?> _pickImageBase64() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return null;
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) return null;
      final ext = (file.extension ?? 'jpg').toLowerCase();
      final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
      return 'data:$mime;base64,${base64Encode(bytes)}';
    } catch (_) {
      return null;
    }
  }

  Future<void> _showProjectWarehouseBalances() async {
    final project = _selectedProject;
    if (project == null) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('رصيد مخزن المشروع — ${project.name}'),
          content: SizedBox(
            width: double.maxFinite,
            child: FutureBuilder<List<ProjectStockModel>>(
              future: () async {
                final raw = await _db.getProjectStock(project.id);
                final list = coerceProjectStockList(raw)
                  ..sort((ProjectStockModel a, ProjectStockModel b) => a.materialName.compareTo(b.materialName));
                return list;
              }(),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Text('تعذر التحميل: ${snapshot.error}', style: const TextStyle(color: Colors.red));
                }
                final list = snapshot.data ?? [];
                if (list.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('لا توجد خامات مسجّلة في مخزن هذا المشروع.'),
                  );
                }
                return SizedBox(
                  height: 400,
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: list.length,
                    separatorBuilder: (_, i) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final s = list[i];
                      return ListTile(
                        dense: true,
                        title: Text(s.materialName, overflow: TextOverflow.ellipsis),
                        trailing: Text(
                          '${s.quantity} ${s.unit}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إغلاق'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final locationsWithMats = _locationsWithMaterials();

    return Scaffold(
      appBar: AppBar(
        title: const Text('المخزن (سحب خامات)'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            await saveLastRoute('home');
            if (!context.mounted) return;
            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => HomeScreen(currentUser: widget.user)));
          },
        ),
      ),
      body: Stack(
        children: [
          ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('اسم المهندس: ${widget.user.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    'السحب يتطلب موافقة مدير العمليات و${UserModel.siteEngineerManagerRoleLabel} معاً. ابدأ بـ «طلب سحب خامات» ثم بعد الاعتماد استخدم «إكمال سحب الخامات».',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<ProjectModel?>(
            value: _selectedProject,
            decoration: const InputDecoration(labelText: 'اسم المشروع', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem(value: null, child: Text('— اختر المشروع —')),
              ..._projects.map((p) => DropdownMenuItem(value: p, child: Text(p.name))),
            ],
            onChanged: (v) {
              setState(() => _selectedProject = v);
              _loadLocationsAndMaterials();
            },
          ),
          const SizedBox(height: 20),
          if (_warehouseLoading)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (_loadError != null)
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      _loadError!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red.shade900),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _loadLocationsAndMaterials,
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            )
          else if (_selectedProject != null && locationsWithMats.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('لا توجد أماكن فرعية لها خامات معينة للسحب في هذا المشروع. تواصل مع مسئول التطبيق لتعيين الخامات من "هيكلة المخازن".')),
              ),
            )
          else if (_selectedProject != null)
            ...locationsWithMats.map((loc) {
              final firstMats = _materialsByLocationPhase[_k(
                    loc.id,
                    LocationMaterialModel.phaseFirstFix,
                  )] ??
                  [];
              final secondMats = _materialsByLocationPhase[_k(
                    loc.id,
                    LocationMaterialModel.phaseSecondFix,
                  )] ??
                  [];
              final firstWithdrawal = _withdrawalByLocationPhase[_k(
                loc.id,
                LocationMaterialModel.phaseFirstFix,
              )];
              final secondWithdrawal = _withdrawalByLocationPhase[_k(
                loc.id,
                LocationMaterialModel.phaseSecondFix,
              )];
              final firstWr = _requestFor(loc.id, LocationMaterialModel.phaseFirstFix);
              final secondWr = _requestFor(loc.id, LocationMaterialModel.phaseSecondFix);
              final isTarget = widget.initialLocationId == loc.id;
              return Card(
                key: isTarget ? _targetLocationKey : null,
                margin: const EdgeInsets.only(bottom: 16),
                shape: isTarget
                    ? RoundedRectangleBorder(
                        side: const BorderSide(color: Color(0xFF1B5E20), width: 2),
                        borderRadius: BorderRadius.circular(12),
                      )
                    : null,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(_locationPath(loc), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      const Text('الخامات المتاحة للسحب حسب المرحلة:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 8),
                      _phaseBlock(
                        label: 'First-fix',
                        materials: firstMats,
                        withdrawal: firstWithdrawal,
                        wr: firstWr,
                        loc: loc,
                        phase: LocationMaterialModel.phaseFirstFix,
                      ),
                      const SizedBox(height: 8),
                      _phaseBlock(
                        label: 'Second-fix',
                        materials: secondMats,
                        withdrawal: secondWithdrawal,
                        wr: secondWr,
                        loc: loc,
                        phase: LocationMaterialModel.phaseSecondFix,
                      ),
                    ],
                  ),
                ),
              );
            }),
          if (_selectedProject != null && !_warehouseLoading && _loadError == null) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _showProjectWarehouseBalances,
              icon: const Icon(Icons.warehouse_outlined),
              label: const Text('عرض رصيد المخزن'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1B5E20),
                side: const BorderSide(color: Color(0xFF1B5E20)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ],
          ),
          if (_loading)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66FFFFFF),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _phaseBlock({
    required String label,
    required List<LocationMaterialModel> materials,
    required LocationWithdrawalModel? withdrawal,
    required WithdrawalRequestModel? wr,
    required ProjectLocationModel loc,
    required String phase,
  }) {
    final path = _locationPath(loc);
    final villaName = _villaNumberForPdf(loc);
    final disUrls = withdrawal != null
        ? _parseImageJson(withdrawal.disbursementPermitImagesJson)
        : <String>[];
    final delUrls = withdrawal != null
        ? _parseImageJson(withdrawal.deliveryPermitImagesJson)
        : <String>[];

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          if (materials.isEmpty)
            const Text(
              'لا توجد خامات لهذه المرحلة',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            )
          else
            ...materials.map(
              (m) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(m.materialName, overflow: TextOverflow.ellipsis),
                    ),
                    Text(
                      '${m.quantity} ${m.unit}',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          if (withdrawal != null)
            Text(
              'تم سحب هذه المرحلة بواسطة "${withdrawal.userName}" في ${withdrawal.createdAt.year}/${withdrawal.createdAt.month.toString().padLeft(2, '0')}/${withdrawal.createdAt.day} ${withdrawal.createdAt.hour.toString().padLeft(2, '0')}:${withdrawal.createdAt.minute.toString().padLeft(2, '0')}',
              style: TextStyle(fontSize: 12, color: Colors.orange[800]),
            )
          else if (materials.isNotEmpty) ...[
            if (wr != null && wr.isRejectedOverall)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _engineerRequestStatusLine(wr),
                  style: TextStyle(fontSize: 12, color: Colors.red.shade800),
                ),
              ),
            if (wr != null && wr.isPendingOverall)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _engineerRequestStatusLine(wr),
                  style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade800),
                ),
              ),
            if (wr == null || wr.isRejectedOverall)
              FilledButton.icon(
                icon: const Icon(Icons.send_outlined),
                label: const Text('طلب سحب خامات'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                ),
                onPressed: () => _submitWithdrawalRequest(loc, phase),
              ),
            if (wr != null && wr.isApprovedOverall)
              FilledButton.icon(
                icon: const Icon(Icons.inventory_2),
                label: const Text('إكمال سحب الخامات'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                ),
                onPressed: () => _showWithdrawDialog(loc, phase, withdrawalRequestId: wr.id),
              ),
          ],
          if (materials.isNotEmpty || withdrawal != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: materials.isEmpty
                      ? null
                      : () => _showMaterialsDialog(
                            title: '$label — $path',
                            phaseLabel: label,
                            villaName: villaName,
                            materials: materials,
                          ),
                  icon: const Icon(Icons.list_alt, size: 18),
                  label: const Text('عرض الخامات'),
                ),
                OutlinedButton.icon(
                  onPressed: withdrawal == null
                      ? null
                      : () => _showPermitImagesDialog(
                            'أذن الصرف — $label',
                            disUrls,
                          ),
                  icon: const Icon(Icons.receipt_long, size: 18),
                  label: const Text('عرض أذن الصرف'),
                ),
                OutlinedButton.icon(
                  onPressed: withdrawal == null
                      ? null
                      : () => _showPermitImagesDialog(
                            'أذن التسليم — $label',
                            delUrls,
                          ),
                  icon: const Icon(Icons.local_shipping_outlined, size: 18),
                  label: const Text('عرض أذن التسليم'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
