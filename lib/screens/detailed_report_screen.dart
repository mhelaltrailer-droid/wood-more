import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'detailed_report_finances_screen.dart';
import '../models/project_model.dart';
import '../models/supervisor_model.dart';
import '../models/contractor_model.dart';
import '../models/work_phase_model.dart';
import '../models/project_location_model.dart';
import '../models/zone_model.dart';
import '../models/building_model.dart';
import '../models/detailed_report_model.dart';
import '../services/storage_service.dart';
import '../services/route_persistence.dart';
import 'home_screen.dart';

/// قيمة ثابتة لخيار "أخرى" في قائمة المشروعات (id = 0 لا يوجد في قاعدة المشروعات)
const ProjectModel _otherProject = ProjectModel(id: 0, name: 'أخرى');

/// مراحل احتياطية عند عدم توفر التحميل من التخزين (مثل وضع الويب بدون خادم).
const List<WorkPhaseModel> _fallbackDetailedReportPhases = [
  WorkPhaseModel(id: 1, name: 'تركيب اكسسوارات'),
  WorkPhaseModel(id: 2, name: 'تقطيع WPC'),
  WorkPhaseModel(id: 3, name: 'تركيب WPC'),
  WorkPhaseModel(id: 4, name: 'معالجة'),
  WorkPhaseModel(id: 5, name: 'دهان'),
];

/// واجهة التقرير المفصل لمهندس الموقع
class DetailedReportScreen extends StatefulWidget {
  final UserModel user;
  final String appBarTitle;
  final bool showSummaryField;
  /// عنوان حقل الملخص في النموذج (الحقل يُخزَّن في `DetailedReportModel.summary`).
  final String summaryFieldLabel;
  final int summaryMaxLines;
  /// إذا كان `true` و`showSummaryField` مفعّلاً، لا يُقبل النموذج بدون نص في حقل الملخص (عند التحرير فقط).
  final bool summaryRequired;
  final bool showAttachmentsSection;
  final bool showPlannedExecutionDate;
  final bool showCraftsmanAndAssistantCounts;
  final bool readOnly;
  final bool showExecutionActions;
  final DetailedReportModel? initialReport;
  final Future<bool> Function({
    required DetailedReportModel plan,
    required String action,
    String? modificationSummary,
    String? postponeReasonKey,
    String? postponeReasonLabel,
    String? postponeCustomReason,
    String? postponeNotes,
    DateTime? postponeReopenDate,
  })? onExecutionSubmit;
  final String? initialExecutionStatus;
  final String? initialPostponedReasonText;
  final String? initialModificationSummary;
  final String? executionInfoMessage;
  /// عند `false`: يُحفظ التقرير من هذه الشاشة دون الانتقال لواجهة الماليات (تُكمَل الماليات لاحقاً من أيقونة «الماليات»).
  final bool continueToFinancesOnNext;

  const DetailedReportScreen({
    super.key,
    required this.user,
    this.appBarTitle = 'التقرير المفصل',
    this.showSummaryField = true,
    this.summaryFieldLabel = 'ملخص الأعمال اليوم',
    this.summaryMaxLines = 3,
    this.summaryRequired = false,
    this.showAttachmentsSection = true,
    this.showPlannedExecutionDate = false,
    this.showCraftsmanAndAssistantCounts = false,
    this.readOnly = false,
    this.showExecutionActions = false,
    this.initialReport,
    this.onExecutionSubmit,
    this.initialExecutionStatus,
    this.initialPostponedReasonText,
    this.initialModificationSummary,
    this.executionInfoMessage,
    this.continueToFinancesOnNext = true,
  });

  @override
  State<DetailedReportScreen> createState() => _DetailedReportScreenState();
}

class _DetailedReportScreenState extends State<DetailedReportScreen> {
  final _db = getStorage();
  final _formKey = GlobalKey<FormState>();
  final _summaryController = TextEditingController();
  final _otherProjectNameController = TextEditingController();

  List<ProjectModel> _projects = [];
  List<SupervisorModel> _supervisors = [];
  List<ContractorModel> _contractors = [];
  List<WorkPhaseModel> _phases = const [];

  List<ProjectLocationModel> _projectLocs = [];
  List<ZoneModel> _zones = [];
  final Map<int, List<BuildingModel>> _buildingsCache = {};

  ProjectModel? _selectedProject;
  SupervisorModel? _selectedSupervisor;
  DateTime? _plannedExecutionDate;
  bool _initialReportApplied = false;
  bool _editExecutionMode = false;
  bool _executionDone = false;
  bool _executing = false;
  String? _executionDoneMessage;
  String? _finalModificationSummary;
  bool _postponedLocked = false;
  String? _postponedReasonText;
  final _modificationSummaryController = TextEditingController();

  bool _loadingStructure = false;

  List<WorkSiteBlockRow> _workSiteRows = [WorkSiteBlockRow()];
  final List<DetailedReportAttachment> _attachments = [];

  bool _persistingWorkOnly = false;

  bool get _isOtherProject => _selectedProject?.id == _otherProject.id;

  String? get _initialProjectDisplayName {
    final fromInitial = widget.initialReport?.projectName?.trim();
    if (fromInitial != null && fromInitial.isNotEmpty) return fromInitial;
    final id = widget.initialReport?.projectId;
    if (id != null) return 'مشروع #$id';
    return null;
  }

  bool get _projectHasWorkSites => _projectLocs.any((l) => l.isWorkSite);

  @override
  void initState() {
    super.initState();
    if (widget.initialExecutionStatus != null && widget.initialExecutionStatus!.trim().isNotEmpty) {
      if (widget.initialExecutionStatus == 'postponed') {
        _postponedLocked = true;
        _executionDone = false;
        _postponedReasonText = widget.initialPostponedReasonText ?? 'تم تأجيل التنفيذ';
      } else {
        _executionDone = true;
        _executionDoneMessage = widget.initialExecutionStatus == 'confirmed_edited'
            ? 'تم التعديل ثم التنفيذ'
            : 'تم التنفيذ';
        _finalModificationSummary = widget.initialModificationSummary;
      }
    }
    _loadData();
  }

