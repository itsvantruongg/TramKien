import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'firebase_options.dart';

import 'providers/app_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'screens/notifications_screen.dart';
import 'services/analytics_service.dart';
import 'services/local_notification_service.dart';
import 'theme/app_theme.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // Bỏ qua nếu chạy background (nếu cần thiết có thể log)
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // --- THÊM ĐOẠN KHỞI TẠO FIREBASE VÀO ĐÂY ---
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  await initializeDateFormatting('vi_VN', null);
  await AnalyticsService.initialize();
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
      create: (_) => AppProvider()..init(),
      child: const SchedifyApp(),
    ),
  );
}

class SchedifyApp extends StatelessWidget {
  const SchedifyApp({super.key});
  // --- KHAI BÁO BIẾN ANALYTICS ---
  static FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  @override
  Widget build(BuildContext context) => MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Trạm Kiến',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        // --- THÊM OBSERVER ĐỂ THEO DÕI CHUYỂN TRANG ---
        navigatorObservers: [
          FirebaseAnalyticsObserver(analytics: analytics),
        ],
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

          // Clamp text scale: ngăn user tăng cỡ chữ hệ thống làm vỡ layout
          // Max 1.15 để vẫn hỗ trợ accessibility nhẹ nhưng không vỡ UI
          final clampedTextScaler = mediaQuery.textScaler.clamp(
            minScaleFactor: 1.0,
            maxScaleFactor: 1.15,
          );

          final adjustedMediaQuery = mediaQuery.copyWith(
            size: Size(contentWidth, size.height),
            textScaler: clampedTextScaler,
          );

          return ColoredBox(
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
          );
        },
        home: const AppRouter(),
      );
}

class AppRouter extends StatelessWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    return switch (p.authState) {
      AuthState.unknown => const _SplashScreen(),
      AuthState.loggedOut => const LoginScreen(),
      AuthState.loggedIn => const MainShell(),
    };
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppTheme.surface,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.school, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 20),
              Text(
                'Trạm Kiến',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 32),
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ),
      );
}
