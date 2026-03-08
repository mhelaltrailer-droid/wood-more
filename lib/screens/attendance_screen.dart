import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../models/project_model.dart';
import '../models/attendance_record_model.dart';
import '../services/storage_service.dart';
import '../services/location_service.dart';
import 'home_screen.dart';

/// شاشة تسجيل الحضور والانصراف للمهندس
class AttendanceScreen extends StatefulWidget {
  final UserModel currentUser;

  const AttendanceScreen({super.key, required this.currentUser});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _db = getStorage();
  final _notesController = TextEditingController();
  List<ProjectModel> _projects = [];
  ProjectModel? _selectedProject;
  String? _selectedType; // 'check_in' | 'check_out'
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    final projects = await _db.getProjects();
    setState(() => _projects = projects);
  }

  bool get _canSubmit => _selectedProject != null && _selectedType != null;

  Future<void> _requestLocationAndSetType(String type) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    final granted = await LocationService.requestPermissionIfNeeded();
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'الموقع مطلوب لتسجيل الحضور والانصراف. يرجى السماح بالوصول للموقع من إعدادات التطبيق.',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }
    setState(() => _selectedType = type);
  }

  Future<void> _submit() async {
    if (!_canSubmit || _isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final now = DateTime.now();
      final location = await LocationService.getCurrentLocation();

      if (!LocationService.looksLikeCoordinates(location)) {
        if (mounted) {
          setState(() {
            _errorMessage = 'الموقع مطلوب لتسجيل الحضور والانصراف. يرجى السماح بالوصول للموقع ثم المحاولة مرة أخرى.';
            _isLoading = false;
          });
        }
        return;
      }

      final record = AttendanceRecordModel(
        id: 0,
        userId: widget.currentUser.id,
        userName: widget.currentUser.name,
        type: _selectedType!,
        dateTime: now,
        location: location,
        projectId: _selectedProject?.id,
        projectName: _selectedProject?.name,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      await _db.addAttendanceRecord(record);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم التسجيل بنجاح'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => HomeScreen(currentUser: widget.currentUser)),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'حدث خطأ: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy/MM/dd', 'ar').format(now);
    final timeStr = DateFormat('hh:mm a', 'ar').format(now);

    final projectSelected = _selectedProject != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تسجيل الحضور والانصراف'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // اسم المهندس
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_outline),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('المهندس', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(
                          widget.currentUser.name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // المشروع (إلزامي) - يجب اختياره أولاً
            DropdownButtonFormField<ProjectModel>(
              value: _selectedProject,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'المشروع *',
                prefixIcon: Icon(Icons.business),
                border: OutlineInputBorder(),
              ),
              items: _projects
                  .map((p) => DropdownMenuItem(value: p, child: Text(p.name, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (p) => setState(() => _selectedProject = p),
            ),
            const SizedBox(height: 8),
            if (!projectSelected)
              Text(
                'يجب اختيار المشروع أولاً لتفعيل تسجيل الحضور أو الانصراف',
                style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
              ),
            const SizedBox(height: 24),

            // اختيار نوع التسجيل: حضور أو انصراف
            const Text('نوع التسجيل', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: projectSelected && !_isLoading
                        ? () => _requestLocationAndSetType('check_in')
                        : null,
                    icon: const Icon(Icons.login),
                    label: const Text('CHECK-IN'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: _selectedType == 'check_in'
                          ? Colors.green.shade700
                          : Colors.green.shade300,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: projectSelected && !_isLoading
                        ? () => _requestLocationAndSetType('check_out')
                        : null,
                    icon: const Icon(Icons.logout),
                    label: const Text('CHECK-OUT'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: _selectedType == 'check_out'
                          ? Colors.orange.shade700
                          : Colors.orange.shade300,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // التاريخ والوقت والموقع
            _ReadOnlyField(label: 'التاريخ', value: dateStr, icon: Icons.calendar_today),
            const SizedBox(height: 12),
            _ReadOnlyField(label: 'الوقت', value: timeStr, icon: Icons.access_time),
            const SizedBox(height: 24),

            // الملاحظات
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'ملاحظات',
                hintText: 'أضف أي ملاحظات (اختياري)',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),

            // زر تأكيد / حفظ
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _canSubmit && !_isLoading ? _submit : null,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle),
                label: Text(_isLoading ? 'جاري الحفظ...' : 'تأكيد / حفظ'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF1B5E20),
                ),
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade700))),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ReadOnlyField({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
