import 'package:flutter/material.dart';

import '../core/invoices_owner_constants.dart';
import '../models/invoices_owner_model.dart';
import '../models/project_model.dart';
import '../models/user_model.dart';
import '../screens/invoices_owner_detail_screen.dart';
import '../services/api_storage_service.dart';
import '../services/storage_service.dart';

class InvoicesOwnerMonthlyChecklistTab extends StatefulWidget {
  final UserModel currentUser;
  final int refreshToken;
  final Future<void> Function() onRefreshParent;

  const InvoicesOwnerMonthlyChecklistTab({
    super.key,
    required this.currentUser,
    this.refreshToken = 0,
    required this.onRefreshParent,
  });

  @override
  State<InvoicesOwnerMonthlyChecklistTab> createState() =>
      _InvoicesOwnerMonthlyChecklistTabState();
}

class _InvoicesOwnerMonthlyChecklistTabState
    extends State<InvoicesOwnerMonthlyChecklistTab> {
  final _storage = getStorage();
  bool _loading = true;
  String? _error;
  String _month = '';
  List<InvoicesOwnerMonthlyChecklistItem> _items = const [];
  List<ProjectModel> _allProjects = const [];
  int? _selectedProjectId;
  bool _adding = false;
  final Set<int> _busyInvoiceIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant InvoicesOwnerMonthlyChecklistTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _load();
    }
  }

  Future<void> _load() async {
    if (_storage is! ApiStorageService) {
      setState(() {
        _loading = false;
        _error = 'يتطلب اتصال API';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _storage.getInvoicesOwnerMonthlyChecklist(
        userId: widget.currentUser.id,
      );
      final projects = await _storage.getProjects();
      if (!mounted) return;
      final listedIds = result.items.map((e) => e.projectId).toSet();
      final available = projects.where((p) => !listedIds.contains(p.id)).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      setState(() {
        _month = result.month;
        _items = result.items;
        _allProjects = available;
        if (_selectedProjectId != null &&
            !available.any((p) => p.id == _selectedProjectId)) {
          _selectedProjectId = null;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _addProject() async {
    if (_storage is! ApiStorageService) return;
    final projectId = _selectedProjectId;
    if (projectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر مشروعاً أولاً')),
      );
      return;
    }
    setState(() => _adding = true);
    try {
      await _storage.addInvoicesOwnerMonthlyChecklistProject(
        userId: widget.currentUser.id,
        projectId: projectId,
      );
      _selectedProjectId = null;
      await _load();
    } catch (e) {
      if (!mounted) return;
      final msg = '$e'.contains('already_added')
          ? 'المشروع مضاف مسبقاً'
          : 'تعذر إضافة المشروع: $e';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _removeProject(InvoicesOwnerMonthlyChecklistItem item) async {
    if (_storage is! ApiStorageService) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إزالة المشروع'),
        content: Text('إزالة «${item.projectName}» من قائمة Monthly Checklist؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إزالة'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _storage.removeInvoicesOwnerMonthlyChecklistProject(
        userId: widget.currentUser.id,
        projectId: item.projectId,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر الإزالة: $e')),
      );
    }
  }

  Future<void> _openInvoice(InvoicesOwnerMonthlyChecklistItem item) async {
    final invoiceId = item.invoiceId;
    if (invoiceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد مستخلص لهذا المشروع في الشهر الجاري')),
      );
      return;
    }
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => InvoicesOwnerDetailScreen(
          currentUser: widget.currentUser,
          invoiceId: invoiceId,
        ),
      ),
    );
    if (changed == true || mounted) await _load();
    await widget.onRefreshParent();
  }

  Future<void> _setSentToClient(
    InvoicesOwnerMonthlyChecklistItem item,
    bool value,
  ) async {
    final invoiceId = item.invoiceId;
    if (invoiceId == null || _storage is! ApiStorageService) return;
    setState(() => _busyInvoiceIds.add(invoiceId));
    try {
      await _storage.updateInvoicesOwnerClientFlags(
        invoiceId: invoiceId,
        userId: widget.currentUser.id,
        sentToClient: value,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر التحديث: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _busyInvoiceIds.remove(invoiceId));
      }
    }
  }

  Future<void> _setClientReplied(
    InvoicesOwnerMonthlyChecklistItem item,
    bool value,
  ) async {
    final invoiceId = item.invoiceId;
    if (invoiceId == null || _storage is! ApiStorageService) return;
    if (value && !item.sentToClient) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب تعليم «تم الإرسال للعميل» أولاً')),
      );
      return;
    }
    setState(() => _busyInvoiceIds.add(invoiceId));
    try {
      await _storage.updateInvoicesOwnerClientFlags(
        invoiceId: invoiceId,
        userId: widget.currentUser.id,
        clientReplied: value,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر التحديث: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _busyInvoiceIds.remove(invoiceId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            Center(
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (_month.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'الشهر الميلادي: $_month',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (_allProjects.isEmpty)
            Text(
              'كل المشروعات مضافة للقائمة، أو لا توجد مشروعات في النظام.',
              style: TextStyle(color: Colors.grey.shade700),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedProjectId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'إضافة مشروع للقائمة',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _allProjects
                        .map(
                          (p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(
                              p.name,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _adding
                        ? null
                        : (v) => setState(() => _selectedProjectId = v),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: FilledButton.icon(
                    onPressed: _adding || _selectedProjectId == null
                        ? null
                        : _addProject,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      foregroundColor: Colors.white,
                    ),
                    icon: _adding
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.add),
                    label: const Text('Add'),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),
          if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: Center(
                child: Text('لا توجد مشروعات في القائمة بعد'),
              ),
            )
          else
            ..._items.map(_buildProjectCard),
        ],
      ),
    );
  }

  Widget _buildProjectCard(InvoicesOwnerMonthlyChecklistItem item) {
    final busy = item.invoiceId != null &&
        _busyInvoiceIds.contains(item.invoiceId);
    final canManual = item.hasExtractThisMonth && item.invoiceId != null && !busy;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openInvoice(item),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      invoicesOwnerProjectHeading(
                        item.projectName,
                        item.extractNumber,
                      ),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    tooltip: 'إزالة من القائمة',
                    onPressed: () => _removeProject(item),
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                item.hasExtractThisMonth
                    ? 'تم عمل مستخلص في الشهر الجاري'
                    : 'لم يتم عمل مستخلص في الشهر الجاري',
                style: TextStyle(
                  color: item.hasExtractThisMonth
                      ? const Color(0xFF1B5E20)
                      : Colors.orange.shade800,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: item.started,
                onChanged: null,
                title: const Text('تم البدأ فيه (قيد التداول)'),
              ),
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: item.omApproved,
                onChanged: null,
                title: const Text('اعتماد نهائي من Operation Manager'),
              ),
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: item.sentToClient,
                onChanged: canManual
                    ? (v) => _setSentToClient(item, v ?? false)
                    : null,
                title: const Text('تم الإرسال للعميل (خارجياً)'),
              ),
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: item.clientReplied,
                onChanged: canManual && item.sentToClient
                    ? (v) => _setClientReplied(item, v ?? false)
                    : null,
                title: const Text('الاعتماد النهائي من العميل'),
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
