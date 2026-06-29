import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/activity_log_model.dart';
import '../models/user_model.dart';
import '../services/api_storage_service.dart';
import '../services/storage_service.dart';
import '../utils/activity_log_display.dart';

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
        actionType: (_selectedActionType == null || _selectedActionType!.isEmpty)
            ? null
            : _selectedActionType,
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
      case 'attendance_check_in':
      case 'attendance_check_out':
      case 'attendance_record':
        return Colors.teal;
      case 'plan_save_today':
      case 'plan_save_tomorrow':
      case 'plan_save_future':
      case 'plan_execute':
        return Colors.green;
      case 'plan_update_today':
      case 'plan_update_tomorrow':
      case 'plan_update_future':
      case 'plan_execute_edited':
        return Colors.orange;
      case 'plan_postpone':
        return Colors.deepOrange;
      case 'daily_report_delete':
      case 'detailed_report_delete':
      case 'user_delete':
      case 'project_delete':
        return Colors.red;
      default:
        return const Color(0xFF1B5E20);
    }
  }

  IconData _iconForActionType(String actionType) {
    switch (actionType) {
      case 'login':
        return Icons.login;
      case 'attendance_check_in':
      case 'attendance_check_out':
      case 'attendance_record':
        return Icons.fingerprint;
      case 'plan_save_today':
      case 'plan_save_tomorrow':
      case 'plan_save_future':
        return Icons.event_note;
      case 'plan_execute':
      case 'plan_execute_edited':
        return Icons.task_alt;
      case 'plan_postpone':
        return Icons.pause_circle_outline;
      case 'plan_update_today':
      case 'plan_update_tomorrow':
      case 'plan_update_future':
        return Icons.edit_note;
      default:
        return Icons.history;
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      ..._users.map(
                        (u) => DropdownMenuItem<int?>(
                          value: u.id,
                          child: Text('${u.name} — ${u.email}'),
                        ),
                      ),
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
                    items: activityLogFilterActionTypes
                        .map(
                          (t) => DropdownMenuItem<String?>(
                            value: t['value'],
                            child: Text(t['label']!),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedActionType = v),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _loading ? null : _run,
                    icon: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
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
                'إجمالي الحركات: ${_logs.length}',
                style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
              ),
            ),
          if (_hasSearched && _logs.isEmpty && !_loading)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('لا توجد حركات خلال المدة المختارة.'),
              ),
            ),
          ..._logs.map((log) {
            final narrative = activityLogNarrative(log, users: _users);
            final email = activityLogUserEmail(log, users: _users);
            final color = _colorForActionType(log.actionType);

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                leading: CircleAvatar(
                  radius: 20,
                  backgroundColor: color.withOpacity(0.12),
                  child: Icon(_iconForActionType(log.actionType), color: color, size: 20),
                ),
                title: Text(
                  narrative,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, height: 1.35),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    email,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
