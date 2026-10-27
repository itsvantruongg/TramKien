import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Tram_Kien/models/models.dart';
import 'package:Tram_Kien/providers/app_provider.dart';
import 'package:Tram_Kien/screens/feedback_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createTestWidget({
    AppProvider? appProvider,
    http.Client? httpClient,
  }) {
    final provider = appProvider ?? AppProvider();
    return ChangeNotifierProvider<AppProvider>.value(
      value: provider,
      child: MaterialApp(
        home: FeedbackScreen(httpClient: httpClient),
      ),
    );
  }

  group('SPEC-FEEDBACK-GOOGLE-FORM-01 Acceptance Criteria Verification Tests', () {
    // =========================================================================
    // AC-01: UI Cleanup
    // =========================================================================
    group('AC-01 (UI Cleanup)', () {
      testWidgets('Displays exactly 3 input fields and completely removes Phone field', (tester) async {
        final appProvider = AppProvider();
        appProvider.student = null;

        await tester.pumpWidget(createTestWidget(appProvider: appProvider));
        await tester.pumpAndSettle();

        // Verify title & headings
        expect(find.text('Góp ý ứng dụng'), findsOneWidget);
        expect(find.text('GỬI PHẢN HỒI CHO CHÚNG TÔI'), findsOneWidget);

        // Verify only 3 field labels are present
        expect(find.text('Họ và tên'), findsOneWidget);
        expect(find.text('Email'), findsOneWidget);
        expect(find.text('Nội dung'), findsOneWidget);

        // Verify phone number field and placeholder are completely removed
        expect(find.text('Số điện thoại'), findsNothing);
        expect(find.text('0912 345 678'), findsNothing);

        // Verify exact count of TextFormField is 3
        expect(find.byType(TextFormField), findsNWidgets(3));
      });
    });

    // =========================================================================
    // AC-02: Auto-Prefill UX
    // =========================================================================
    group('AC-02 (Auto-Prefill UX)', () {
      testWidgets('Pre-fills Name and Email when AppProvider.student is available', (tester) async {
        final appProvider = AppProvider();
        appProvider.student = const Student(
          mssv: '2151061234',
          hoTen: 'Trần Văn Trường',
          email: 'truongtv@hau.edu.vn',
        );

        await tester.pumpWidget(createTestWidget(appProvider: appProvider));
        await tester.pumpAndSettle();

        final textFields = find.byType(TextFormField);
        final nameField = tester.widget<TextFormField>(textFields.at(0));
        final emailField = tester.widget<TextFormField>(textFields.at(1));
        final contentField = tester.widget<TextFormField>(textFields.at(2));

        expect(nameField.controller?.text, equals('Trần Văn Trường'));
        expect(emailField.controller?.text, equals('truongtv@hau.edu.vn'));
        expect(contentField.controller?.text, isEmpty);
      });

      testWidgets('Leaves fields empty when AppProvider.student is null', (tester) async {
        final appProvider = AppProvider();
        appProvider.student = null;

        await tester.pumpWidget(createTestWidget(appProvider: appProvider));
        await tester.pumpAndSettle();

        final textFields = find.byType(TextFormField);
        final nameField = tester.widget<TextFormField>(textFields.at(0));
        final emailField = tester.widget<TextFormField>(textFields.at(1));
        final contentField = tester.widget<TextFormField>(textFields.at(2));

        expect(nameField.controller?.text, isEmpty);
        expect(emailField.controller?.text, isEmpty);
        expect(contentField.controller?.text, isEmpty);
      });
    });

    // =========================================================================
    // AC-03: Field Validation
    // =========================================================================
    group('AC-03 (Field Validation)', () {
      testWidgets('Shows error messages when required fields are empty', (tester) async {
        final appProvider = AppProvider();
        appProvider.student = null;

        await tester.pumpWidget(createTestWidget(appProvider: appProvider));
        await tester.pumpAndSettle();

        // Tap submit button with all fields empty
        await tester.tap(find.text('Gửi góp ý'));
        await tester.pumpAndSettle();

        expect(find.text('Vui lòng nhập họ tên'), findsOneWidget);
        expect(find.text('Vui lòng nhập email'), findsOneWidget);
        expect(find.text('Vui lòng nhập nội dung'), findsOneWidget);
      });

      testWidgets('Validates email format using standard regex', (tester) async {
        final appProvider = AppProvider();
        appProvider.student = null;

        await tester.pumpWidget(createTestWidget(appProvider: appProvider));
        await tester.pumpAndSettle();

        final textFields = find.byType(TextFormField);
        await tester.enterText(textFields.at(0), 'Nguyễn Văn A');
        await tester.enterText(textFields.at(1), 'invalid-email-address');
        await tester.enterText(textFields.at(2), 'Ý kiến phản hồi');

        await tester.tap(find.text('Gửi góp ý'));
        await tester.pumpAndSettle();

        expect(find.text('Email không hợp lệ'), findsOneWidget);
        expect(find.text('Vui lòng nhập họ tên'), findsNothing);
        expect(find.text('Vui lòng nhập nội dung'), findsNothing);

        // Correct email
        await tester.enterText(textFields.at(1), 'valid.user@hau.edu.vn');
        await tester.tap(find.text('Gửi góp ý'));
        await tester.pumpAndSettle();

        expect(find.text('Email không hợp lệ'), findsNothing);
      });

      testWidgets('Enforces maxLength of 500 characters on content field', (tester) async {
        final appProvider = AppProvider();
        appProvider.student = null;

        await tester.pumpWidget(createTestWidget(appProvider: appProvider));
        await tester.pumpAndSettle();

        final textFields = find.byType(TextField);
        final contentField = tester.widget<TextField>(textFields.at(2));
        expect(contentField.maxLength, equals(500));
      });
    });

    // =========================================================================
    // AC-04: Headless Submission to Google Form Endpoint
    // =========================================================================
    group('AC-04 (Headless Submission)', () {
      testWidgets('Submits URL-encoded form data to Google Form on HTTP 200 OK', (tester) async {
        http.Request? capturedRequest;

        final mockClient = MockClient((request) async {
          capturedRequest = request;
          return http.Response('<!DOCTYPE html><html>Form Submitted</html>', 200);
        });

        final appProvider = AppProvider();
        appProvider.student = const Student(
          mssv: '2151061234',
          hoTen: 'Lê Văn An',
          email: 'anlv@hau.edu.vn',
        );

        await tester.pumpWidget(createTestWidget(
          appProvider: appProvider,
          httpClient: mockClient,
        ));
        await tester.pumpAndSettle();

        final textFields = find.byType(TextFormField);
        await tester.enterText(textFields.at(2), 'Ứng dụng chạy rất ổn định!');

        await tester.tap(find.text('Gửi góp ý'));
        await tester.pumpAndSettle();

        // 1. Verify endpoint contract
        expect(capturedRequest, isNotNull);
        expect(
          capturedRequest!.url.toString(),
          equals(FeedbackScreen.googleFormEndpoint),
        );
        expect(
          capturedRequest!.url.toString(),
          equals('https://docs.google.com/forms/d/e/1FAIpQLSfe_FG1oCxfXZkRt0R766Rj9aWSX2z-w96-lMZsrxA6kAQlew/formResponse'),
        );
        expect(capturedRequest!.method, equals('POST'));

        // 2. Verify headers
        expect(
          capturedRequest!.headers['content-type'],
          contains('application/x-www-form-urlencoded'),
        );

        // 3. Verify body mapping
        expect(capturedRequest!.bodyFields[FeedbackScreen.entryName], equals('Lê Văn An'));
        expect(capturedRequest!.bodyFields[FeedbackScreen.entryEmail], equals('anlv@hau.edu.vn'));
        expect(capturedRequest!.bodyFields[FeedbackScreen.entryContent], equals('Ứng dụng chạy rất ổn định!'));
        expect(capturedRequest!.bodyFields['entry.1036072439'], equals('Lê Văn An'));
        expect(capturedRequest!.bodyFields['entry.336370746'], equals('anlv@hau.edu.vn'));
        expect(capturedRequest!.bodyFields['entry.2114228'], equals('Ứng dụng chạy rất ổn định!'));

        // 4. Verify UX on success: success SnackBar is displayed
        expect(find.text('✅ Gửi góp ý thành công! Cảm ơn bạn.'), findsOneWidget);

        // 5. Verify UX on success: content is cleared, while Name and Email remain preserved
        final nameField = tester.widget<TextFormField>(textFields.at(0));
        final emailField = tester.widget<TextFormField>(textFields.at(1));
        final contentField = tester.widget<TextFormField>(textFields.at(2));

        expect(nameField.controller?.text, equals('Lê Văn An'));
        expect(emailField.controller?.text, equals('anlv@hau.edu.vn'));
        expect(contentField.controller?.text, isEmpty);
      });

      testWidgets('Treats redirect status 302 as success (< 400)', (tester) async {
        final mockClient = MockClient((request) async {
          return http.Response('', 302, headers: {'location': 'https://docs.google.com/forms/d/e/.../viewform'});
        });

        final appProvider = AppProvider();
        appProvider.student = null;

        await tester.pumpWidget(createTestWidget(
          appProvider: appProvider,
          httpClient: mockClient,
        ));
        await tester.pumpAndSettle();

        final textFields = find.byType(TextFormField);
        await tester.enterText(textFields.at(0), 'Phạm Bình');
        await tester.enterText(textFields.at(1), 'binhp@hau.edu.vn');
        await tester.enterText(textFields.at(2), 'Ý kiến 302 redirect');

        await tester.tap(find.text('Gửi góp ý'));
        await tester.pumpAndSettle();

        expect(find.text('✅ Gửi góp ý thành công! Cảm ơn bạn.'), findsOneWidget);
        final contentField = tester.widget<TextFormField>(textFields.at(2));
        expect(contentField.controller?.text, isEmpty);
      });

      testWidgets('Shows error dialog when HTTP status >= 400', (tester) async {
        final mockClient = MockClient((request) async {
          return http.Response('Forbidden', 403);
        });

        final appProvider = AppProvider();
        appProvider.student = null;

        await tester.pumpWidget(createTestWidget(
          appProvider: appProvider,
          httpClient: mockClient,
        ));
        await tester.pumpAndSettle();

        final textFields = find.byType(TextFormField);
        await tester.enterText(textFields.at(0), 'Đặng C');
        await tester.enterText(textFields.at(1), 'cdang@hau.edu.vn');
        await tester.enterText(textFields.at(2), 'Góp ý thử nghiệm');

        await tester.tap(find.text('Gửi góp ý'));
        await tester.pumpAndSettle();

        // Verify error dialog appears
        expect(find.text('Gửi thất bại'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.textContaining('HTTP 403'),
          ),
          findsOneWidget,
        );
        expect(find.text('Mở Gmail'), findsOneWidget);
        expect(find.text('Đóng'), findsOneWidget);

        // Close dialog
        await tester.tap(find.text('Đóng'));
        await tester.pumpAndSettle();
        expect(find.text('Gửi thất bại'), findsNothing);
      });

      testWidgets('Shows error dialog when network exception occurs', (tester) async {
        final mockClient = MockClient((request) async {
          throw http.ClientException('Mạng không khả dụng');
        });

        final appProvider = AppProvider();
        appProvider.student = null;

        await tester.pumpWidget(createTestWidget(
          appProvider: appProvider,
          httpClient: mockClient,
        ));
        await tester.pumpAndSettle();

        final textFields = find.byType(TextFormField);
        await tester.enterText(textFields.at(0), 'Nguyễn D');
        await tester.enterText(textFields.at(1), 'dnguyen@hau.edu.vn');
        await tester.enterText(textFields.at(2), 'Mất kết nối');

        await tester.tap(find.text('Gửi góp ý'));
        await tester.pumpAndSettle();

        expect(find.text('Gửi thất bại'), findsOneWidget);
        expect(find.textContaining('Mạng không khả dụng'), findsOneWidget);
      });
    });

    // =========================================================================
    // AC-05: Fallback Email Cleaned Up (No Phone Field)
    // =========================================================================
    group('AC-05 (Fallback Update)', () {
      test('buildEmailFallbackUri excludes phone number from mailto body', () {
        final uri = FeedbackScreen.buildEmailFallbackUri(
          name: 'Nguyễn Văn Test',
          email: 'test@hau.edu.vn',
          content: 'Nội dung phản hồi góp ý tính năng.',
        );

        expect(uri.scheme, equals('mailto'));
        expect(uri.path, equals('loginchily1@gmail.com'));

        final queryParams = uri.queryParameters;
        expect(
          queryParams['subject'],
          equals('Góp ý ứng dụng Schedify HAU - Nguyễn Văn Test'),
        );

        final body = queryParams['body']!;
        expect(body, contains('Họ và tên: Nguyễn Văn Test'));
        expect(body, contains('Email: test@hau.edu.vn'));
        expect(body, contains('Nội dung:\nNội dung phản hồi góp ý tính năng.'));

        // Ensure Phone / SĐT is completely absent from the email body
        expect(body.toLowerCase(), isNot(contains('số điện thoại')));
        expect(body.toLowerCase(), isNot(contains('sđt')));
        expect(body.toLowerCase(), isNot(contains('phone')));
      });
    });
  });
}
