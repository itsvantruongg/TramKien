# Technical Specification: Tích Hợp Firebase An Toàn Cho Dự Án Mã Nguồn Mở & Nâng Cấp Phiên Bản 1.1.0+5

- **Mã tài liệu:** SPEC-FIREBASE-OPENSOURCE-01
- **Phân hệ:** App Telemetry, Crash Reporting, Build Configuration & Version Management
- **Tác giả:** Senior Business Analyst & Software Architect
- **Trạng thái:** Approved / Ready for Implementation

---

## 1. YÊU CẦU & BẢNG PHÂN TÍCH HIỆN TRẠNG (REQUIREMENTS & GAP AUDIT)

| Hạng mục / Tiêu chí | Hiện trạng (Current State) | Rủi ro & Hạn chế (Risks) | Giải pháp chuẩn kiến trúc (Target Standard) |
| :--- | :--- | :--- | :--- |
| **1. Phiên bản dự án (App Versioning)**<br>`pubspec.yaml:4`<br>`DatabaseService:15` | Đang ở `1.0.6+4`. | Vừa hoàn thành tính năng lớn "Xưởng Widget Studio" và các bản vá đồng bộ dữ liệu. Nếu không nâng Minor version sẽ không đúng chuẩn SemVer và kho ứng dụng từ chối phát hành. | Đồng bộ nâng lên **`1.1.0+5`** tại cả `pubspec.yaml` và `DatabaseService.currentAppVersion`. Giữ nguyên SQLite `_version = 17` vì không thay đổi schema CSDL. |
| **2. Bảo vệ bí mật trên Public Git (Open-Source Security)** | `google-services.json` và `GoogleService-Info.plist` đang nằm trong thư mục nguồn và có nguy cơ bị push lên GitHub public. | **Lộ Project ID & nguy cơ spam quota:** Bất kỳ ai clone repo đều có thể kết nối vào Firebase của chủ dự án hoặc gây quá tải hạn mức. | Áp dụng **Cách A (Security Isolation)**: Thêm các file cấu hình thật vào `.gitignore`, tạo file mẫu `lib/firebase_options.dart.example` làm tài liệu hướng dẫn cho cộng đồng. |
| **3. Khởi tạo an toàn (Safe Initialization)** | Chưa khởi tạo Firebase trong `main.dart`. | Nếu tệp cấu hình bị thiếu hoặc môi trường kiểm thử (Unit test) không có Native Firebase, app sẽ bị văng (Crash on Cold Start). | Đóng gói `AnalyticsService.init()` với khối try-catch an toàn: nếu Firebase khả dụng thì chạy, nếu thiếu cấu hình hoặc trong môi trường test thì ghi nhận log cảnh báo và app vẫn chạy offline bình thường. |
| **4. Chính sách bảo mật thông tin sinh viên (Zero PII Policy)** | Chưa có bộ lọc sự kiện. | Nếu vô tình đẩy MSSV, Họ tên, Điểm số hay Mật khẩu vào Analytics/Crashlytics sẽ vi phạm nghiêm trọng quyền riêng tư người dùng. | **Nghiêm cấm gửi PII:** Chỉ ghi nhận các sự kiện vô danh (`app_open`, `view_schedule`, `sync_completed`, `open_widget_studio`, `submit_feedback`). |

---

## 2. ĐẶC TẢ CHI TIẾT KỸ THUẬT & CẤU HÌNH (SPECIFICATIONS)

### 2.1. Cập nhật Phiên bản Dự án
- `pubspec.yaml`:
  ```yaml
  version: 1.1.0+5
  ```
- `lib/services/database_service.dart`:
  ```dart
  static const String currentAppVersion = '1.1.0+5';
  ```

### 2.2. Khai báo Thư viện trong `pubspec.yaml`
Bổ sung các dependencies chính thức từ Firebase (tương thích Flutter 3.x):
```yaml
dependencies:
  # ... các dependencies hiện tại giữ nguyên ...
  firebase_core: ^3.6.0
  firebase_analytics: ^11.3.3
  firebase_crashlytics: ^4.1.3
```

