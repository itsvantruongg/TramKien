import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Tram_Kien/services/database_service.dart';
import 'package:Tram_Kien/services/app_info_service.dart';
import 'package:Tram_Kien/providers/app_provider.dart';
import 'package:Tram_Kien/screens/profile_screen.dart';
import 'package:Tram_Kien/screens/terms_screen.dart';
import 'package:Tram_Kien/screens/login_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppInfoService.reset();
  });

  tearDown(() {
    AppInfoService.reset();
  });

  group('App Version Single Source of Truth Tests', () {
    test('Fallback to DatabaseService.currentAppVersion when PackageInfo fails or is unmocked', () async {
      // By default in pure unit test without mock initial values,
      // AppInfoService falls back gracefully to DatabaseService.currentAppVersion
      final version = AppInfoService.currentAppVersion;
      expect(version, equals(DatabaseService.currentAppVersion));
      expect(version, equals('1.1.0+5'));
    });

    test('PackageInfo.setMockInitialValues correctly updates AppInfoService', () async {
      PackageInfo.setMockInitialValues(
        appName: 'Tram Kien',
        packageName: 'com.tramkien.hau',
        version: '1.2.3',
        buildNumber: '99',
        buildSignature: '',
      );

      final version = await AppInfoService.getAppVersion();
      expect(version, equals('1.2.3+99'));
      expect(AppInfoService.version, equals('1.2.3'));
      expect(AppInfoService.buildNumber, equals('99'));
      expect(AppInfoService.currentAppVersion, equals('1.2.3+99'));
    });

    test('AppInfoService.setMockVersion manually overrides version', () {
      AppInfoService.setMockVersion(version: '2.0.0', buildNumber: '12');
      expect(AppInfoService.currentAppVersion, equals('2.0.0+12'));
      expect(AppInfoService.version, equals('2.0.0'));
      expect(AppInfoService.buildNumber, equals('12'));
    });

    test('DatabaseService.getAppVersion delegates to AppInfoService', () async {
      AppInfoService.setMockVersion(version: '3.1.4', buildNumber: '159');
      final ver = await DatabaseService.getAppVersion();
      expect(ver, equals('3.1.4+159'));
    });

    testWidgets('ProfileScreen renders dynamic VERSION from AppProvider', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      AppInfoService.setMockVersion(version: '1.2.3', buildNumber: '45');
      final provider = AppProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppProvider>.value(
          value: provider,
          child: const MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('VERSION 1.2.3+45'), findsOneWidget);
      expect(find.text('VERSION 1.0.6'), findsNothing);
    });

    testWidgets('TermsScreen renders dynamic version from AppInfoService', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      AppInfoService.setMockVersion(version: '1.1.0', buildNumber: '5');

      await tester.pumpWidget(
        const MaterialApp(
          home: TermsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Phiên bản 1.1.0+5'), findsOneWidget);
      expect(find.textContaining('Phiên bản 1.0.6'), findsNothing);
    });

    testWidgets('LoginScreen renders dynamic app version from AppInfoService', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      AppInfoService.setMockVersion(version: '1.1.0', buildNumber: '5');

      final provider = AppProvider();
      await tester.pumpWidget(
        ChangeNotifierProvider<AppProvider>.value(
          value: provider,
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Trạm Kiến - HAU v1.1.0+5'), findsOneWidget);
      expect(find.textContaining('v1.0.6'), findsNothing);
    });
  });
}
