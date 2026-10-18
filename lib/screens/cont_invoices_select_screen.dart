import 'package:flutter/material.dart';

import '../models/contractor_model.dart';
import '../models/project_model.dart';
import '../models/user_model.dart';
import '../services/api_storage_service.dart';
import '../services/storage_service.dart';
import 'cont_invoices_work_screen.dart';

/// الشاشة 1: اختيار المقاول والمشروع ثم متابعة.
class ContInvoicesSelectScreen extends StatefulWidget {
  final UserModel currentUser;

  const ContInvoicesSelectScreen({super.key, required this.currentUser});

  @override
  State<ContInvoicesSelectScreen> createState() =>
      _ContInvoicesSelectScreenState();
}

class _ContInvoicesSelectScreenState extends State<ContInvoicesSelectScreen> {
  final _storage = getStorage();
  bool _loading = true;
  String? _error;
  List<ContractorModel> _contractors = const [];
  List<ProjectModel> _projects = const [];
  ContractorModel? _contractor;
  ProjectModel? _project;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_storage is! ApiStorageService) {
        throw Exception('Cont-Invoices يتطلب الاتصال بالخادم');
      }
      final api = _storage as ApiStorageService;
      final contractors = await api.getContractors();
      final projects = await api.getProjects();
      if (!mounted) return;
      setState(() {
        _contractors = contractors;
        _projects = projects;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _continue() async {
    if (_contractor == null || _project == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر المقاول والمشروع')),
      );
      return;
    }
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ContInvoicesWorkScreen(
          currentUser: widget.currentUser,
          contractor: _contractor!,
          project: _project!,
        ),
      ),
    );
    if (result != null && mounted) {
      Navigator.of(context).pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('مستخلص جديد')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      DropdownButtonFormField<ContractorModel>(
                        value: _contractor,
                        decoration: const InputDecoration(
                          labelText: 'اسم المقاول',
                          border: OutlineInputBorder(),
                        ),
                        items: _contractors
                            .map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Text(c.name),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _contractor = v),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<ProjectModel>(
                        value: _project,
                        decoration: const InputDecoration(
                          labelText: 'المشروع',
                          border: OutlineInputBorder(),
                        ),
                        items: _projects
                            .map(
                              (p) => DropdownMenuItem(
                                value: p,
                                child: Text(p.name),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _project = v),
                      ),
                      const SizedBox(height: 28),
                      FilledButton.icon(
                        onPressed: _continue,
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('متابعة'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: const Color(0xFF1B5E20),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
