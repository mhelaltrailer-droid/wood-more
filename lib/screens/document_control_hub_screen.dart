import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/icon_visibility_service.dart';
import '../services/route_persistence.dart';
import '../services/route_restore.dart';
import '../services/storage_service.dart';
import 'home_screen.dart';
import 'ir_mir_screen.dart';
import 'module_placeholder_screen.dart';
import 'mos_itp_screen.dart';
import 'ms_sd_screen.dart';

/// محور Document Control: IR-MIR / MS-SD / QS-INV(s) / MoS-ITP
class DocumentControlHubScreen extends StatelessWidget {
  final UserModel currentUser;

  const DocumentControlHubScreen({super.key, required this.currentUser});

  static const _children = <_DocControlChild>[
    _DocControlChild(
      id: 'ir_mir',
      routeName: 'ir-mir',
      title: 'IR-MIR',
      icon: Icons.folder_special,
      subtitleFor: _IrMirSubtitle(),
    ),
    _DocControlChild(
      id: 'ms_sd',
      routeName: 'ms-sd',
      title: 'MS-SD',
      icon: Icons.architecture_outlined,
      subtitleFor: _MsSdSubtitle(),
    ),
    _DocControlChild(
      id: 'qs_invs',
      routeName: 'qs-invs',
      title: 'QS-INV(s)',
      icon: Icons.receipt_long_outlined,
      subtitleFor: _QsInvSubtitle(),
    ),
    _DocControlChild(
      id: 'mos_itp',
      routeName: 'mos-itp',
      title: 'MoS-ITP',
      icon: Icons.checklist_rtl_outlined,
      subtitleFor: _MosItpSubtitle(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final visibleIds =
        IconVisibilityService.documentControlChildrenForRole(currentUser.role)
            .toSet();
    final items = _children.where((c) => visibleIds.contains(c.id)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Control'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            await saveLastRoute('home');
            if (!context.mounted) return;
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => HomeScreen(currentUser: currentUser),
              ),
            );
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            _HubCard(
              icon: items[i].icon,
              title: items[i].title,
              subtitle: items[i].subtitleFor.resolve(currentUser),
              onTap: () => _openChild(context, items[i]),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openChild(BuildContext context, _DocControlChild child) async {
    final screen = _screenFor(child.id);
    final needsAttendance = currentUser.isSiteEngineer &&
        (child.id == 'ir_mir' ||
            (child.id == 'ms_sd' && !currentUser.canUploadMsSd) ||
            (child.id == 'mos_itp' && !currentUser.canUploadMosItp));

    if (needsAttendance) {
      final db = getStorage();
      final attendance =
          await db.getAttendanceForUserOnDate(currentUser.id, DateTime.now());
      if (!context.mounted) return;
      if (attendance.checkIn == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يجب تسجيل الحضور اولا')),
        );
        return;
      }
    }
    if (!context.mounted) return;
    await pushAndSaveRoute(context, child.routeName, screen);
  }

  Widget _screenFor(String id) {
    switch (id) {
      case 'ir_mir':
        return IrMirScreen(currentUser: currentUser);
      case 'ms_sd':
        return MsSdScreen(currentUser: currentUser);
      case 'qs_invs':
        return const ModulePlaceholderScreen(
          title: 'QS-INV(s)',
          description:
              'Quantity Survey — Invoices\nحصر الكميات والفواتير',
          icon: Icons.receipt_long_outlined,
        );
      case 'mos_itp':
        return MosItpScreen(currentUser: currentUser);
      default:
        return const SizedBox.shrink();
    }
  }
}

class _DocControlChild {
  final String id;
  final String routeName;
  final String title;
  final IconData icon;
  final _ChildSubtitle subtitleFor;

  const _DocControlChild({
    required this.id,
    required this.routeName,
    required this.title,
    required this.icon,
    required this.subtitleFor,
  });
}

abstract class _ChildSubtitle {
  const _ChildSubtitle();
  String resolve(UserModel user);
}

class _IrMirSubtitle extends _ChildSubtitle {
  const _IrMirSubtitle();
  @override
  String resolve(UserModel user) => user.isSiteEngineer
      ? 'رفع مستندات MIR أو IR حسب هيكلة المشروع'
      : 'عرض مرفقات MIR و IR من مهندسي المواقع';
}

class _MsSdSubtitle extends _ChildSubtitle {
  const _MsSdSubtitle();
  @override
  String resolve(UserModel user) => user.canUploadMsSd
      ? 'تقديم الخامات والرسومات التنفيذية — إضافة MS و SD'
      : 'عرض سجلات MS-SD المرفوعة من Document Controller';
}

class _QsInvSubtitle extends _ChildSubtitle {
  const _QsInvSubtitle();
  @override
  String resolve(UserModel user) =>
      'Quantity Survey — Invoices — حصر الكميات والفواتير';
}

class _MosItpSubtitle extends _ChildSubtitle {
  const _MosItpSubtitle();
  @override
  String resolve(UserModel user) => user.canUploadMosItp
      ? 'منهجية التنفيذ وخطة الفحص — إضافة MoS و ITP'
      : 'عرض سجلات MoS-ITP المرفوعة من Document Controller';
}

class _HubCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HubCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Row(
            children: [
              Icon(icon, size: 40, color: const Color(0xFF1B5E20)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(color: Colors.grey.shade700)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left),
            ],
          ),
        ),
      ),
    );
  }
}
