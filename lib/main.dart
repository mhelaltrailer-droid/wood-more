import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/app_theme.dart';
import 'firebase_options.dart';
import 'models/user_model.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_storage_service.dart';
import 'services/auth_persistence.dart';
import 'services/route_persistence.dart';
import 'core/route_observer.dart';
import 'services/route_restore.dart';
import 'services/storage_service.dart';

void main() async {
  // تأكد من إضافة هذين السطرين قبل runApp
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await initStorage();

  runApp(const WoodAndMoreApp());
}

class WoodAndMoreApp extends StatelessWidget {
  const WoodAndMoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wood & More',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      navigatorObservers: [RouteObserverProvider.routeObserver],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
      ],
      locale: const Locale('ar'),
      home: const _AuthGate(),
    );
  }
}

/// Shows LoginScreen or HomeScreen depending on stored user. When using API, validates session so that after docker down / backend unavailable we ask for login again.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  Future<UserModel?> _getValidatedUser() async {
    final user = await getStoredUser();
    if (user == null) return null;
    final storage = getStorage();
    if (storage is ApiStorageService) {
      try {
        final current = await storage.getUserByEmail(user.email);
        if (current == null) {
          await clearCurrentUser();
          return null;
        }
        return user;
      } catch (_) {
        await clearCurrentUser();
        return null;
      }
    }
    return user;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserModel?>(
      future: _getValidatedUser(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        final user = snapshot.data;
        if (user != null) {
          return _HomeWithRouteRestore(user: user);
        }
        return const LoginScreen();
      },
    );
  }
}

/// Shows HomeScreen or the restored sub-route directly (no dashboard flash on refresh).
class _HomeWithRouteRestore extends StatefulWidget {
  final UserModel user;

  const _HomeWithRouteRestore({required this.user});

  @override
  State<_HomeWithRouteRestore> createState() => _HomeWithRouteRestoreState();
}

class _HomeWithRouteRestoreState extends State<_HomeWithRouteRestore> {
  String? _routeToShow; // null = loading, 'home' = home, else = sub-route name

  @override
  void initState() {
    super.initState();
    getLastRoute().then((name) {
      if (!mounted) return;
      setState(() {
        _routeToShow = (name != null && name.isNotEmpty && name != 'home') ? name : 'home';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_routeToShow == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_routeToShow == 'home') {
      return HomeScreen(currentUser: widget.user);
    }
    final screen = getScreenForRoute(_routeToShow!, widget.user);
    if (screen == null) {
      return HomeScreen(currentUser: widget.user);
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (!didPop && mounted) {
          await saveLastRoute('home');
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => HomeScreen(currentUser: widget.user)),
          );
        }
      },
      child: screen,
    );
  }
}
