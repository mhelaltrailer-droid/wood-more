import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../services/api_storage_service.dart';
import '../services/local_cache_service.dart';
import '../services/storage_service.dart';

class DailyMovementScreen extends StatefulWidget {
  final UserModel currentUser;

  const DailyMovementScreen({super.key, required this.currentUser});

  @override
  State<DailyMovementScreen> createState() => _DailyMovementScreenState();
}

class _DailyMovementScreenState extends State<DailyMovementScreen> {
  static const Duration _cacheTtl = Duration(minutes: 5);
  DateTime _selectedDate = DateTime.now();
  bool _loading = false;
  Map<String, dynamic>? _summary;

  String get _cacheKey {
    final d = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    return 'daily_movement_${d.toIso8601String()}';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null) return;
    setState(() => _selectedDate = DateTime(picked.year, picked.month, picked.day));
    await _load();
  }

  Future<void> _load() async {
    final hadDataBefore = _summary != null;
    if (mounted) setState(() => _loading = !hadDataBefore);
    final cached = LocalCacheService.instance.getMap(_cacheKey);
    if (cached != null && mounted) {
      setState(() => _summary = cached);
    }
    try {
      final storage = getStorage();
      if (storage is! ApiStorageService) {
        throw Exception('شاشة الحركة اليومية متاحة في وضع API فقط');
      }
      final data = await storage.getDailyPlanMovementSummary(
        date: _selectedDate,
        requesterEmail: widget.currentUser.email,
      );
      if (!mounted) return;
      setState(() => _summary = data);
      await LocalCacheService.instance.setMap(_cacheKey, data, ttl: _cacheTtl);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحميل الحركة اليومية: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _kpiCard({
    required String title,
    required int value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 10),
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            '$value',
            style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text('مشروع', style: TextStyle(color: color.withValues(alpha: 0.8))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('yyyy-MM-dd');
    final confirmed = (_summary?['confirmed_projects'] ?? 0) as int;
    final edited = (_summary?['confirmed_edited_projects'] ?? 0) as int;
    final postponed = (_summary?['postponed_projects'] ?? 0) as int;
    final total = (_summary?['total_projects'] ?? 0) as int;
    return Scaffold(
      appBar: AppBar(
        title: const Text('الحركة اليومية'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text('التاريخ: ${fmt.format(_selectedDate)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _pickDate,
                    icon: const Icon(Icons.date_range),
                    label: const Text('تغيير التاريخ'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.35,
              children: [
                _kpiCard(
                  title: 'تم التنفيذ',
                  value: confirmed,
                  color: Colors.green,
                  icon: Icons.check_circle,
                ),
                _kpiCard(
                  title: 'تم التعديل ثم التنفيذ',
                  value: edited,
                  color: Colors.blue,
                  icon: Icons.edit_note,
                ),
                _kpiCard(
                  title: 'تم التأجيل',
                  value: postponed,
                  color: Colors.orange,
                  icon: Icons.pause_circle,
                ),
                _kpiCard(
                  title: 'إجمالي خطط اليوم',
                  value: total,
                  color: const Color(0xFF1B5E20),
                  icon: Icons.summarize,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
