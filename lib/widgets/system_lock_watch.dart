import 'dart:async';

import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../screens/login_screen.dart';
import '../services/auth_persistence.dart';
import '../services/storage_service.dart';
import '../services/system_lock_service.dart';

/// Polls maintenance lock while a user session is active and signs out non-admin users.
class SystemLockWatch extends StatefulWidget {
  final UserModel user;
  final Widget child;

  const SystemLockWatch({
    super.key,
    required this.user,
    required this.child,
  });

  @override
  State<SystemLockWatch> createState() => _SystemLockWatchState();
}

class _SystemLockWatchState extends State<SystemLockWatch>
    with WidgetsBindingObserver {
  static const Duration _pollInterval = Duration(seconds: 30);
  Timer? _timer;
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(_pollInterval, (_) => _checkMaintenanceLock());
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkMaintenanceLock());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkMaintenanceLock();
    }
  }

  Future<void> _checkMaintenanceLock() async {
    if (_signingOut || !mounted) return;
    if (isMaintenanceBypassEmail(widget.user.email)) return;
    try {
      final locked = await getStorage().isSystemLocked();
      if (!shouldForceSignOutForMaintenance(widget.user, locked)) return;
    } catch (_) {
      return;
    }
    _signingOut = true;
    await clearCurrentUser();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(forcedMaintenanceSignOut: true),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
