import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/api_storage_service.dart';
import '../services/icon_visibility_service.dart';
import '../services/storage_service.dart';

class IconsControlScreen extends StatefulWidget {
  final UserModel currentUser;

  const IconsControlScreen({super.key, required this.currentUser});

  @override
  State<IconsControlScreen> createState() => _IconsControlScreenState();
}

class _IconsControlScreenState extends State<IconsControlScreen> {
  bool _loading = true;
  bool _saving = false;
  String _selectedRole = IconVisibilityService.roleAppAdmin;
  Map<String, Map<String, bool>> _allConfig =
      IconVisibilityService.normalizeAllConfig(null);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final storage = getStorage();
      Map<String, Map<String, bool>> config;
      if (storage is ApiStorageService) {
        config = await storage.getHomeIconsVisibilityConfig();
      } else {
        config = await storage.getHomeIconsVisibilityConfig();
      }
      if (!mounted) return;
      setState(() {
        _allConfig = config;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحميل إعدادات الأيقونات: $e')),
      );
    }
  }

  Future<void> _setRoleConfig(String role, Map<String, bool> roleConfig) async {
    setState(() => _saving = true);
    try {
      final storage = getStorage();
      if (storage is ApiStorageService) {
        await storage.setHomeIconsVisibilityForRole(
          requesterEmail: widget.currentUser.email,
          role: role,
          roleConfig: roleConfig,
        );
      } else {
        await storage.setHomeIconsVisibilityForRole(role, roleConfig);
      }
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حفظ إعدادات الأيقونات')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر الحفظ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.currentUser.canManageIconsControl) {
      return Scaffold(
        appBar: AppBar(title: const Text('Icons Control')),
        body: const Center(child: Text('غير مصرح لك باستخدام هذه الشاشة')),
      );
    }

    final roleItems = IconVisibilityService.roleTitles.entries.toList();
    final icons =
        IconVisibilityService.roleIcons[_selectedRole] ??
        const <HomeIconItem>[];
    final roleConfig =
        _allConfig[_selectedRole] ??
        IconVisibilityService.defaultForRole(_selectedRole);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Icons Control'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: DropdownButtonFormField<String>(
                    value: _selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'مستخدمين البرنامج',
                      border: OutlineInputBorder(),
                    ),
                    items: roleItems
                        .map(
                          (e) => DropdownMenuItem<String>(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) {
                            if (value == null) return;
                            setState(() => _selectedRole = value);
                          },
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    itemCount: icons.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = icons[index];
                      final isOn = IconVisibilityService.isVisible(
                        roleConfig,
                        item.id,
                      );
                      return Card(
                        child: ListTile(
                          title: Text(item.label),
                          subtitle: Text(isOn ? 'On' : 'Off'),
                          trailing: Switch(
                            value: isOn,
                            onChanged: _saving
                                ? null
                                : (value) async {
                                    final updated = Map<String, bool>.from(
                                      roleConfig,
                                    );
                                    updated[item.id] = value;
                                    setState(() {
                                      _allConfig[_selectedRole] = updated;
                                    });
                                    await _setRoleConfig(
                                      _selectedRole,
                                      updated,
                                    );
                                  },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
