import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/location_material_model.dart';
import '../models/location_withdrawal_model.dart';
import '../models/project_location_model.dart';
import '../models/project_model.dart';
import '../models/user_model.dart';
import '../services/route_persistence.dart';
import '../services/storage_service.dart';
import 'home_screen.dart';

/// المخازن — عرض خامات مواقع العمل ومرفقات أذن الصرف/التسليم بعد السحب (بدون إمكانية السحب).
class WarehousesViewScreen extends StatefulWidget {
  final UserModel currentUser;

  const WarehousesViewScreen({super.key, required this.currentUser});

  @override
  State<WarehousesViewScreen> createState() => _WarehousesViewScreenState();
}

class _WarehousesViewScreenState extends State<WarehousesViewScreen> {
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
          withdrawalByLocPhase[_k(loc.id, phase)] =
              await _db.getLocationWithdrawal(loc.id, phase: phase);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل التحميل: $e'), backgroundColor: Colors.red),
      );
    }
  }

  List<ProjectLocationModel> _locationsWithMaterials() {
    return _allLocations
        .where(
          (loc) => LocationMaterialModel.phases.any(
            (p) =>
                (_materialsByLocationPhase[_k(loc.id, p)] ?? []).isNotEmpty,
          ),
        )
        .toList();
  }

  String _locationPath(ProjectLocationModel loc) {
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
    return path.join(' / ');
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

  void _showMaterialsDialog(String title, List<LocationMaterialModel> materials) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: materials.isEmpty
              ? const Text('لا توجد خامات')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: materials.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
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

  Widget _phaseViewBlock({
    required String label,
    required List<LocationMaterialModel> materials,
    required LocationWithdrawalModel? withdrawal,
    required String locationPath,
  }) {
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
            Text(
              '${materials.length} بند خامات — استخدم «عرض الخامات» للتفاصيل',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          if (withdrawal != null) ...[
            const SizedBox(height: 6),
            Text(
              'تم السحب بواسطة "${withdrawal.userName}" في '
              '${withdrawal.createdAt.year}/${withdrawal.createdAt.month.toString().padLeft(2, '0')}/${withdrawal.createdAt.day} '
              '${withdrawal.createdAt.hour.toString().padLeft(2, '0')}:${withdrawal.createdAt.minute.toString().padLeft(2, '0')}',
              style: TextStyle(fontSize: 12, color: Colors.green.shade800),
            ),
          ] else if (materials.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'لم يتم سحب هذه المرحلة بعد — أذونات الصرف/التسليم غير متاحة',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: materials.isEmpty
                    ? null
                    : () => _showMaterialsDialog(
                          '$label — $locationPath',
                          materials,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locationsWithMats = _locationsWithMaterials();

    return Scaffold(
      appBar: AppBar(
        title: const Text('المخازن'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            await saveLastRoute('home');
            if (!context.mounted) return;
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => HomeScreen(currentUser: widget.currentUser),
              ),
            );
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
                  Text(
                    'عرض خامات سحب المواقع وأذونات الصرف/التسليم (قراءة فقط)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'المستخدم: ${widget.currentUser.name}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<ProjectModel?>(
            value: _selectedProject,
            decoration: const InputDecoration(
              labelText: 'اسم المشروع',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('— اختر المشروع —')),
              ..._projects.map(
                (p) => DropdownMenuItem(value: p, child: Text(p.name)),
              ),
            ],
            onChanged: (v) {
              setState(() => _selectedProject = v);
              _loadLocationsAndMaterials();
            },
          ),
          const SizedBox(height: 20),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_selectedProject != null && locationsWithMats.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'لا توجد أماكن فرعية لها خامات معيّنة في هذا المشروع.',
                  ),
                ),
              ),
            )
          else if (_selectedProject != null)
            ...locationsWithMats.map((loc) {
              final firstMats =
                  _materialsByLocationPhase[_k(loc.id, LocationMaterialModel.phaseFirstFix)] ??
                      [];
              final secondMats =
                  _materialsByLocationPhase[_k(loc.id, LocationMaterialModel.phaseSecondFix)] ??
                      [];
              final firstW = _withdrawalByLocationPhase[_k(
                loc.id,
                LocationMaterialModel.phaseFirstFix,
              )];
              final secondW = _withdrawalByLocationPhase[_k(
                loc.id,
                LocationMaterialModel.phaseSecondFix,
              )];
              final path = _locationPath(loc);
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        path,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _phaseViewBlock(
                        label: 'First-fix',
                        materials: firstMats,
                        withdrawal: firstW,
                        locationPath: path,
                      ),
                      const SizedBox(height: 8),
                      _phaseViewBlock(
                        label: 'Second-fix',
                        materials: secondMats,
                        withdrawal: secondW,
                        locationPath: path,
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
