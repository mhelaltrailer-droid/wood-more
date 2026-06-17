import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/reports_sys_model.dart';
import '../models/user_model.dart';
import '../services/api_storage_service.dart';
import '../services/storage_service.dart';
import 'reports_sys_detail_screen.dart';
import 'reports_sys_form_screen.dart';

class ReportsSysHubScreen extends StatefulWidget {
  final UserModel currentUser;
  final int initialTabIndex;

  const ReportsSysHubScreen({
    super.key,
    required this.currentUser,
    this.initialTabIndex = 0,
  });

  @override
  State<ReportsSysHubScreen> createState() => _ReportsSysHubScreenState();
}

class _ReportsSysHubScreenState extends State<ReportsSysHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _storage = getStorage();
  final _searchController = TextEditingController();
  bool _loading = true;
  String? _error;
  final Map<String, List<ReportsSysModel>> _lists = {};
  String _archiveSearch = '';
  String _rejectedSearch = '';

  List<_TabDef> get _tabs {
    final tabs = <_TabDef>[
      _TabDef('pending', 'بانتظار إجرائي'),
      _TabDef('created', 'منشأة'),
      _TabDef('sent', 'مشاركة'),
    ];
    if (widget.currentUser.canViewReportsSysArchiveTab) {
      tabs.add(_TabDef('archive', 'الأرشيف'));
    }
    tabs.add(_TabDef('rejected', 'المرفوضة'));
    if (widget.currentUser.canViewReportsSysAllTab) {
      tabs.add(_TabDef('all', 'الكل'));
    }
    return tabs;
  }

  @override
  void initState() {
    super.initState();
    final tabs = _tabs;
    var idx = widget.initialTabIndex;
    if (idx >= tabs.length) idx = 0;
    _tabController = TabController(length: tabs.length, vsync: this, initialIndex: idx);
    final initialTab = tabs[idx].key;
    if (_tabSupportsSearch(initialTab)) {
      _searchController.text = _searchForTab(initialTab);
    }
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      final tab = _tabs[_tabController.index].key;
      if (_tabSupportsSearch(tab)) {
        _searchController.text = _searchForTab(tab);
      }
      _loadTab(tab);
      if (mounted) setState(() {});
    });
    _loadAll();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  bool _tabSupportsSearch(String tabKey) =>
      tabKey == 'archive' || tabKey == 'rejected';

  String _searchForTab(String tabKey) {
    if (tabKey == 'archive') return _archiveSearch;
    if (tabKey == 'rejected') return _rejectedSearch;
    return '';
  }

  void _setSearchForTab(String tabKey, String value) {
    if (tabKey == 'archive') _archiveSearch = value;
    if (tabKey == 'rejected') _rejectedSearch = value;
  }

  Future<void> _applySearchForCurrentTab() async {
    final tab = _tabs[_tabController.index].key;
    if (!_tabSupportsSearch(tab)) return;
    _setSearchForTab(tab, _searchController.text.trim());
    await _loadTab(tab);
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      for (final t in _tabs) {
        await _fetchTab(t.key);
      }
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _loadTab(String tab) async {
    try {
      await _fetchTab(tab);
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _fetchTab(String tab) async {
    if (_storage is! ApiStorageService) {
      throw Exception('Reports-SYS يتطلب اتصال API');
    }
    final list = await _storage.listReportsSysInbox(
      userId: widget.currentUser.id,
      tab: tab,
      requesterEmail: widget.currentUser.email,
      searchQuery: _tabSupportsSearch(tab) ? _searchForTab(tab) : null,
    );
    _lists[tab] = list;
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReportsSysFormScreen(currentUser: widget.currentUser),
      ),
    );
    if (created == true) await _loadAll();
  }

  Future<void> _openReport(ReportsSysModel report) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReportsSysDetailScreen(
          currentUser: widget.currentUser,
          reportId: report.id,
        ),
      ),
    );
    if (changed == true) await _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    final fmt = DateFormat('dd/MM/yyyy HH:mm', 'ar');
    final currentTabKey = tabs[_tabController.index].key;
    final showSearchBar = _tabSupportsSearch(currentTabKey);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports -SYS'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: tabs.map((t) => Tab(text: t.label)).toList(),
        ),
      ),
      floatingActionButton: widget.currentUser.canParticipateInReportsSys
          ? FloatingActionButton.extended(
              onPressed: _openCreate,
              backgroundColor: const Color(0xFF1B5E20),
              icon: const Icon(Icons.add),
              label: const Text('تقرير جديد'),
            )
          : null,
      body: Column(
        children: [
          if (showSearchBar && !_loading && _error == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'بحث: اسم التقرير، المشروع، الملخص',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchForTab(currentTabKey).isNotEmpty
                      ? IconButton(
                          tooltip: 'مسح البحث',
                          onPressed: () {
                            _searchController.clear();
                            _setSearchForTab(currentTabKey, '');
                            _loadTab(currentTabKey);
                          },
                          icon: const Icon(Icons.clear),
                        )
                      : IconButton(
                          tooltip: 'بحث',
                          onPressed: _applySearchForCurrentTab,
                          icon: const Icon(Icons.search),
                        ),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => _applySearchForCurrentTab(),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: tabs.map((t) {
                          final items = _lists[t.key] ?? const [];
                          return _buildTabList(
                            items: items,
                            fmt: fmt,
                            emptyMessage: _tabSupportsSearch(t.key) &&
                                    _searchForTab(t.key).isNotEmpty
                                ? 'لا توجد نتائج للبحث'
                                : 'لا توجد تقارير في هذا القسم',
                          );
                        }).toList(),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabList({
    required List<ReportsSysModel> items,
    required DateFormat fmt,
    required String emptyMessage,
  }) {
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            Center(child: Text(emptyMessage)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final r = items[index];
          return Card(
            child: ListTile(
              onTap: () => _openReport(r),
              title: Text(
                r.reportName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.reportType),
                  if (r.projectName.trim().isNotEmpty)
                    Text('المشروع: ${r.projectName}'),
                  if (r.summary.trim().isNotEmpty)
                    Text(
                      r.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  Text(
                    'الحالة: ${r.statusLabelAr}'
                    '${r.currentAssigneeUserName != null ? ' — عند: ${r.currentAssigneeUserName}' : ''}',
                  ),
                  Text(fmt.format(r.updatedAt)),
                ],
              ),
              trailing: const Icon(Icons.chevron_left),
            ),
          );
        },
      ),
    );
  }
}

class _TabDef {
  final String key;
  final String label;
  const _TabDef(this.key, this.label);
}

int? parseReportsSysIdFromEventType(String eventType) {
  final m = RegExp(r'^reports_sys_(\d+)$').firstMatch(eventType.trim());
  if (m == null) return null;
  return int.tryParse(m.group(1) ?? '');
}