### 2.3. Cấu hình Gradle Android (`settings.gradle.kts` & `app/build.gradle.kts`)
- Trong `android/settings.gradle.kts`:
  ```kts
  plugins {
      id("dev.flutter.flutter-plugin-loader") version "1.0.0"
      id("com.android.application") version "8.11.1" apply false
      id("com.google.gms.google-services") version "4.4.2" apply false
      id("com.google.firebase.crashlytics") version "3.0.2" apply false
      id("org.jetbrains.kotlin.android") version "2.2.20" apply false
  }
  ```
- Trong `android/app/build.gradle.kts`:
  ```kts
  plugins {
      id("com.android.application")
      id("kotlin-android")
      id("dev.flutter.flutter-gradle-plugin")
      id("com.google.gms.google-services")
      id("com.google.firebase.crashlytics")
  }
  ```

### 2.4. Cấu hình Cô lập Bảo mật trong `.gitignore`
Bổ sung các tệp nhạy cảm vào `.gitignore`:
```gitignore
# Firebase sensitive credentials - DO NOT COMMIT
android/app/google-services.json
ios/Runner/GoogleService-Info.plist
lib/firebase_options.dart
```

### 2.5. Tệp Mẫu cho Cộng đồng (`lib/firebase_options.dart.example`)
Tạo tệp mẫu chứa cấu trúc placeholder để người dùng bên ngoài biết cách cấu hình:
```dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('DefaultFirebaseOptions are not supported for this platform.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR-ANDROID-API-KEY',
    appId: '1:000000000000:android:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'your-project-id',
    storageBucket: 'your-project-id.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR-IOS-API-KEY',
    appId: '1:000000000000:ios:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'your-project-id',
    storageBucket: 'your-project-id.firebasestorage.app',
    iosBundleId: 'com.tramkien.hau',
  );
}
```

### 2.6. Triển khai Dịch vụ Đo lường & Bắt lỗi An toàn (`lib/services/analytics_service.dart`)
- **Khởi tạo không chặn (Non-blocking Safe Init):**
  - Thực hiện trong `AnalyticsService.initialize()`.
  - Tự động bắt lỗi Flutter framework với `FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;`.
  - Bắt lỗi bất đồng bộ nền tảng với `PlatformDispatcher.instance.onError = (error, stack) { FirebaseCrashlytics.instance.recordError(error, stack, fatal: true); return true; };`.
  - Nếu gặp môi trường không có cấu hình (Unit test / CI), ghi log cảnh báo và tiếp tục, không bao giờ để crash app.
- **Sự kiện chuẩn hóa (Whitelisted Anonymous Events):**
  - `logScreenView(String screenName)`
  - `logScheduleSync(bool success, int itemCount)`
  - `logWidgetCustomized(String layoutMode, String bgStyle)`
  - `logFeedbackSubmitted()`

---

## 3. TIÊU CHUẨN NGHIỆM THU (ACCEPTANCE CRITERIA - AC CHECKLIST)

- [ ] **AC-01 (Version Bump):** `pubspec.yaml` hiển thị `version: 1.1.0+5` và `DatabaseService.currentAppVersion` trả về `'1.1.0+5'`. Test case tính toàn vẹn phiên bản `test/sync_test.dart` chạy thành công.
- [ ] **AC-02 (Security Isolation in .gitignore):** `.gitignore` đã chứa `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist` và `lib/firebase_options.dart`.
- [ ] **AC-03 (Example Template):** Tệp `lib/firebase_options.dart.example` được tạo với định dạng hợp lệ, không chứa thông tin mật khẩu hay token nhạy cảm.
- [ ] **AC-04 (Safe Initialization):** `AnalyticsService.initialize()` khởi động an toàn, không ném ngoại lệ không xử lý khi chạy trong môi trường test hay máy thiếu file cấu hình.
- [ ] **AC-05 (Zero PII Compliance):** Không có bất kỳ dòng code nào ghi nhận MSSV, mật khẩu, tên sinh viên hoặc thông tin cá nhân vào Analytics hay Crashlytics.
- [ ] **AC-06 (Automated Tests & Quality Gates):** `flutter test` chạy thành công $100\%$ (toàn bộ các bài test cũ và bài test mới đều pass).
