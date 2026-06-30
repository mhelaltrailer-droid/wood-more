import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_persistence.dart';
import '../services/storage_service.dart';
import '../services/api_storage_service.dart';
import '../services/icon_visibility_service.dart';
import '../core/route_observer.dart';
import 'login_screen.dart';
import 'notifications_screen.dart';
import 'shop_darwing_notifications_screen.dart';
import 'manager_withdrawal_requests_screen.dart';
import 'reorderable_home_screen.dart';
import '../widgets/shop_darwing_notification_app_bar_icon.dart';

/// الصفحة الرئيسية - تختلف حسب دور المستخدم
class HomeScreen extends StatefulWidget {
  final UserModel currentUser;

  const HomeScreen({super.key, required this.currentUser});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with RouteAware, SingleTickerProviderStateMixin {
  bool _subscribed = false;
  Map<String, bool>? _iconConfig;
  int _unreadNotificationsCount = 0;
  int _unreadShopDarwingNotificationsCount = 0;
  int _pendingWithdrawalRequestsCount = 0;
  int _pendingReportsSysCount = 0;
  int _pendingShopDrawingCount = 0;
  Timer? _notificationsPollTimer;
  late final AnimationController _wrRotateController;

  bool get _canUseNotifications => widget.currentUser.canUseNotifications;

  bool get _canUseShopDarwingNotification =>
      widget.currentUser.canUseShopDarwingNotification;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_subscribed) return;
    final route = ModalRoute.of(context);
    if (route is ModalRoute<void>) {
      RouteObserverProvider.routeObserver.subscribe(this, route);
      _subscribed = true;
    }
  }

  @override
  void dispose() {
    _notificationsPollTimer?.cancel();
    _wrRotateController.dispose();
    RouteObserverProvider.routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    saveLastRoute('home');
    _loadIconsConfig();
    _loadUnreadNotificationsCount();
    _loadUnreadShopDarwingNotificationsCount();
    _loadPendingWithdrawalActionsCount();
    _loadPendingReportsSysCount();
    _loadPendingShopDrawingCount();
  }

  @override
  void initState() {
    super.initState();
    _wrRotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _loadIconsConfig();
    _loadUnreadNotificationsCount();
    _loadUnreadShopDarwingNotificationsCount();
    _loadPendingWithdrawalActionsCount();
    _loadPendingReportsSysCount();
    _loadPendingShopDrawingCount();
    _startNotificationsPollingIfManager();
  }

  Future<void> _loadIconsConfig() async {
    try {
      final storage = getStorage();
      final role = widget.currentUser.role;
      final all = storage is ApiStorageService
          ? await storage.getHomeIconsVisibilityConfig()
          : await storage.getHomeIconsVisibilityConfig();
      if (!mounted) return;
      setState(() {
        _iconConfig = all[role] ?? IconVisibilityService.defaultForRole(role);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _iconConfig = IconVisibilityService.defaultForRole(
          widget.currentUser.role,
        );
      });
    }
  }

  Future<void> _loadUnreadNotificationsCount() async {
    if (!_canUseNotifications) {
      if (!mounted) return;
      setState(() => _unreadNotificationsCount = 0);
      return;
    }
    try {
      final prevCount = _unreadNotificationsCount;
      final storage = getStorage();
      final count = storage is ApiStorageService
          ? await storage.getUnreadNotificationsCount(widget.currentUser.id)
          : await storage.getUnreadNotificationsCount(widget.currentUser.id);
      if (!mounted) return;
      setState(() => _unreadNotificationsCount = count);
      if (count > prevCount && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('لديك ${count - prevCount} إشعار جديد'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _unreadNotificationsCount = 0);
    }
  }

  Future<void> _loadUnreadShopDarwingNotificationsCount() async {
    if (!_canUseShopDarwingNotification) {
      if (!mounted) return;
      setState(() => _unreadShopDarwingNotificationsCount = 0);
      return;
    }
    try {
      final storage = getStorage();
      final count = storage is ApiStorageService
          ? await storage.getUnreadShopDarwingNotificationsCount(
              widget.currentUser.id,
            )
          : await storage.getUnreadShopDarwingNotificationsCount(
              widget.currentUser.id,
            );
      if (!mounted) return;
      setState(() => _unreadShopDarwingNotificationsCount = count);
    } catch (_) {
      if (!mounted) return;
      setState(() => _unreadShopDarwingNotificationsCount = 0);
    }
  }

  Future<void> _loadPendingWithdrawalActionsCount() async {
    if (!widget.currentUser.canActOnWithdrawalRequests) {
      if (mounted) {
        setState(() => _pendingWithdrawalRequestsCount = 0);
        _wrRotateController.stop();
        _wrRotateController.reset();
      }
      return;
    }
    try {
      final storage = getStorage();
      final c = await storage.countPendingWithdrawalActionsForManager(
        userId: widget.currentUser.id,
        role: widget.currentUser.role,
      );
      if (!mounted) return;
      setState(() => _pendingWithdrawalRequestsCount = c);
      if (c > 0) {
        if (!_wrRotateController.isAnimating) {
          _wrRotateController.repeat();
        }
      } else {
        _wrRotateController.stop();
        _wrRotateController.reset();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _pendingWithdrawalRequestsCount = 0);
      _wrRotateController.stop();
      _wrRotateController.reset();
    }
  }

  Future<void> _loadPendingReportsSysCount() async {
    if (!widget.currentUser.canParticipateInReportsSys) {
      if (mounted) setState(() => _pendingReportsSysCount = 0);
      return;
    }
    try {
      final storage = getStorage();
      final c = await storage.countPendingReportsSys(widget.currentUser.id);
      if (!mounted) return;
      setState(() => _pendingReportsSysCount = c);
    } catch (_) {
      if (!mounted) return;
      setState(() => _pendingReportsSysCount = 0);
    }
  }

  Future<void> _loadPendingShopDrawingCount() async {
    if (!widget.currentUser.canAccessShopDrawingHomeIcon) {
      if (mounted) setState(() => _pendingShopDrawingCount = 0);
      return;
    }
    try {
      final storage = getStorage();
      if (storage is! ApiStorageService) {
        if (mounted) setState(() => _pendingShopDrawingCount = 0);
        return;
      }
      final c = await storage.getShopDrawingPendingCount(widget.currentUser.id);
      if (!mounted) return;
      setState(() => _pendingShopDrawingCount = c);
    } catch (_) {
      if (!mounted) return;
      setState(() => _pendingShopDrawingCount = 0);
    }
  }

  void _startNotificationsPollingIfManager() {
    if (!_canUseNotifications &&
        !_canUseShopDarwingNotification &&
        !widget.currentUser.canAccessShopDrawingHomeIcon) {
      return;
    }
    _notificationsPollTimer?.cancel();
    _notificationsPollTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) {
        if (_canUseNotifications) _loadUnreadNotificationsCount();
        if (_canUseShopDarwingNotification) {
          _loadUnreadShopDarwingNotificationsCount();
        }
        _loadPendingWithdrawalActionsCount();
        _loadPendingReportsSysCount();
        _loadPendingShopDrawingCount();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = widget.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/logo.png',
                height: 32,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.forest, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Text('Wood & More'),
            ],
          ),
        ),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        actions: [
          if (currentUser.canActOnWithdrawalRequests)
            _pendingWithdrawalRequestsCount > 0
                ? RotationTransition(
                    turns: _wrRotateController,
                    child: IconButton(
                      tooltip: currentUser.role == 'site_engineer_manager'
                          ? 'طلبات سحب خامات وتأجيل خطط بانتظار قراركم'
                          : 'طلبات سحب خامات',
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ManagerWithdrawalRequestsScreen(
                              currentUser: currentUser,
                            ),
                          ),
                        );
                        await _loadPendingWithdrawalActionsCount();
                      },
                      icon: const Icon(Icons.inventory_2_outlined),
                    ),
                  )
                : IconButton(
                    tooltip: currentUser.role == 'site_engineer_manager'
                        ? 'طلبات سحب خامات وتأجيل خطط بانتظار قراركم'
                        : 'طلبات سحب خامات',
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ManagerWithdrawalRequestsScreen(
                            currentUser: currentUser,
                          ),
                        ),
                      );
                      await _loadPendingWithdrawalActionsCount();
                    },
                    icon: const Icon(Icons.inventory_2_outlined),
                  ),
          if (currentUser.canUseShopDarwingNotification)
            IconButton(
              tooltip: 'إشعارات',
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ShopDarwingNotificationsScreen(
                      currentUser: currentUser,
                    ),
                  ),
                );
                await _loadUnreadShopDarwingNotificationsCount();
              },
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const ShopDarwingNotificationAppBarIcon(),
                  if (_unreadShopDarwingNotificationsCount > 0)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(minWidth: 18),
                        child: Text(
                          _unreadShopDarwingNotificationsCount > 99
                              ? '99+'
                              : '$_unreadShopDarwingNotificationsCount',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (_canUseNotifications)
            IconButton(
              tooltip: 'الإشعارات',
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => NotificationsScreen(currentUser: currentUser),
                  ),
                );
                await _loadUnreadNotificationsCount();
              },
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications),
                  if (_unreadNotificationsCount > 0)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(minWidth: 18),
                        child: Text(
                          _unreadNotificationsCount > 99
                              ? '99+'
                              : '$_unreadNotificationsCount',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await clearCurrentUser();
              await clearLastRoute();
              if (!context.mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: ReorderableHomeScreen(
        user: currentUser,
        iconConfig: _iconConfig,
        pendingReportsSysCount: _pendingReportsSysCount,
        pendingShopDrawingCount: _pendingShopDrawingCount,
        onReportsSysReturn: _loadPendingReportsSysCount,
        onShopDrawingReturn: _loadPendingShopDrawingCount,
      ),
    );
  }
}
