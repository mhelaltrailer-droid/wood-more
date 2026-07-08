import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../utils/app_release_install_messages.dart';

/// Bottom sheet يظهر بعد تنزيل APK — خطوات: تنزيل → تثبيت → فتح.
class AppReleaseInstallBottomSheet extends StatefulWidget {
  final String versionLabel;
  final String fileSizeLabel;
  final Future<String?> Function() onInstallNow;
  final Future<bool> Function() onVerifyUpdated;

  const AppReleaseInstallBottomSheet({
    super.key,
    required this.versionLabel,
    required this.fileSizeLabel,
    required this.onInstallNow,
    required this.onVerifyUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required String versionLabel,
    required String fileSizeLabel,
    required Future<String?> Function() onInstallNow,
    required Future<bool> Function() onVerifyUpdated,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 8,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: AppReleaseInstallBottomSheet(
          versionLabel: versionLabel,
          fileSizeLabel: fileSizeLabel,
          onInstallNow: onInstallNow,
          onVerifyUpdated: onVerifyUpdated,
        ),
      ),
    );
  }

  @override
  State<AppReleaseInstallBottomSheet> createState() =>
      _AppReleaseInstallBottomSheetState();
}

class _AppReleaseInstallBottomSheetState
    extends State<AppReleaseInstallBottomSheet> {
  bool _installAttempted = false;
  bool _installVerified = false;
  bool _installing = false;
  bool _verifying = false;
  String? _installError;
  String? _installInfo;

  Future<void> _handleInstall() async {
    setState(() {
      _installing = true;
      _installError = null;
      _installInfo = null;
    });
    try {
      final message = await widget.onInstallNow();
      if (!mounted) return;
      final settingsInfo = isInstallSettingsMessage(message);
      setState(() {
        _installAttempted = message == null;
        _installing = false;
        _installError = settingsInfo ? null : message;
        _installInfo = settingsInfo ? installSettingsUserMessage(message!) : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _installing = false;
        _installError = '$e';
      });
    }
  }

  Future<void> _handleVerify() async {
    setState(() {
      _verifying = true;
      _installError = null;
      _installInfo = null;
    });
    try {
      final updated = await widget.onVerifyUpdated();
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _installVerified = updated;
        if (!updated) {
          _installError =
              'لم يتغيّر إصدار التطبيق بعد. أكمل التثبيت من شاشة Android ثم أعد المحاولة.';
        }
      });
      if (updated && mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم التحديث — ${widget.versionLabel}. أغلِق التطبيق وافتحه من جديد إن لزم.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _installError = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final stepInstallActive = !_installVerified;
    final stepOpenActive = _installAttempted && !_installVerified;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.system_update_alt, color: Colors.green.shade700, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'تم تنزيل التحديث',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${widget.versionLabel} (${widget.fileSizeLabel})',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _stepRow(
          done: true,
          active: false,
          title: '1. تنزيل الملف',
          subtitle: 'مكتمل',
        ),
        _stepRow(
          done: _installAttempted,
          active: stepInstallActive,
          title: '2. تثبيت التحديث',
          subtitle: _installAttempted
              ? 'تم فتح المثبّت — أكمل من شاشة Android'
              : 'اضغط «تثبيت الآن»',
        ),
        _stepRow(
          done: _installVerified,
          active: stepOpenActive,
          title: '3. تفعيل النسخة الجديدة',
          subtitle: _installVerified
              ? 'تم التحقق من التحديث'
              : 'بعد التثبيت اضغط «تحقق من التحديث»',
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'سيظهر مثبّت Android. اضغط «تثبيت» واسمح للتطبيق بتثبيت التحديثات إن طُلب منك.',
            style: TextStyle(fontSize: 13, color: Colors.blue.shade900),
          ),
        ),
        if (_installError != null) ...[
          const SizedBox(height: 12),
          Text(
            _installError!,
            style: TextStyle(color: Colors.red.shade700, fontSize: 13),
          ),
        ],
        if (_installInfo != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _installInfo!,
              style: TextStyle(fontSize: 13, color: Colors.orange.shade900),
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (!_installVerified) ...[
          FilledButton.icon(
            onPressed: _installing ? null : _handleInstall,
            icon: _installing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.install_mobile),
            label: Text(_installing ? 'جاري الفتح...' : 'تثبيت الآن'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          if (_installAttempted) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _verifying ? null : _handleVerify,
              icon: _verifying
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: Text(
                _verifying ? 'جاري التحقق...' : 'تحقق من التحديث',
              ),
            ),
          ],
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('لاحقاً'),
          ),
        ],
      ],
    );
  }

  Widget _stepRow({
    required bool done,
    required bool active,
    required String title,
    required String subtitle,
  }) {
    IconData icon;
    Color color;
    if (done) {
      icon = Icons.check_circle;
      color = Colors.green;
    } else if (active) {
      icon = Icons.radio_button_checked;
      color = const Color(0xFF1B5E20);
    } else {
      icon = Icons.radio_button_unchecked;
      color = Colors.grey;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: active || done ? Colors.black87 : Colors.black45,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// يقارن إصدار الجهاز مع تسمية النسخة على الخادم (أرقام فقط).
Future<bool> appReleaseVersionMatchesLabel(String versionLabel) async {
  final info = await PackageInfo.fromPlatform();
  final serverDigits = RegExp(r'\d+')
      .allMatches(versionLabel)
      .map((m) => m.group(0)!)
      .join();
  final deviceDigits = '${info.version}${info.buildNumber}'
      .replaceAll(RegExp(r'[^\d]'), '');
  if (serverDigits.isEmpty) return false;
  return deviceDigits.contains(serverDigits) ||
      serverDigits.contains(deviceDigits.replaceAll(RegExp(r'^0+'), ''));
}