  @override
  void dispose() {
    _summaryController.dispose();
    _otherProjectNameController.dispose();
    _modificationSummaryController.dispose();
    super.dispose();
  }

  bool get _isReadOnlyNow => widget.readOnly && (_postponedLocked || !_editExecutionMode || _executionDone);
  bool get _lockProjectAndDate => widget.readOnly;

  Future<void> _loadData() async {
    List<ProjectModel> projects = [];
    List<SupervisorModel> supervisors = [];
    List<ContractorModel> contractors = [];
    List<WorkPhaseModel> phases = const [];
    String? loadError;

    try {
      projects = await _db.getProjects();
    } catch (e) {
      loadError = 'المشاريع: $e';
    }
    try {
      supervisors = await _db.getSupervisors();
    } catch (e) {
      loadError = (loadError != null ? '$loadError; ' : '') + 'المشرفون: $e';
    }
    try {
      contractors = await _db.getContractors();
    } catch (e) {
      loadError = (loadError != null ? '$loadError; ' : '') + 'المقاولون: $e';
    }
    try {
      phases = await _db.getWorkPhases();
      if (phases.isEmpty) phases = _fallbackDetailedReportPhases;
    } catch (e) {
      phases = _fallbackDetailedReportPhases;
      loadError = (loadError != null ? '$loadError; ' : '') + 'مراحل العمل: $e';
    }
    if (mounted) {
      setState(() {
        _projects = projects;
        _supervisors = supervisors;
        _contractors = contractors
            .where((c) {
              final n = c.name.trim().toLowerCase();
              return n != 'لايوجد مقاول' && n != 'ذاتي';
            })
            .toList();
        _phases = phases;
        final phaseIds = phases.map((p) => p.id).toSet();
        for (final row in _workSiteRows) {
          for (final slot in row.phaseSlots) {
            if (slot.phaseId != null && !phaseIds.contains(slot.phaseId)) {
              slot.phaseId = null;
            }
          }
        }
      });
      if (!_initialReportApplied && widget.initialReport != null) {
        await _applyInitialReport(widget.initialReport!);
        _initialReportApplied = true;
      }
      if (loadError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تحذير: $loadError'), backgroundColor: Colors.orange),
        );
      }
    }
  }

  List<int> _pathForLocationId(int locationId) {
    final byId = {for (final l in _projectLocs) l.id: l};
    final path = <int>[];
    var current = byId[locationId];
    while (current != null) {
      path.insert(0, current.id);
      current = current.parentId == null ? null : byId[current.parentId!];
    }
    return path;
  }

  Future<void> _applyInitialReport(DetailedReportModel report) async {
    final projectId = report.projectId;
    ProjectModel? selectedProject;
    if (projectId != null) {
      for (final p in _projects) {
        if (p.id == projectId) {
          selectedProject = p;
          break;
        }
      }
      if (selectedProject == null) {
        final fallbackName = (report.projectName ?? '').trim().isNotEmpty
            ? report.projectName!.trim()
            : 'مشروع #$projectId';
        selectedProject = ProjectModel(id: projectId, name: fallbackName);
        _projects = [..._projects, selectedProject];
      }
    } else if ((report.projectName ?? '').trim().startsWith('أخرى')) {
      selectedProject = _otherProject;
      final m = RegExp(r'^أخرى\s*\((.*)\)$').firstMatch(report.projectName!.trim());
      _otherProjectNameController.text = m != null ? m.group(1) ?? '' : report.projectName!;
    }

    SupervisorModel? selectedSupervisor;
    if (report.supervisorId != null) {
      for (final s in _supervisors) {
        if (s.id == report.supervisorId) {
          selectedSupervisor = s;
          break;
        }
      }
    }

    setState(() {
      _selectedProject = selectedProject;
      _selectedSupervisor = selectedSupervisor;
      _plannedExecutionDate = DateTime(
        report.reportDatetime.year,
        report.reportDatetime.month,
        report.reportDatetime.day,
      );
      _summaryController.text = report.summary ?? '';
    });

    if (projectId != null) {
      await _loadStructureForProject(projectId);
    } else if (selectedProject != null && selectedProject.id != _otherProject.id) {
      await _loadStructureForProject(selectedProject.id);
    }

    final grouped = <String, WorkSiteBlockRow>{};
    for (final line in report.lines) {
      final key =
          '${line.contractorId ?? 0}|${line.locationId ?? 0}|${line.zoneId ?? 0}|${line.buildingId ?? 0}';
      final row = grouped.putIfAbsent(
        key,
        () => WorkSiteBlockRow(showCraftsmanAndAssistantCounts: widget.showCraftsmanAndAssistantCounts)
          ..contractorId = line.contractorId
          ..locationId = line.locationId
          ..zoneId = line.zoneId
          ..buildingId = line.buildingId
          ..phaseSlots = [],
      );
      row.phaseSlots.add(
        PhaseSlot(
          phaseId: line.phaseId,
          workersCount: line.workersCount,
          craftsmanCount: line.contractorWorkersCount > 0 ? line.contractorWorkersCount : 1,
          assistantCount: line.selfWorkersCount > 0 ? line.selfWorkersCount : 1,
        ),
      );
    }
    final rows = grouped.values.toList();
    for (final row in rows) {
      if (row.locationId != null && _projectLocs.isNotEmpty) {
        row.locationPath = _pathForLocationId(row.locationId!);
      }
      if (row.phaseSlots.isEmpty) {
        row.phaseSlots.add(PhaseSlot());
      }
    }
    setState(() {
      _workSiteRows = rows.isNotEmpty ? rows : [WorkSiteBlockRow(showCraftsmanAndAssistantCounts: widget.showCraftsmanAndAssistantCounts)];
    });
  }

  Future<void> _loadStructureForProject(int projectId) async {
    setState(() {
      _loadingStructure = true;
      _projectLocs = [];
      _zones = [];
      _buildingsCache.clear();
    });
    try {
      var locs = await _db.getProjectLocations(projectId);
      var zones = await _db.getZones(projectId);
      var resolvedProjectId = projectId;

      // Fallback: في حال اختيار مشروع باسم مكرر وتمت هيكلته تحت id آخر.
      if (locs.isEmpty && zones.isEmpty && _selectedProject != null) {
        final currentName = _normalizeProjectName(_selectedProject!.name);
        try {
          final allProjects = await _db.getProjectsRaw();
          final candidates = allProjects.where((p) {
            return _normalizeProjectName(p.name) == currentName;
          }).toList();
          List<ProjectLocationModel> bestLocs = locs;
          List<ZoneModel> bestZones = zones;
          var bestProjectId = resolvedProjectId;
          var bestScore = -1;
          for (final candidate in candidates) {
            final cLocs = await _db.getProjectLocations(candidate.id);
            final cZones = await _db.getZones(candidate.id);
            if (cLocs.isEmpty && cZones.isEmpty) continue;
            final workSites = cLocs.where((l) => l.isWorkSite).length;
            final folders = cLocs.where((l) => l.isFolder).length;
            // نفضّل الهيكلة الأكثر اكتمالاً: عدد مواقع العمل ثم المجلدات ثم الزونات.
            final score = (workSites * 10000) + (folders * 100) + cZones.length;
            final isTieAndNewer = score == bestScore && candidate.id > bestProjectId;
            if (score > bestScore || isTieAndNewer) {
              bestScore = score;
              bestLocs = cLocs;
              bestZones = cZones;
              bestProjectId = candidate.id;
            }
          }
          if (bestScore >= 0) {
            locs = bestLocs;
            zones = bestZones;
            resolvedProjectId = bestProjectId;
          }
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _projectLocs = locs;
        _zones = zones;
        if (_selectedProject != null && _selectedProject!.id == projectId && resolvedProjectId != projectId) {
          ProjectModel? matched;
          for (final p in _projects) {
            if (p.id == resolvedProjectId) {
              matched = p;
              break;
            }
          }
          if (matched == null) {
            matched = ProjectModel(id: resolvedProjectId, name: _selectedProject!.name);
            _projects = [..._projects, matched];
          }
          _selectedProject = matched;
        }
        _loadingStructure = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingStructure = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل تحميل هيكلة المشروع: $e'), backgroundColor: Colors.red),
      );
    }
  }

  String _normalizeProjectName(String input) {
    final lower = input.trim().toLowerCase();
    final collapsed = lower.replaceAll(RegExp(r'\s+'), ' ');
    return collapsed.replaceAll(RegExp(r'[_-]+'), ' ');
  }

  Future<void> _ensureBuildingsLoaded(int zoneId) async {
    if (_buildingsCache.containsKey(zoneId)) return;
    try {
      final list = await _db.getBuildings(zoneId);
      if (!mounted) return;
      setState(() => _buildingsCache[zoneId] = list);
    } catch (_) {
      if (mounted) setState(() => _buildingsCache[zoneId] = []);
    }
  }

  ProjectLocationModel? _nodeById(int id) {
    for (final l in _projectLocs) {
      if (l.id == id) return l;
    }
    return null;
  }

  void _recalcLocationId(WorkSiteBlockRow row) {
    if (row.locationPath.isEmpty) {
      row.locationId = null;
      return;
    }
    final lastId = row.locationPath.last;
    final node = _nodeById(lastId);
    if (node == null) {
      row.locationId = null;
      return;
    }
    if (node.isWorkSite) {
      row.locationId = lastId;
      return;
    }
    if (!_projectHasWorkSites) {
      row.locationId = lastId;
    } else {
      row.locationId = null;
    }
  }

  bool _rowPlaceOk(WorkSiteBlockRow row) {
    if (_isOtherProject) return true;
    if (_projectLocs.isNotEmpty) {
      if (row.locationPath.isEmpty) return false;
      final last = _nodeById(row.locationPath.last);
      if (last == null) return false;
      if (_projectHasWorkSites) {
        return last.isWorkSite && row.locationId != null;
      }
      return row.locationId != null;
    }
    return row.zoneId != null && row.buildingId != null;
  }

  void _addWorkSiteBlock() {
    setState(() => _workSiteRows.add(WorkSiteBlockRow(showCraftsmanAndAssistantCounts: widget.showCraftsmanAndAssistantCounts)));
  }

  void _removeWorkSiteBlock(int index) {
    if (_workSiteRows.length <= 1) return;
    setState(() => _workSiteRows.removeAt(index));
  }

  Future<void> _addPhaseSlot(WorkSiteBlockRow block) async {
    if (_phases.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد مراحل متاحة حالياً')),
      );
      return;
    }
    final selectedPhaseId = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('اختر المرحلة المضافة'),
        content: DropdownButtonFormField<int>(
          isExpanded: true,
          value: null,
          decoration: const InputDecoration(
            labelText: 'المرحلة',
            border: OutlineInputBorder(),
          ),
          items: _phases
              .map((p) => DropdownMenuItem<int>(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (v) {
            if (v != null) Navigator.of(ctx).pop(v);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
    if (selectedPhaseId == null) return;
    final inheritedWorkers = block.phaseSlots.isNotEmpty && block.phaseSlots.first.workersCount >= 1
        ? block.phaseSlots.first.workersCount
        : 1;
    setState(() {
      block.phaseSlots.add(PhaseSlot(
        phaseId: selectedPhaseId,
        workersCount: inheritedWorkers,
        craftsmanCount: widget.showCraftsmanAndAssistantCounts
            ? (block.phaseSlots.isNotEmpty ? block.phaseSlots.first.craftsmanCount : 1)
            : 1,
        assistantCount: widget.showCraftsmanAndAssistantCounts
            ? (block.phaseSlots.isNotEmpty ? block.phaseSlots.first.assistantCount : 1)
            : 1,
      ));
    });
  }

  void _removePhaseSlot(WorkSiteBlockRow block, int slotIndex) {
    if (block.phaseSlots.length <= 1) return;
    setState(() => block.phaseSlots.removeAt(slotIndex));
  }

  DetailedReportModel? _buildReportForNext() {
    if (!_formKey.currentState!.validate()) return null;
    if (widget.showPlannedExecutionDate && _plannedExecutionDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختر تاريخ تنفيذ الخطة')));
      return null;
    }
    if (_selectedProject == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختر المشروع')));
      return null;
    }
    if (_isOtherProject) {
      final otherName = _otherProjectNameController.text.trim();
      if (otherName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('عند اختيار "أخرى" يرجى كتابة اسم المشروع في الخانة أدناه')),
        );
        return null;
      }
    }
    final lines = <DetailedReportLineModel>[];
    for (final block in _workSiteRows) {
      if (!_isOtherProject) {
        if (!_rowPlaceOk(block)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _projectLocs.isNotEmpty
                    ? (_projectHasWorkSites
                        ? 'أكمل اختيار الموقع الفرعي حتى «موقع العمل» لكل موقع عمل تُدخل له مراحل'
                        : 'اختر الموقع الفرعي من الهيكلة لكل موقع عمل')
                    : 'اختر المنطقة (زون) والمبنى لكل موقع عمل تُدخل له مراحل',
              ),
              backgroundColor: Colors.orange,
            ),
          );
          return null;
        }
      }
      var addedAnyPhase = false;
      final baseWorkers = block.phaseSlots.isNotEmpty && block.phaseSlots.first.workersCount >= 1
          ? block.phaseSlots.first.workersCount
          : 1;
      for (final slot in block.phaseSlots) {
        if (slot.phaseId == null) continue;
        lines.add(DetailedReportLineModel(
          contractorId: block.contractorId,
          zoneId: _isOtherProject || _projectLocs.isNotEmpty ? null : block.zoneId,
          buildingId: _isOtherProject || _projectLocs.isNotEmpty ? null : block.buildingId,
          locationId: _isOtherProject || _projectLocs.isEmpty ? null : block.locationId,
          phaseId: slot.phaseId!,
          contractorWorkersCount: widget.showCraftsmanAndAssistantCounts ? slot.craftsmanCount : 0,
          selfWorkersCount: widget.showCraftsmanAndAssistantCounts ? slot.assistantCount : 0,
          workersCount: baseWorkers,
        ));
        addedAnyPhase = true;
      }
      if (!_isOtherProject && _rowPlaceOk(block) && !addedAnyPhase) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('أضف مرحلة واحدة على الأقل لكل موقع عمل مكتمل'),
            backgroundColor: Colors.orange,
          ),
        );
        return null;
      }
    }
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف على الأقل مرحلة واحدة')),
      );
      return null;
    }
    return DetailedReportModel(
      userId: widget.user.id,
      userName: widget.user.name,
      reportDatetime: widget.showPlannedExecutionDate && _plannedExecutionDate != null ? _plannedExecutionDate! : DateTime.now(),
      projectId: _isOtherProject ? null : _selectedProject!.id,
      projectName: _isOtherProject ? 'أخرى (${_otherProjectNameController.text.trim()})' : _selectedProject!.name,
      supervisorId: _selectedSupervisor?.id,
      summary: widget.showSummaryField && _summaryController.text.trim().isNotEmpty ? _summaryController.text.trim() : null,
      lines: lines,
      expenses: const [],
      attachments: widget.showAttachmentsSection ? List<DetailedReportAttachment>.from(_attachments) : const [],
    );
  }

  void _goNext() {
    final report = _buildReportForNext();
    if (report == null || !mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DetailedReportFinancesScreen(user: widget.user, report: report),
      ),
    );
  }

  Future<void> _saveWorkWithoutFinances() async {
    final report = _buildReportForNext();
    if (report == null || !mounted) return;
    setState(() => _persistingWorkOnly = true);
    try {
      await _db.addDetailedReport(report);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ التقرير. يمكنك إدخال الماليات من أيقونة الماليات عند الحاجة'), backgroundColor: Colors.green),
      );
      await saveLastRoute('home');
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => HomeScreen(currentUser: widget.user)),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _persistingWorkOnly = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  ZoneModel? _zoneDropdownValue(WorkSiteBlockRow row) {
    if (row.zoneId == null) return null;
    for (final z in _zones) {
      if (z.id == row.zoneId) return z;
    }
    return null;
  }

  BuildingModel? _buildingDropdownValue(WorkSiteBlockRow row) {
    if (row.zoneId == null || row.buildingId == null) return null;
    final list = _buildingsCache[row.zoneId!] ?? [];
    for (final b in list) {
      if (b.id == row.buildingId) return b;
    }
    return null;
  }

  List<Widget> _buildLocationCascade(WorkSiteBlockRow row) {
    final widgets = <Widget>[];
    int? parentId;
    var depth = 0;
    while (true) {
      final children = _projectLocs.where((l) => l.parentId == parentId).toList()
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      if (children.isEmpty) break;

      final selectedAtDepth = depth < row.locationPath.length ? row.locationPath[depth] : null;
      final validSelected =
          selectedAtDepth != null && children.any((c) => c.id == selectedAtDepth) ? selectedAtDepth : null;

      final d = depth;
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: DropdownButtonFormField<int>(
            value: validSelected,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: depth == 0 ? 'موقع المشروع (المستوى 1)' : 'المستوى ${depth + 1}',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              const DropdownMenuItem<int>(value: null, child: Text('— اختر —')),
              ...children.map(
                (c) => DropdownMenuItem(
                  value: c.id,
                  child: Text(c.name, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: _isReadOnlyNow ? null : (id) {
              setState(() {
                if (id == null) {
                  row.locationPath = row.locationPath.take(d).toList();
                  _recalcLocationId(row);
                  return;
                }
                row.locationPath = [...row.locationPath.take(d), id];
                _recalcLocationId(row);
              });
            },
          ),
        ),
      );

      if (validSelected == null) break;
      final node = children.firstWhere((c) => c.id == validSelected);
      if (node.isWorkSite) break;
      parentId = validSelected;
      depth++;
    }
    return widgets;
  }

  Widget _buildZoneBuildingFields(WorkSiteBlockRow row) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<ZoneModel?>(
          value: _zoneDropdownValue(row),
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'المنطقة (زون) *',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: [
            const DropdownMenuItem<ZoneModel?>(value: null, child: Text('— اختر المنطقة —')),
            ..._zones.map((z) => DropdownMenuItem(value: z, child: Text(z.name, overflow: TextOverflow.ellipsis))),
          ],
          onChanged: _isReadOnlyNow ? null : (z) async {
            row.zoneId = z?.id;
            row.buildingId = null;
            if (z != null) await _ensureBuildingsLoaded(z.id);
            setState(() {});
          },
        ),
        if (row.zoneId != null) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<BuildingModel?>(
            value: _buildingDropdownValue(row),
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'المبنى *',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              const DropdownMenuItem<BuildingModel?>(value: null, child: Text('— اختر المبنى —')),
              ...(_buildingsCache[row.zoneId!] ?? []).map(
                (b) => DropdownMenuItem(value: b, child: Text(b.name, overflow: TextOverflow.ellipsis)),
              ),
            ],
            onChanged: _isReadOnlyNow ? null : (b) => setState(() => row.buildingId = b?.id),
          ),
        ],
      ],
    );
  }

  ContractorModel? _contractorDropdownValue(WorkSiteBlockRow row) {
    if (row.contractorId == null) return null;
    for (final c in _contractors) {
      if (c.id == row.contractorId) return c;
    }
    return null;
  }

  Widget _buildPhaseSlotRow(WorkSiteBlockRow block, int slotIndex, PhaseSlot slot) {
    String phaseNameById(int? id) {
      if (id == null) return '—';
      for (final p in _phases) {
        if (p.id == id) return p.name;
      }
      return '—';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: slotIndex == 0
                ? DropdownButtonFormField<int>(
                    value: slot.phaseId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'المرحلة', border: OutlineInputBorder(), isDense: true),
                    items: [
                      const DropdownMenuItem<int>(value: null, child: Text('— اختر المرحلة —')),
                      ..._phases.map((p) => DropdownMenuItem<int>(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: _isReadOnlyNow ? null : (v) => setState(() => slot.phaseId = v),
                  )
                : Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      phaseNameById(slot.phaseId),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          if (slotIndex == 0)
            SizedBox(
              width: 110,
              child: DropdownButtonFormField<int>(
                value: slot.workersCount >= 0 ? slot.workersCount : 0,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'عدد العمال', border: OutlineInputBorder(), isDense: true),
                items: List.generate(14, (n) => n).map((n) => DropdownMenuItem(value: n, child: Text('$n'))).toList(),
                onChanged: _isReadOnlyNow ? null : (v) {
                  final value = v ?? 0;
                  setState(() {
                    slot.workersCount = value;
                    for (var i = 1; i < block.phaseSlots.length; i++) {
                      block.phaseSlots[i].workersCount = value;
                    }
                  });
                },
              ),
            ),
          if (slotIndex == 0 && widget.showCraftsmanAndAssistantCounts) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 95,
              child: DropdownButtonFormField<int>(
                value: slot.craftsmanCount >= 0 && slot.craftsmanCount <= 13 ? slot.craftsmanCount : 0,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'صنايعي', border: OutlineInputBorder(), isDense: true),
                items: List.generate(14, (n) => n).map((n) => DropdownMenuItem(value: n, child: Text('$n'))).toList(),
                onChanged: _isReadOnlyNow ? null : (v) {
                  final value = v ?? 0;
                  setState(() {
                    slot.craftsmanCount = value;
                    for (var i = 1; i < block.phaseSlots.length; i++) {
                      block.phaseSlots[i].craftsmanCount = value;
                    }
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 95,
              child: DropdownButtonFormField<int>(
                value: slot.assistantCount >= 0 && slot.assistantCount <= 13 ? slot.assistantCount : 0,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'مساعد', border: OutlineInputBorder(), isDense: true),
                items: List.generate(14, (n) => n).map((n) => DropdownMenuItem(value: n, child: Text('$n'))).toList(),
                onChanged: _isReadOnlyNow ? null : (v) {
                  final value = v ?? 0;
                  setState(() {
                    slot.assistantCount = value;
                    for (var i = 1; i < block.phaseSlots.length; i++) {
                      block.phaseSlots[i].assistantCount = value;
                    }
                  });
                },
              ),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.close, size: 20, color: Colors.red),
            onPressed: (_isReadOnlyNow || block.phaseSlots.length <= 1) ? null : () => _removePhaseSlot(block, slotIndex),
            tooltip: 'حذف هذه المرحلة',
          ),
        ],
      ),
    );
  }

  Widget _buildWorkSiteBlockCard(int index, WorkSiteBlockRow row) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('موقع العمل ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                if (_workSiteRows.length > 1 && !_isReadOnlyNow)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _removeWorkSiteBlock(index),
                    tooltip: 'حذف هذا الموقع',
                  ),
              ],
            ),
            if (!_isOtherProject) ...[
              const SizedBox(height: 8),
              const Text('مكان العمل', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              if (_loadingStructure)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_projectLocs.isNotEmpty) ...[
                const Text(
                  'اختر الموقع الفرعي حسب هيكلة المشروع (من لوحة «هيكل مواقع المشروع») حتى موقع العمل.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                ..._buildLocationCascade(row),
              ] else if (_zones.isNotEmpty) ...[
                const Text(
                  'لا توجد مواقع فرعية في الهيكلة؛ استخدم المنطقة والمبنى.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                _buildZoneBuildingFields(row),
              ] else ...[
                const Text(
                  'لا توجد هيكلة مواقع ولا مناطق لهذا المشروع؛ أضفها من مسؤول التطبيق.',
                  style: TextStyle(fontSize: 12, color: Colors.orange),
                ),
              ],
              const SizedBox(height: 12),
            ],
            DropdownButtonFormField<ContractorModel?>(
              value: _contractorDropdownValue(row),
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'اسم المقاول',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                ..._contractors.map((c) => DropdownMenuItem(value: c, child: Text(c.name, overflow: TextOverflow.ellipsis))),
              ],
              onChanged: _isReadOnlyNow ? null : (v) => setState(() => row.contractorId = v?.id),
            ),
            const SizedBox(height: 12),
            const Text(
              'المراحل',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              widget.showCraftsmanAndAssistantCounts
                  ? 'في المرحلة الأولى: اختر المرحلة وعدد العمال وعدد الصنايعي وعدد المساعد. عند إضافة مرحلة جديدة: يتم اختيار المرحلة مرة واحدة وتظهر بدون قوائم إضافية، مع نفس الأعداد تلقائياً.'
                  : 'في المرحلة الأولى: اختر المرحلة وعدد العمال. عند إضافة مرحلة جديدة: يتم اختيار المرحلة مرة واحدة وتظهر بدون قوائم إضافية، مع نفس عدد العمال تلقائياً.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700, height: 1.35),
            ),
            const SizedBox(height: 8),
            ...row.phaseSlots.asMap().entries.map((e) => _buildPhaseSlotRow(row, e.key, e.value)),
            if (!_isReadOnlyNow)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () => _addPhaseSlot(row),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('إضافة مرحلة'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _mimeFromFileName(String? name, {required bool imageOnly}) {
    final ext = name?.split('.').last.toLowerCase() ?? '';
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
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _pickSummaryImages() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true,
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) return;
      for (final f in result.files) {
        final bytes = f.bytes;
        if (bytes == null) continue;
        final mime = _mimeFromFileName(f.name, imageOnly: true);
        final data = 'data:$mime;base64,${base64Encode(bytes)}';
        _attachments.add(DetailedReportAttachment(kind: 'image', fileName: f.name, data: data));
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _pickSummaryFiles() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        withData: true,
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) return;
      for (final f in result.files) {
        final bytes = f.bytes;
        if (bytes == null) continue;
        final mime = _mimeFromFileName(f.name, imageOnly: false);
        final data = 'data:$mime;base64,${base64Encode(bytes)}';
        final isImg = mime.startsWith('image/');
        _attachments.add(DetailedReportAttachment(kind: isImg ? 'image' : 'file', fileName: f.name, data: data));
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
    }
  }

  void _removeAttachmentAt(int i) {
    setState(() => _attachments.removeAt(i));
  }

  Future<List<Map<String, dynamic>>> _loadPostponeReasons() async {
    try {
      final list = await _db.getPostponeReasons();
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return const [
        {'reason_key': 'materials_shortage', 'label': 'نقص خامات', 'requires_custom': false},
        {'reason_key': 'site_not_ready', 'label': 'عدم جاهزية موقع العمل', 'requires_custom': false},
        {'reason_key': 'approval_delay', 'label': 'تأخر اعتماد/موافقة', 'requires_custom': false},
        {'reason_key': 'weather', 'label': 'ظروف جوية', 'requires_custom': false},
        {'reason_key': 'labor_shortage', 'label': 'نقص عمالة', 'requires_custom': false},
        {'reason_key': 'other', 'label': 'أخرى', 'requires_custom': true},
      ];
    }
  }

  Future<({String key, String label, String? custom, String? notes, DateTime reopenDate})?> _askPostponeReason() async {
    final reasons = await _loadPostponeReasons();
    if (!mounted) return null;
    String? selectedKey;
    String? selectedLabel;
    bool requiresCustom = false;
    final customController = TextEditingController();
    final notesController = TextEditingController();
    DateTime? reopenDate;
    final result = await showDialog<({String key, String label, String? custom, String? notes, DateTime reopenDate})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('سبب التأجيل'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedKey,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'اختر سبب التأجيل *',
                  border: OutlineInputBorder(),
                ),
                items: reasons
                    .map((r) => DropdownMenuItem<String>(
                          value: (r['reason_key'] ?? '').toString(),
                          child: Text((r['label'] ?? '').toString(), overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (v) {
                  setLocal(() {
                    selectedKey = v;
                    final matched = reasons.where((r) => (r['reason_key'] ?? '').toString() == v).toList();
                    selectedLabel = matched.isEmpty ? null : (matched.first['label'] ?? '').toString();
                    requiresCustom = matched.isNotEmpty && matched.first['requires_custom'] == true;
                  });
                },
              ),
              if (requiresCustom) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: customController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'اكتب السبب *',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: reopenDate ?? now,
                    firstDate: DateTime(now.year - 1, 1, 1),
                    lastDate: DateTime(now.year + 2, 12, 31),
                  );
                  if (picked == null) return;
                  setLocal(() {
                    reopenDate = DateTime(picked.year, picked.month, picked.day);
                  });
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'تاريخ إعادة فتح الخطة *',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    reopenDate == null
                        ? '— اختر التاريخ —'
                        : '${reopenDate!.year.toString().padLeft(4, '0')}-${reopenDate!.month.toString().padLeft(2, '0')}-${reopenDate!.day.toString().padLeft(2, '0')}',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات (اختياري)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                final custom = customController.text.trim();
                if (selectedKey == null || selectedLabel == null) return;
                if (requiresCustom && custom.isEmpty) return;
                if (reopenDate == null) return;
                Navigator.pop(
                  ctx,
                  (
                    key: selectedKey!,
                    label: selectedLabel!,
                    custom: custom.isEmpty ? null : custom,
                    notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                    reopenDate: reopenDate!,
                  ),
                );
              },
              child: const Text('تأكيد التأجيل'),
            ),
          ],
        ),
      ),
    );
    customController.dispose();
    notesController.dispose();
    return result;
  }

  Future<void> _submitExecution(String action) async {
    if (_executing || _executionDone) return;
    if (action == 'confirmed_edited' && _modificationSummaryController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى كتابة ملخص التعديلات قبل تأكيد التنفيذ'), backgroundColor: Colors.orange),
      );
      return;
    }
    String? postponeReasonKey;
    String? postponeReasonLabel;
    String? postponeCustomReason;
    String? postponeNotes;
    DateTime? postponeReopenDate;
    if (action == 'postponed') {
      final reason = await _askPostponeReason();
      if (reason == null) return;
      postponeReasonKey = reason.key;
      postponeReasonLabel = reason.label;
      postponeCustomReason = reason.custom;
      postponeNotes = reason.notes;
      postponeReopenDate = reason.reopenDate;
    }
    final DetailedReportModel? plan = _editExecutionMode ? _buildReportForNext() : (widget.initialReport ?? _buildReportForNext());
    if (plan == null) return;
    setState(() => _executing = true);
    try {
      final ok = await (widget.onExecutionSubmit?.call(
            plan: plan,
            action: action,
            modificationSummary: _modificationSummaryController.text.trim().isEmpty
                ? null
                : _modificationSummaryController.text.trim(),
            postponeReasonKey: postponeReasonKey,
            postponeReasonLabel: postponeReasonLabel,
            postponeCustomReason: postponeCustomReason,
            postponeNotes: postponeNotes,
            postponeReopenDate: postponeReopenDate,
          ) ??
          Future.value(false));
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر حفظ التنفيذ'), backgroundColor: Colors.red),
        );
        return;
      }
      if (action == 'postponed') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم التأجيل'), backgroundColor: Colors.orange),
        );
        setState(() {
          _postponedLocked = true;
          _editExecutionMode = false;
          _executionDone = false;
          _executionDoneMessage = null;
          _postponedReasonText = postponeReasonKey == 'other' && postponeCustomReason != null && postponeCustomReason.trim().isNotEmpty
              ? 'تم التأجيل: ${postponeCustomReason.trim()}'
              : 'تم التأجيل: ${postponeReasonLabel ?? 'سبب غير محدد'}';
          if (postponeReopenDate != null) {
            _postponedReasonText = '$_postponedReasonText\nتاريخ إعادة الفتح: ${postponeReopenDate.year.toString().padLeft(4, '0')}-${postponeReopenDate.month.toString().padLeft(2, '0')}-${postponeReopenDate.day.toString().padLeft(2, '0')}';
          }
          if (postponeNotes != null && postponeNotes.trim().isNotEmpty) {
            _postponedReasonText = '${_postponedReasonText!}\nملاحظات: ${postponeNotes.trim()}';
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم التأكيد'), backgroundColor: Colors.green),
        );
        final summaryText = _modificationSummaryController.text.trim();
        setState(() {
          _executionDone = true;
          _postponedLocked = false;
          _editExecutionMode = false;
          _executionDoneMessage = action == 'confirmed_edited' ? 'تم التعديل ثم التنفيذ' : 'تم التنفيذ';
          _finalModificationSummary = action == 'confirmed_edited' && summaryText.isNotEmpty ? summaryText : null;
        });
      }
    } finally {
      if (mounted) setState(() => _executing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.appBarTitle),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: Scrollbar(
          thumbVisibility: true,
          child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _readOnlyRow('اسم المهندس', widget.user.name),
            const SizedBox(height: 16),
            DropdownButtonFormField<ProjectModel>(
              value: _selectedProject,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'اسم المشروع *',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<ProjectModel>(value: null, child: Text('— اختر المشروع —')),
                ..._projects.where((p) => p.name != 'أخرى').map((p) => DropdownMenuItem(value: p, child: Text(p.name, overflow: TextOverflow.ellipsis))),
                const DropdownMenuItem<ProjectModel>(value: _otherProject, child: Text('أخرى')),
              ],
              onChanged: _lockProjectAndDate ? null : (v) {
                setState(() {
                  _selectedProject = v;
                  _workSiteRows = [
                    WorkSiteBlockRow(showCraftsmanAndAssistantCounts: widget.showCraftsmanAndAssistantCounts),
                  ];
                  _attachments.clear();
                  _projectLocs = [];
                  _zones = [];
                  _buildingsCache.clear();
                  _loadingStructure = false;
                });
                if (v != null && v.id != _otherProject.id) {
                  _loadStructureForProject(v.id);
                }
              },
              validator: (v) => v == null ? 'المشروع إلزامي' : null,
            ),
            if (widget.showPlannedExecutionDate) ...[
              const SizedBox(height: 16),
              InkWell(
                onTap: _lockProjectAndDate ? null : () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _plannedExecutionDate ?? now,
                    firstDate: DateTime(now.year - 1, 1, 1),
                    lastDate: DateTime(now.year + 2, 12, 31),
                  );
                  if (picked != null) {
                    setState(() {
                      _plannedExecutionDate = DateTime(picked.year, picked.month, picked.day);
                    });
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'تاريخ تنفيذ الخطة *',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    _plannedExecutionDate == null
                        ? '— اختر التاريخ —'
                        : '${_plannedExecutionDate!.year.toString().padLeft(4, '0')}-${_plannedExecutionDate!.month.toString().padLeft(2, '0')}-${_plannedExecutionDate!.day.toString().padLeft(2, '0')}',
                  ),
                ),
              ),
            ],
            if (_isOtherProject) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _otherProjectNameController,
                enabled: !_isReadOnlyNow,
                decoration: const InputDecoration(
                  labelText: 'حدد المشروع (إلزامي عند اختيار أخرى) *',
                  hintText: 'اكتب اسم المشروع أو وصفاً قصيراً',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (_isOtherProject && (v == null || v.trim().isEmpty)) return 'مطلوب عند اختيار أخرى';
                  return null;
                },
                onChanged: _isReadOnlyNow ? null : (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: 24),
            if (_selectedProject != null || (widget.readOnly && widget.initialReport != null)) ...[
              const Text('توزيع العمال حسب الموقع والمرحلة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              ..._workSiteRows.asMap().entries.map((e) => _buildWorkSiteBlockCard(e.key, e.value)),
              if (!_isReadOnlyNow)
                OutlinedButton.icon(
                  onPressed: _addWorkSiteBlock,
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة موقع عمل آخر'),
                ),
            ],
            if (_lockProjectAndDate && _selectedProject == null && _initialProjectDisplayName != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
                ),
                child: Text(
                  'المشروع المسجل بالخطة: $_initialProjectDisplayName',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
            const SizedBox(height: 24),
            DropdownButtonFormField<SupervisorModel>(
              value: _selectedSupervisor,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'اسم المشرف',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<SupervisorModel>(value: null, child: Text('— اختر المشرف —')),
                ..._supervisors.map((s) => DropdownMenuItem(value: s, child: Text(s.name, overflow: TextOverflow.ellipsis))),
              ],
              onChanged: _isReadOnlyNow ? null : (v) => setState(() => _selectedSupervisor = v),
            ),
            const SizedBox(height: 24),
            if (widget.showSummaryField) ...[
              TextFormField(
                controller: _summaryController,
                maxLines: widget.summaryMaxLines,
                readOnly: _isReadOnlyNow,
                decoration: InputDecoration(
                  labelText: widget.summaryRequired && !_isReadOnlyNow ? '${widget.summaryFieldLabel} *' : widget.summaryFieldLabel,
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: widget.summaryRequired && !_isReadOnlyNow
                    ? (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'حقل «${widget.summaryFieldLabel}» إلزامي';
                        }
                        return null;
                      }
                    : null,
              ),
              const SizedBox(height: 20),
            ],
            if (widget.showAttachmentsSection) ...[
              const Text('مرفقات (اختياري)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              const Text('يمكن إرفاق صور أو ملفات قبل الانتقال لخطوة الماليات.', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _isReadOnlyNow ? null : _pickSummaryImages,
                    icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
                    label: const Text('إرفاق صورة أو أكثر'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isReadOnlyNow ? null : _pickSummaryFiles,
                    icon: const Icon(Icons.attach_file, size: 20),
                    label: const Text('إرفاق ملف أو أكثر'),
                  ),
                ],
              ),
              if (_attachments.isNotEmpty) ...[
                const SizedBox(height: 12),
                ..._attachments.asMap().entries.map((e) {
                  final i = e.key;
                  final a = e.value;
                  final label = a.fileName?.isNotEmpty == true ? a.fileName! : (a.kind == 'image' ? 'صورة' : 'ملف');
                  return Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      dense: true,
                      leading: Icon(a.kind == 'image' ? Icons.image_outlined : Icons.insert_drive_file_outlined),
                      title: Text(label, overflow: TextOverflow.ellipsis),
                      subtitle: Text(a.kind == 'image' ? 'صورة' : 'ملف'),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: _isReadOnlyNow ? null : () => _removeAttachmentAt(i),
                      ),
                    ),
                  );
                }),
              ],
            ],
            const SizedBox(height: 24),
            if (!_isReadOnlyNow && !widget.showExecutionActions)
              FilledButton(
                onPressed: _persistingWorkOnly
                    ? null
                    : (widget.continueToFinancesOnNext ? _goNext : _saveWorkWithoutFinances),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF1B5E20),
                ),
                child: _persistingWorkOnly
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(widget.continueToFinancesOnNext ? 'التالي' : 'حفظ التقرير'),
              ),
            if (widget.showExecutionActions && _executionDone) ...[
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
                ),
                child: Text(
                  _executionDoneMessage ?? 'تم التنفيذ',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ),
              if ((_finalModificationSummary ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ملخص التعديلات',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                      const SizedBox(height: 6),
                      Text(_finalModificationSummary!.trim()),
                    ],
                  ),
                ),
              ],
            ],
            if ((widget.executionInfoMessage ?? '').trim().isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.35)),
                ),
                child: Text(
                  widget.executionInfoMessage!.trim(),
                  style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (widget.showExecutionActions && _postponedLocked && !_executionDone) ...[
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                ),
                child: Text(
                  _postponedReasonText ?? 'تم تأجيل التنفيذ',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: _executing
                    ? null
                    : () {
                        setState(() {
                          _postponedLocked = false;
                          _editExecutionMode = false;
                        });
                      },
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text('إعادة فتح للتنفيذ'),
              ),
            ],
            if (widget.showExecutionActions && !_executionDone && !_editExecutionMode && !_postponedLocked) ...[
              FilledButton(
                onPressed: _executing ? null : () => _submitExecution('confirmed'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF1B5E20),
                ),
                child: Text(_executing ? 'جاري الحفظ...' : 'تأكيد التنفيذ'),
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: _executing
                    ? null
                    : () {
                        setState(() => _editExecutionMode = true);
                      },
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text('تأكيد+تعديل'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _executing ? null : () => _submitExecution('postponed'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.orange,
                ),
                child: const Text('تأجيل التنفيذ'),
              ),
            ],
            if (widget.showExecutionActions && !_executionDone && _editExecutionMode) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _modificationSummaryController,
                maxLines: 3,
                validator: (v) {
                  if ((v ?? '').trim().isEmpty) return 'ملخص التعديلات إلزامي';
                  return null;
                },
                decoration: const InputDecoration(
                  labelText: 'ملخص التعديلات *',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _executing ? null : () => _submitExecution('confirmed_edited'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF1B5E20),
                ),
                child: Text(_executing ? 'جاري الحفظ...' : 'تأكيد التنفيذ'),
              ),
            ],
          ],
          ),
        ),
      ),
    );
  }

  Widget _readOnlyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

/// مرحلة واحدة ضمن نفس موقع العمل (عدة مراحل في اليوم نفسه)
class PhaseSlot {
  int? phaseId;
  int workersCount;
  int craftsmanCount;
  int assistantCount;

  PhaseSlot({
    this.phaseId,
    this.workersCount = 1,
    this.craftsmanCount = 1,
    this.assistantCount = 1,
  });
}

/// موقع عمل + مقاول + قائمة مراحل (كل مرحلة بعدد عمال)
class WorkSiteBlockRow {
  List<int> locationPath;
  int? locationId;
  int? zoneId;
  int? buildingId;
  int? contractorId;
  List<PhaseSlot> phaseSlots;

  WorkSiteBlockRow({
    List<int>? locationPath,
    this.locationId,
    this.zoneId,
    this.buildingId,
    this.contractorId,
    List<PhaseSlot>? phaseSlots,
    bool showCraftsmanAndAssistantCounts = false,
  })  : locationPath = locationPath ?? [],
        phaseSlots = phaseSlots ??
            [
              PhaseSlot(
                craftsmanCount: showCraftsmanAndAssistantCounts ? 1 : 1,
                assistantCount: showCraftsmanAndAssistantCounts ? 1 : 1,
              ),
            ];
}
