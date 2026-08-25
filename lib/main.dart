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
import 'services/background_sync_service.dart';
import 'services/local_notification_service.dart';
import 'theme/app_theme.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // Bỏ qua nếu chạy background (nếu cần thiết có thể log)
}

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: AppTheme.surface,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  await initializeDateFormatting('vi_VN', null);

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: const SchedifyApp(),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(LocalNotificationService.init(
      onDidReceiveNotificationResponse: (response) {
        if (navigatorKey.currentState != null) {
          navigatorKey.currentState!.push(
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          );
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    ));
    unawaited(BackgroundSyncService.initialize());
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
          final shortestSide = size.shortestSide;

          final maxContentWidth = shortestSide >= 840
              ? 600.0
              : shortestSide >= 600
                  ? 520.0
                  : size.width;

          final contentWidth =
              size.width < maxContentWidth ? size.width : maxContentWidth;

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
            size: Size(contentWidth, size.height),
            textScaler: clampedTextScaler,
          );

          return Theme(
            data: AppTheme.lightWithScale(scaleFactor),
            child: ColoredBox(
              color: AppTheme.surface,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentWidth),
                  child: MediaQuery(
                    data: adjustedMediaQuery,
                    child: child ?? const SizedBox.shrink(),
                  ),
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
    await p.quickAuthReady;
    if (mounted) {
      setState(() {
        _quickAuthDone = true;
      });
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
      child = const Scaffold(
        key: ValueKey('splash_holder'),
        backgroundColor: Colors.white,
        body: SizedBox.expand(),
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
