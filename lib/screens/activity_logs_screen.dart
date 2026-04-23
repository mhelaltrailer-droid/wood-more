import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/activity_log_model.dart';
import '../models/user_model.dart';
import '../services/api_storage_service.dart';
import '../services/storage_service.dart';

class ActivityLogsScreen extends StatefulWidget {
  final UserModel currentUser;

  const ActivityLogsScreen({super.key, required this.currentUser});

  @override
  State<ActivityLogsScreen> createState() => _ActivityLogsScreenState();
}

class _ActivityLogsScreenState extends State<ActivityLogsScreen> {
  DateTime _dateFrom = DateTime.now();
  DateTime _dateTo = DateTime.now();
  TimeOfDay _timeFrom = const TimeOfDay(hour: 0, minute: 0);
  TimeOfDay _timeTo = const TimeOfDay(hour: 23, minute: 59);
  bool _loading = false;
  bool _hasSearched = false;
  List<ActivityLogModel> _logs = [];
  List<UserModel> _users = [];
  int? _selectedUserId;
  String? _selectedActionType;

  static const List<Map<String, String>> _actionTypes = [
    {'value': '', 'label': 'كل أنواع الحركة'},
    {'value': 'login', 'label': 'تسجيل دخول'},
    {'value': 'attendance_record', 'label': 'تسجيل حضور/انصراف'},
    {'value': 'daily_report_view', 'label': 'عرض تقرير يومي'},
    {'value': 'daily_report_create', 'label': 'إنشاء تقرير يومي'},
    {'value': 'daily_report_update', 'label': 'تعديل تقرير يومي'},
    {'value': 'daily_report_delete', 'label': 'حذف تقرير يومي'},
    {'value': 'detailed_report_view', 'label': 'عرض تقرير مفصل'},
    {'value': 'detailed_report_create', 'label': 'إنشاء تقرير مفصل'},
    {'value': 'detailed_report_update', 'label': 'تعديل تقرير مفصل'},
    {'value': 'detailed_report_delete', 'label': 'حذف تقرير مفصل'},
    {'value': 'user_create', 'label': 'إنشاء مستخدم'},
    {'value': 'user_update', 'label': 'تعديل مستخدم'},
    {'value': 'user_delete', 'label': 'حذف مستخدم'},
    {'value': 'project_create', 'label': 'إنشاء مشروع'},
    {'value': 'project_update', 'label': 'تعديل مشروع'},
    {'value': 'project_delete', 'label': 'حذف مشروع'},
    {'value': 'other', 'label': 'حركة أخرى'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final storage = getStorage();
      if (storage is! ApiStorageService) return;
      final users = await storage.getUsers();
      if (!mounted) return;
      users.sort((a, b) => a.name.compareTo(b.name));
      setState(() => _users = users);
    } catch (_) {}
  }

