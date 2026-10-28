import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'providers/app_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'screens/notifications_screen.dart';
import 'services/analytics_service.dart';
import 'services/app_info_service.dart';
import 'services/background_sync_service.dart';
import 'services/local_notification_service.dart';
import 'services/widget_data_sync_service.dart';
import 'screens/widget_studio_screen.dart';
import 'widgets/shared_widgets.dart';
import 'theme/app_theme.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // Bỏ qua nếu chạy background (nếu cần thiết có thể log)
}

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Safe Analytics & Crashlytics initialization
  await AnalyticsService.initialize();
  await AppInfoService.getAppVersion();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: AppTheme.surface,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  await initializeDateFormatting('vi_VN', null);

  await LocalNotificationService.init(
    onDidReceiveNotificationResponse: (response) {
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.push(
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        );
      }
    },
    onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: const SchedifyApp(),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    unawaited(AnalyticsService.logAppOpen());
    unawaited(BackgroundSyncService.initialize());

    // Deep link from Android Widget (AC-06)
    try {
      final initialRoute = await WidgetDataSyncService.getInitialRoute();
      if (initialRoute == '/widget_studio' &&
          navigatorKey.currentState != null) {
        navigatorKey.currentState!.push(
          MaterialPageRoute(builder: (_) => const WidgetStudioScreen()),
        );
      }
    } catch (_) {}
  });
}

class SchedifyApp extends StatelessWidget {
  const SchedifyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Trạm Kiến',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        navigatorObservers: const [],
        builder: (context, child) {
          final mediaQuery = MediaQuery.of(context);
          final size = mediaQuery.size;

          // Tính toán scale factor toàn cục dựa trên breakpoint kích thước màn hình
          final double scaleFactor;
          if (size.width <= 0) {
            scaleFactor = 1.0;
          } else if (size.width < 360) {
            scaleFactor = 0.85;
          } else if (size.width < 480) {
            scaleFactor = 1.0;
          } else if (size.width < 600) {
            scaleFactor = 1.08;
          } else {
            scaleFactor = 1.15;
          }

          // Cập nhật textScaler dựa trên scaleFactor
          final clampedTextScaler = mediaQuery.textScaler.clamp(
            minScaleFactor: scaleFactor,
            maxScaleFactor: scaleFactor * 1.15,
          );

          final adjustedMediaQuery = mediaQuery.copyWith(
            textScaler: clampedTextScaler,
          );

          return Theme(
            data: AppTheme.lightWithScale(scaleFactor),
            child: ColoredBox(
              color: AppTheme.surface,
              child: MediaQuery(
                data: adjustedMediaQuery,
                child: AppShimmerScope(
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            ),
          );
        },
        home: const AppRouter(),
      );
}

class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  bool _quickAuthDone = false;

  @override
  void initState() {
    super.initState();
    _initAuth();
  }

  Future<void> _initAuth() async {
    final p = context.read<AppProvider>();
    await p.authReady;
    if (mounted) {
      setState(() => _quickAuthDone = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FlutterNativeSplash.remove();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();

    final Widget child;
    if (!_quickAuthDone || p.authState == AuthState.unknown) {
      child = Scaffold(
        key: const ValueKey('splash_holder'),
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/splash_logo_android12.png',
                width: 110,
                height: 110,
                errorBuilder: (_, __, ___) => Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.school, color: Colors.white, size: 40),
                ),
              ),
              const SizedBox(height: 28),
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ),
      );
    } else if (p.authState == AuthState.loggedOut) {
      child = const LoginScreen(key: ValueKey('login'));
    } else {
      child = const MainShell(key: ValueKey('main'));
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: child,
      ),
      child: child,
    );
  }
}
