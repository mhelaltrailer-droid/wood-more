import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_persistence.dart';
import '../services/storage_service.dart';
import '../services/api_storage_service.dart';
import '../services/icon_visibility_service.dart';
import '../core/route_observer.dart';
import '../core/polling_intervals.dart';
import 'login_screen.dart';
import 'notifications_screen.dart';
import 'shop_darwing_notifications_screen.dart';
import 'meetings_notifications_screen.dart';
import 'app_versions_screen.dart';
import 'manager_withdrawal_requests_screen.dart';
import 'reorderable_home_screen.dart';
import '../widgets/shop_darwing_notification_app_bar_icon.dart';
import '../widgets/meetings_notification_app_bar_icon.dart';
import '../services/view_as_role_session.dart';
import '../services/view_as_role_options.dart';
import '../core/role_labels.dart';
import '../services/notification_view_as_filter.dart';

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
  int _pendingInvoicesOwnerCount = 0;
  int _unreadMeetingsNotificationsCount = 0;
  bool _hasAppReleaseUpdate = false;
  Timer? _notificationsPollTimer;
  late final AnimationController _wrRotateController;

  /// المستخدم الفعّال (بعد View as إن وُجد).
  UserModel get _user {
    final base = widget.currentUser;
    if (!base.canUseViewAsRole) return base;
    return base.withViewAsRole(ViewAsRoleSession.viewAsRole);
  }

  bool get _canUseNotifications => _user.canUseNotifications;

  bool get _canUseShopDarwingNotification =>
      _user.canUseShopDarwingNotification;

  bool get _canUseMeetingsNotification =>
      _user.canUseMeetingsNotification;

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
    _loadUnreadMeetingsNotificationsCount();
    _loadPendingWithdrawalActionsCount();
    _loadPendingReportsSysCount();
    _loadPendingShopDrawingCount();
    _loadPendingInvoicesOwnerCount();
    _loadAppReleaseUpdateBadge();
  }

  @override
  void initState() {
    super.initState();
    // كل فتح للرئيسية يبدأ بوضع المسؤول الأساسي (لا يُحفظ View as بين الجلسات).
    if (widget.currentUser.canUseViewAsRole) {
      ViewAsRoleSession.clear();
      ViewAsRoleSession.setViewAs(
        requesterUserId: widget.currentUser.id,
        role: null,
      );
    }
    _wrRotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _loadIconsConfig();
    _loadUnreadNotificationsCount();
    _loadUnreadShopDarwingNotificationsCount();
    _loadUnreadMeetingsNotificationsCount();
    _loadPendingWithdrawalActionsCount();
    _loadPendingReportsSysCount();
    _loadPendingShopDrawingCount();
    _loadPendingInvoicesOwnerCount();
    _loadAppReleaseUpdateBadge();
    _startNotificationsPollingIfManager();
  }

  Future<void> _onViewAsChanged(String value) async {
    if (!widget.currentUser.canUseViewAsRole) return;
    ViewAsRoleSession.setViewAs(
      requesterUserId: widget.currentUser.id,
      role: value == ViewAsRoleSession.primaryOptionValue ? null : value,
    );
    setState(() {});
    await _loadIconsConfig();
    await _loadUnreadNotificationsCount();
    await _loadUnreadShopDarwingNotificationsCount();
    await _loadUnreadMeetingsNotificationsCount();
    await _loadPendingWithdrawalActionsCount();
    await _loadPendingReportsSysCount();
    await _loadPendingShopDrawingCount();
    await _loadPendingInvoicesOwnerCount();
    await _loadAppReleaseUpdateBadge();
    _notificationsPollTimer?.cancel();
    _startNotificationsPollingIfManager();
  }

  Future<void> _loadIconsConfig() async {
    try {
      final storage = getStorage();
      final role = _user.role;
      final all = storage is ApiStorageService
          ? await storage.getHomeIconsVisibilityConfig()
          : await storage.getHomeIconsVisibilityConfig();
      if (!mounted) return;
      final defaults = IconVisibilityService.defaultForRole(role);
      final stored = all[role];
      final merged = Map<String, bool>.from(defaults);
      if (stored != null) {
        stored.forEach((key, value) {
          merged[key] = value;
        });
      }
      setState(() {
        _iconConfig = merged;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _iconConfig = IconVisibilityService.defaultForRole(
          _user.role,
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
      int count;
      if (_user.isViewingAsOtherRole && storage is ApiStorageService) {
        final items = await storage.getNotificationsForUser(
          _user.id,
          limit: 100,
          offset: 0,
        );
        count = items
            .where(
              (n) =>
                  !n.isRead &&
                  isNotificationVisibleForViewAsRole(
                    eventType: n.eventType,
                    viewAsRole: _user.viewAsRole,
                  ),
            )
            .length;
      } else {
        count = await storage.getUnreadNotificationsCount(_user.id);
      }
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
              _user.id,
            )
          : await storage.getUnreadShopDarwingNotificationsCount(
              _user.id,
            );
      if (!mounted) return;
      setState(() => _unreadShopDarwingNotificationsCount = count);
    } catch (_) {
      if (!mounted) return;
      setState(() => _unreadShopDarwingNotificationsCount = 0);
    }
  }

  Future<void> _loadUnreadMeetingsNotificationsCount() async {
    if (!_canUseMeetingsNotification) {
      if (!mounted) return;
      setState(() => _unreadMeetingsNotificationsCount = 0);
      return;
    }
    try {
      final storage = getStorage();
      if (storage is! ApiStorageService) {
        if (mounted) setState(() => _unreadMeetingsNotificationsCount = 0);
        return;
      }
      final count = await storage.getUnreadMeetingsNotificationsCount(
        _user.id,
      );
      if (!mounted) return;
      setState(() => _unreadMeetingsNotificationsCount = count);
    } catch (_) {
      if (!mounted) return;
      setState(() => _unreadMeetingsNotificationsCount = 0);
    }
  }

  Future<void> _loadPendingWithdrawalActionsCount() async {
    if (!_user.canActOnWithdrawalRequests) {
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
        userId: _user.id,
        role: _user.role,
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
    if (!_user.canParticipateInReportsSys) {
      if (mounted) setState(() => _pendingReportsSysCount = 0);
      return;
    }
    try {
      final storage = getStorage();
      final c = await storage.countPendingReportsSys(_user.id);
      if (!mounted) return;
      setState(() => _pendingReportsSysCount = c);
    } catch (_) {
      if (!mounted) return;
      setState(() => _pendingReportsSysCount = 0);
    }
  }

  Future<void> _loadPendingShopDrawingCount() async {
    if (!_user.canAccessShopDrawingHomeIcon) {
      if (mounted) setState(() => _pendingShopDrawingCount = 0);
      return;
    }
    try {
      final storage = getStorage();
      if (storage is! ApiStorageService) {
        if (mounted) setState(() => _pendingShopDrawingCount = 0);
        return;
      }
      final c = await storage.getShopDrawingPendingCount(_user.id);
      if (!mounted) return;
      setState(() => _pendingShopDrawingCount = c);
    } catch (_) {
      if (!mounted) return;
      setState(() => _pendingShopDrawingCount = 0);
    }
  }

  Future<void> _loadPendingInvoicesOwnerCount() async {
    if (!_user.canAccessInvoicesOwner) {
      if (mounted) setState(() => _pendingInvoicesOwnerCount = 0);
      return;
    }
    try {
      final storage = getStorage();
      if (storage is! ApiStorageService) {
        if (mounted) setState(() => _pendingInvoicesOwnerCount = 0);
        return;
      }
      final c =
          await storage.getInvoicesOwnerPendingCount(_user.id);
      if (!mounted) return;
      setState(() => _pendingInvoicesOwnerCount = c);
    } catch (_) {
      if (!mounted) return;
      setState(() => _pendingInvoicesOwnerCount = 0);
    }
  }

  Future<void> _loadAppReleaseUpdateBadge() async {
    if (!_user.canViewAppVersionsIcon) {
      if (mounted) setState(() => _hasAppReleaseUpdate = false);
      return;
    }
    final storage = getStorage();
    if (storage is! ApiStorageService) {
      if (mounted) setState(() => _hasAppReleaseUpdate = false);
      return;
    }
    try {
      final hasUpdate = await storage.hasAppReleaseUpdate(_user.id);
      if (!mounted) return;
      setState(() => _hasAppReleaseUpdate = hasUpdate);
    } catch (_) {
      if (!mounted) return;
      setState(() => _hasAppReleaseUpdate = false);
    }
  }

  void _startNotificationsPollingIfManager() {
    if (!_canUseNotifications &&
        !_canUseShopDarwingNotification &&
        !_canUseMeetingsNotification &&
        !_user.canAccessShopDrawingHomeIcon &&
        getStorage() is! ApiStorageService) {
      return;
    }
    _notificationsPollTimer?.cancel();
    _notificationsPollTimer = Timer.periodic(
      AppPollingIntervals.homeBadges,
      (_) {
        if (_canUseNotifications) _loadUnreadNotificationsCount();
        if (_canUseShopDarwingNotification) {
          _loadUnreadShopDarwingNotificationsCount();
        }
        if (_canUseMeetingsNotification) {
          _loadUnreadMeetingsNotificationsCount();
        }
        _loadPendingWithdrawalActionsCount();
        _loadPendingReportsSysCount();
        _loadPendingShopDrawingCount();
        _loadPendingInvoicesOwnerCount();
        _loadAppReleaseUpdateBadge();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _user;
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
          if (widget.currentUser.canUseViewAsRole)
            PopupMenuButton<String>(
              tooltip: 'View as',
              onSelected: _onViewAsChanged,
              itemBuilder: (context) {
                final options = buildViewAsRoleOptions(arabicRoleLabel);
                final selected = ViewAsRoleSession.viewAsRole ??
                    ViewAsRoleSession.primaryOptionValue;
                return [
                  for (final o in options)
                    CheckedPopupMenuItem<String>(
                      value: o.value,
                      checked: o.value == selected ||
                          (o.value == ViewAsRoleSession.primaryOptionValue &&
                              ViewAsRoleSession.viewAsRole == null),
                      child: Text(o.label),
                    ),
                ];
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'View as',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      currentUser.isViewingAsOtherRole
                          ? (arabicRoleLabel(currentUser.role).isNotEmpty
                              ? arabicRoleLabel(currentUser.role)
                              : currentUser.role)
                          : ViewAsRoleSession.primaryLabel,
                      style: const TextStyle(fontSize: 11),
                    ),
                    const Icon(Icons.arrow_drop_down, size: 20),
                  ],
                ),
              ),
            ),
          if (currentUser.canActOnWithdrawalRequests)
            _pendingWithdrawalRequestsCount > 0
                ? RotationTransition(
                    turns: _wrRotateController,
                    child: IconButton(
                      tooltip: currentUser.hasSiteEngineerManagerPrivileges
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
                    tooltip: currentUser.hasSiteEngineerManagerPrivileges
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
          if (_canUseMeetingsNotification)
            IconButton(
              tooltip: 'إشعارات الاجتماعات',
              onPressed: () async {
                final storage = getStorage();
                if (storage is ApiStorageService) {
                  try {
                    await storage.markAllMeetingsNotificationsRead(
                      currentUser.id,
                    );
                  } catch (_) {}
                }
                await _loadUnreadMeetingsNotificationsCount();
                if (!context.mounted) return;
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MeetingsNotificationsScreen(
                      currentUser: currentUser,
                    ),
                  ),
                );
                await _loadUnreadMeetingsNotificationsCount();
              },
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const MeetingsNotificationAppBarIcon(),
                  if (_unreadMeetingsNotificationsCount > 0)
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
                          _unreadMeetingsNotificationsCount > 99
                              ? '99+'
                              : '$_unreadMeetingsNotificationsCount',
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
          if (getStorage() is ApiStorageService &&
              currentUser.canViewAppVersionsIcon)
            IconButton(
              tooltip: 'Versions',
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AppVersionsScreen(currentUser: currentUser),
                  ),
                );
                await _loadAppReleaseUpdateBadge();
              },
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.system_update_alt),
                  if (_hasAppReleaseUpdate)
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
                        child: const Text(
                          '1',
                          textAlign: TextAlign.center,
                          style: TextStyle(
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
              ViewAsRoleSession.clear();
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
        pendingInvoicesOwnerCount: _pendingInvoicesOwnerCount,
        unreadMeetingsCount: _unreadMeetingsNotificationsCount,
        onReportsSysReturn: _loadPendingReportsSysCount,
        onShopDrawingReturn: _loadPendingShopDrawingCount,
        onInvoicesOwnerReturn: _loadPendingInvoicesOwnerCount,
        onMeetingsReturn: _loadUnreadMeetingsNotificationsCount,
      ),
    );
  }
}