  Future<void> _pickDate(bool isFrom) async {
    final current = isFrom ? _dateFrom : _dateTo;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _dateFrom = DateTime(picked.year, picked.month, picked.day);
      } else {
        _dateTo = DateTime(picked.year, picked.month, picked.day);
      }
    });
  }

  Future<void> _pickTime(bool isFrom) async {
    final current = isFrom ? _timeFrom : _timeTo;
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _timeFrom = picked;
      } else {
        _timeTo = picked;
      }
    });
  }

  Future<void> _run() async {
    final fromDateTime = DateTime(
      _dateFrom.year,
      _dateFrom.month,
      _dateFrom.day,
      _timeFrom.hour,
      _timeFrom.minute,
    );
    final toDateTime = DateTime(
      _dateTo.year,
      _dateTo.month,
      _dateTo.day,
      _timeTo.hour,
      _timeTo.minute,
      59,
      999,
    );
    if (toDateTime.isBefore(fromDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تأكد أن المدة الزمنية صحيحة: من <= إلى')),
      );
      return;
    }
    setState(() {
      _loading = true;
      _hasSearched = true;
    });
    try {
      final storage = getStorage();
      if (storage is! ApiStorageService) {
        throw Exception('شاشة سجل الحركة متاحة في وضع الخادم API فقط');
      }
      final logs = await storage.getActivityLogs(
        dateFrom: fromDateTime,
        dateTo: toDateTime,
        requesterEmail: widget.currentUser.email,
        userId: _selectedUserId,
        actionType: (_selectedActionType == null || _selectedActionType!.isEmpty) ? null : _selectedActionType,
      );
      if (!mounted) return;
      setState(() => _logs = logs);
    } catch (e) {
      if (!mounted) return;
      setState(() => _logs = []);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحميل سجل الحركة: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _colorForActionType(String actionType) {
    switch (actionType) {
      case 'login':
        return Colors.indigo;
      case 'attendance_record':
        return Colors.teal;
      case 'daily_report_view':
      case 'detailed_report_view':
      case 'activity_log_view':
        return Colors.blue;
      case 'daily_report_create':
      case 'detailed_report_create':
      case 'user_create':
      case 'project_create':
        return Colors.green;
      case 'daily_report_update':
      case 'detailed_report_update':
      case 'user_update':
      case 'project_update':
        return Colors.orange;
      case 'daily_report_delete':
      case 'detailed_report_delete':
      case 'user_delete':
      case 'project_delete':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _colorForStatusCode(int statusCode) {
    if (statusCode >= 500) return Colors.red;
    if (statusCode >= 400) return Colors.orange;
    if (statusCode >= 300) return Colors.blueGrey;
    return Colors.green;
  }

  String _shortEndpoint(String endpoint) {
    if (endpoint.length <= 32) return endpoint;
    return '...${endpoint.substring(endpoint.length - 32)}';
  }

  IconData _iconForActionType(String actionType) {
    switch (actionType) {
      case 'login':
        return Icons.login;
      case 'attendance_record':
        return Icons.fingerprint;
      case 'daily_report_create':
      case 'detailed_report_create':
      case 'user_create':
      case 'project_create':
        return Icons.add_circle_outline;
      case 'daily_report_update':
      case 'detailed_report_update':
      case 'user_update':
      case 'project_update':
        return Icons.edit_note;
      case 'daily_report_delete':
      case 'detailed_report_delete':
      case 'user_delete':
      case 'project_delete':
        return Icons.delete_outline;
      default:
        return Icons.history;
    }
  }

  String _statusLabel(int statusCode) {
    if (statusCode >= 500) return 'خطأ خادم $statusCode';
    if (statusCode >= 400) return 'طلب غير صالح $statusCode';
    if (statusCode >= 300) return 'غير معدل $statusCode';
    return 'نجاح $statusCode';
  }

  String _displayUserName(ActivityLogModel log) {
    final name = log.userName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'حركة نظام (بدون مستخدم)';
  }

  String _displayUserEmail(ActivityLogModel log) {
    final email = log.userEmail?.trim();
    if (email != null && email.isNotEmpty) return email;
    return 'لا يوجد بريد للمستخدم في هذا الطلب';
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('yyyy-MM-dd HH:mm');
    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل الحركة'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('فلترة المدة', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _pickDate(true),
                          child: Text('من: ${DateFormat('yyyy-MM-dd').format(_dateFrom)}'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _pickDate(false),
                          child: Text('إلى: ${DateFormat('yyyy-MM-dd').format(_dateTo)}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _pickTime(true),
                          child: Text('من الساعة: ${_timeFrom.format(context)}'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _pickTime(false),
                          child: Text('إلى الساعة: ${_timeTo.format(context)}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    value: _selectedUserId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'اسم المستخدم',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('جميع المستخدمين')),
                      ..._users.map((u) => DropdownMenuItem<int?>(value: u.id, child: Text(u.name))),
                    ],
                    onChanged: (v) => setState(() => _selectedUserId = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    value: _selectedActionType,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'نوع الحركة',
                      border: OutlineInputBorder(),
                    ),
                    items: _actionTypes
                        .map((t) => DropdownMenuItem<String?>(value: t['value'], child: Text(t['label']!)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedActionType = v),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _loading ? null : _run,
                    icon: _loading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.search),
                    label: Text(_loading ? 'جاري التحميل...' : 'عرض سجل الحركة'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_hasSearched && _logs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'إجمالي الحركات: ${_logs.length}  •  اضغط على أي حركة لعرض التفاصيل',
                style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
              ),
            ),
          if (_hasSearched && _logs.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: const Text(
                'ملاحظة: بعض الحركات تُسجل بدون بيانات مستخدم (مثل طلبات نظام عامة)، لذلك قد يظهر "حركة نظام (بدون مستخدم)".',
                style: TextStyle(fontSize: 12.5),
              ),
            ),
          if (_hasSearched && _logs.isEmpty && !_loading)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('لا توجد حركات خلال المدة المختارة.'),
              ),
            ),
          ..._logs.map((log) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  leading: CircleAvatar(
                    radius: 17,
                    backgroundColor: _colorForActionType(log.actionType).withOpacity(0.12),
                    child: Icon(
                      _iconForActionType(log.actionType),
                      color: _colorForActionType(log.actionType),
                      size: 18,
                    ),
                  ),
                  title: Text(
                    _displayUserName(log),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                  ),
                  subtitle: Text(
                    '${log.actionLabel.isNotEmpty ? log.actionLabel : log.actionType}  •  ${fmt.format(log.createdAt.toLocal())}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _colorForStatusCode(log.statusCode).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _colorForStatusCode(log.statusCode).withOpacity(0.4)),
                    ),
                    child: Text(
                      _statusLabel(log.statusCode),
                      style: TextStyle(
                        color: _colorForStatusCode(log.statusCode),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _MetaChip(
                          icon: Icons.http,
                          label: '${log.method.toUpperCase()} ${_shortEndpoint(log.endpoint)}',
                        ),
                        _MetaChip(
                          icon: Icons.person_outline,
                          label: _displayUserEmail(log),
                        ),
                        _MetaChip(
                          icon: Icons.tag,
                          label: 'ID: ${log.userId?.toString() ?? '—'}',
                        ),
                      ],
                    ),
                    if (log.details.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Text(
                          log.details,
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5),
                        ),
                      ),
                    ],
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
