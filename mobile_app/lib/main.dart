import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/api_service.dart';
import 'generated/app_localizations.dart';
import 'generated/app_localizations_ar.dart';
import 'generated/app_localizations_en.dart';
import 'providers/auth_provider.dart';
import 'providers/locale_provider.dart';
import 'services/token_storage.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/admin/admin_home_screen.dart';
import 'screens/user/user_home_screen.dart';
import 'screens/warehouse/warehouse_home_screen.dart';
import 'navigation/app_route_observer.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: const _LocalizedMaterialApp(),
    );
  }
}

/// Binds [MaterialApp.locale] to [LocaleProvider] so [LanguageSelector] / `setLocale` work again.
/// Keeps a simple shell [ThemeData] (no MaterialApp.builder) to reduce gray-screen risk on Android.
class _LocalizedMaterialApp extends StatefulWidget {
  const _LocalizedMaterialApp();

  @override
  State<_LocalizedMaterialApp> createState() => _LocalizedMaterialAppState();
}

class _LocalizedMaterialAppState extends State<_LocalizedMaterialApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    ApiService.onUnauthorized = _onSessionExpired;
  }

  @override
  void dispose() {
    ApiService.onUnauthorized = null;
    super.dispose();
  }

  Future<void> _onSessionExpired() async {
    final ctx = _navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    final auth = Provider.of<AuthProvider>(ctx, listen: false);
    await auth.logout();
    if (!ctx.mounted) return;
    Navigator.of(ctx).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>().locale;
    final isAr = locale.languageCode == 'ar';
    final title = isAr ? AppLocalizationsAr().appTitle : AppLocalizationsEn().appTitle;

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: title,
      debugShowCheckedModeBanner: false,
      navigatorObservers: [appRouteObserver],
      locale: locale,
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6366F1)),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isAuthenticated = false;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    const minSplashDuration = Duration(seconds: 2);
    const authTimeout = Duration(seconds: 2);

    try {
      final authFuture = Future(() async {
        try {
          final token = await TokenStorage.instance.getToken().timeout(
            const Duration(milliseconds: 1500),
            onTimeout: () => null,
          );
          final prefs = await SharedPreferences.getInstance().timeout(
            const Duration(milliseconds: 1500),
          );
          final role = prefs.getString('userRole');
          return (token != null && token.isNotEmpty, role);
        } catch (_) {
          return (false, null);
        }
      });

      final results = await Future.wait([
        Future.delayed(minSplashDuration),
        authFuture.timeout(authTimeout, onTimeout: () => (false, null)),
      ]);

      var (isAuthenticated, userRole) = results[1] as (bool, String?);

      if (mounted && isAuthenticated) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        try {
          final loaded = await authProvider
              .loadUser()
              .timeout(const Duration(seconds: 15), onTimeout: () => false);
          if (!loaded) {
            isAuthenticated = false;
            userRole = null;
          } else {
            userRole = authProvider.user?.role ?? userRole;
          }
        } catch (_) {
          isAuthenticated = false;
          userRole = null;
        }
      }

      if (mounted) {
        setState(() {
          _isAuthenticated = isAuthenticated;
          _userRole = userRole;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isAuthenticated = false;
          _userRole = null;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SplashScreen();
    }

    if (_isAuthenticated) {
      final role = (_userRole ?? '').toLowerCase().replaceAll(' ', '_');
      if (role == 'admin') {
        return const AdminHomeScreen();
      } else if (role == 'warehouse_user' || role == 'warehouse' || role == 'warehouseuser') {
        return const WarehouseHomeScreen();
      } else {
        return const UserHomeScreen();
      }
    }

    return const LoginScreen();
  }
}
