import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/project_model.dart';
import '../models/project_location_model.dart';
import '../models/location_material_model.dart';
import '../models/location_withdrawal_model.dart';
import '../models/project_stock_model.dart';
import '../services/storage_service.dart';
import '../services/route_persistence.dart';
import 'home_screen.dart';
import 'withdrawal_balance_review_screen.dart';

/// المخزن (سحب خامات) — لمهندس الموقع: عرض الخامات المتاحة لكل مكان فرعي وسحبها مرة واحدة مع أذن صرف وتسليم
class EngineerWithdrawMaterialsScreen extends StatefulWidget {
  final UserModel user;

  const EngineerWithdrawMaterialsScreen({super.key, required this.user});

  @override
  State<EngineerWithdrawMaterialsScreen> createState() => _EngineerWithdrawMaterialsScreenState();
}

class _EngineerWithdrawMaterialsScreenState extends State<EngineerWithdrawMaterialsScreen> {
  final _db = getStorage();
  List<ProjectModel> _projects = [];
  ProjectModel? _selectedProject;
  List<ProjectLocationModel> _allLocations = [];
  Map<String, List<LocationMaterialModel>> _materialsByLocationPhase = {};
  Map<String, LocationWithdrawalModel?> _withdrawalByLocationPhase = {};
  bool _loading = false;

  String _k(int locationId, String phase) => '${locationId}_$phase';

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    final list = await _db.getProjects();
    if (!mounted) return;
    setState(() => _projects = list);
  }

  Future<void> _loadLocationsAndMaterials() async {
    if (_selectedProject == null) {
      setState(() {
        _allLocations = [];
        _materialsByLocationPhase = {};
        _withdrawalByLocationPhase = {};
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final locations = await _db.getProjectLocations(_selectedProject!.id);
      final Map<String, List<LocationMaterialModel>> materialsByLocPhase = {};
      final Map<String, LocationWithdrawalModel?> withdrawalByLocPhase = {};
      for (final loc in locations) {
        for (final phase in LocationMaterialModel.phases) {
          final mats = await _db.getLocationMaterials(loc.id, phase: phase);
          if (mats.isNotEmpty) {
            materialsByLocPhase[_k(loc.id, phase)] = mats;
          }
          withdrawalByLocPhase[_k(loc.id, phase)] = await _db
              .getLocationWithdrawal(loc.id, phase: phase);
        }
      }
      if (!mounted) return;
      setState(() {
        _allLocations = locations;
        _materialsByLocationPhase = materialsByLocPhase;
        _withdrawalByLocationPhase = withdrawalByLocPhase;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل التحميل: $e'), backgroundColor: Colors.red));
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

  Future<void> _onWithdrawTap(ProjectLocationModel loc, String phase) async {
    final withdrawal = _withdrawalByLocationPhase[_k(loc.id, phase)];
    if (withdrawal != null) {
      final dateStr = '${withdrawal.createdAt.year}/${withdrawal.createdAt.month.toString().padLeft(2, '0')}/${withdrawal.createdAt.day}';
      final timeStr = '${withdrawal.createdAt.hour.toString().padLeft(2, '0')}:${withdrawal.createdAt.minute.toString().padLeft(2, '0')}';
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('تم السحب مسبقاً'),
          content: Text(
            'لقد تم سحب الخامات بالفعل من طرف المستخدم "${withdrawal.userName}" في التاريخ $dateStr والوقت $timeStr.',
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسناً'))],
        ),
      );
      return;
    }
    await _showWithdrawDialog(loc, phase);
  }

  Future<void> _showWithdrawDialog(ProjectLocationModel loc, String phase) async {
    List<String> disbursementImages = [];
    List<String> deliveryImages = [];

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('سحب الخامات'),
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
              onPressed: () {
                if (disbursementImages.isEmpty || deliveryImages.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('يجب إرفاق أذن الصرف وأذن التسليم (صورة أو صورتين لكل منهما)')));
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('تأكيد السحب'),
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('اسم المهندس: ${widget.user.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
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
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
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
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
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
                        onWithdraw: () => _onWithdrawTap(
                          loc,
                          LocationMaterialModel.phaseFirstFix,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _phaseBlock(
                        label: 'Second-fix',
                        materials: secondMats,
                        withdrawal: secondWithdrawal,
                        onWithdraw: () => _onWithdrawTap(
                          loc,
                          LocationMaterialModel.phaseSecondFix,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          if (_selectedProject != null && !_loading) ...[
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
    );
  }

  Widget _phaseBlock({
    required String label,
    required List<LocationMaterialModel> materials,
    required LocationWithdrawalModel? withdrawal,
    required VoidCallback onWithdraw,
  }) {
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
          else if (materials.isNotEmpty)
            FilledButton.icon(
              icon: const Icon(Icons.inventory_2),
              label: const Text('سحب الخامات'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
              ),
              onPressed: onWithdraw,
            ),
        ],
      ),
    );
  }
}
