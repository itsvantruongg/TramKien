# ĐẶC TẢ KỸ THUẬT (TECHNICAL SPECIFICATION)
## Phân Hệ: Tối Ưu Hóa Nâng Cấp v1.1.0, Khắc Phục Luồng Thông Báo & Khôi Phục Đồng Bộ Nền
- **Mã tài liệu:** `SPEC-UPGRADE-RESILIENCE-AND-NOTIFICATION-01`
- **Phiên bản:** `1.0.0`
- **Tác giả:** Senior BA / Hermes Master Orchestrator
- **Dự án:** Trạm Kiến - Ứng dụng Quản lý Học tập & Lịch học HAU (Flutter / Android / iOS)
- **Tình trạng:** Trình duyệt (Draft / Pending Approval) - **Tuyệt đối không sửa mã nguồn trước khi được duyệt**

---

## 1. ĐỐI CHIẾU LỊCH SỬ MÃ NGUỒN & NGUYÊN NHÂN GỐC RỄ (GIT ARCHAEOLOGY & ROOT CAUSE)

### 1.1. Về Màn Hình Splash & Vòng Xoay Loading (CircularProgressIndicator):
- **Tại commit `ac3242e` (v1.0.6):** 
  - Trong `lib/main.dart` của v1.0.6, đúng là tồn tại 2 tầng Splash:
    1. *Tầng Native:* Mặc định của Android (`LaunchTheme` hiển thị `launch_background.xml`).
    2. *Tầng Custom Flutter (`_SplashScreen`):* Chứa icon trường học gradient, tên "Trạm Kiến" và vòng xoay xoay `CircularProgressIndicator`.
- **Tại commit `068eeb9` (sau v1.0.6):**
  - Người dùng **ĐÃ GỠ BỎ HOÀN TOÀN** widget `_SplashScreen` custom chứa vòng xoay này, chuyển sang cơ chế `flutter_native_splash` kết hợp `splash_holder` (Scaffold trắng) và dùng `await p.quickAuthReady` để gỡ bỏ Splash cực nhanh trong vài mili-giây.
- **Tại commit `2311dcb` (v1.1.0):**
  - Một thay đổi ngoài ý muốn đã sửa `await p.quickAuthReady;` thành `await p.authReady;` trong `_initAuth()`:
    ```dart
    // lib/main.dart:156 (HEAD v1.1.0)
    Future<void> _initAuth() async {
      final p = context.read<AppProvider>();
      await p.authReady; // ⚠️ GÂY NGHẼN: Chờ toàn bộ load DB + Migration v17
      if (mounted) {
        setState(() => _quickAuthDone = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          FlutterNativeSplash.remove(); // Splash chỉ được gỡ sau khi nạp xong SQLite
        });
      }
    }
    ```
- **Về câu hỏi "Splash mặc định của Android có bị khóa cứng thời gian (hardcoded delay) không?":**
  - **Khẳng định 100%:** Trong `styles.xml`, `values-v31/styles.xml` và `MainActivity.kt` **HOÀN TOÀN KHÔNG CÓ BẤT KỲ TIMER HAY HARDCODED DELAY NÀO**.
  - Lý do splash trên Android bị lưu lại lâu là do `FlutterNativeSplash.preserve()` giữ màn hình Native cho đến khi `FlutterNativeSplash.remove()` được gọi. Do dòng code trên chờ `p.authReady` (quét toàn bộ SQLite), nên thời gian hiển thị Splash bị khóa chặt theo tốc độ I/O đọc ổ cứng của máy.

---

### 1.2. Về Luồng Thông Báo: Tại Sao v1.0.6 Chạy Được Nhưng v1.1.0 Không Thấy Bắn Thông Báo?

| Hạng mục đối chiếu | Bản cũ v1.0.6 (`ac3242e`) | Bản hiện tại v1.1.0 (`HEAD`) | Hậu quả kỹ thuật trên v1.1.0 |
| :--- | :--- | :--- | :--- |
| **1. Khởi tạo `LocalNotificationService.init`** | Được `await` trực tiếp trong `main()` **TRƯỚC** `runApp()`. | Bị đưa vào `unawaited(...)` trong `addPostFrameCallback` của `main()`. | Gây **Race Condition**: Khi mở app vào ProfileScreen, Switch có thể được gạt trước khi plugin kịp hoàn tất `initialize()`, dẫn đến gọi lệnh bắn thông báo khi plugin chưa sẵn sàng. |
| **2. Tên Icon Android Notification** | Sử dụng `'@mipmap/ic_launcher'` (icon mặc định luôn có sẵn). | Đã đổi sang `'ic_notification'`. | Tên file mới không có tiền tố `@drawable/` trong hàm khởi tạo. |
| **3. Bảo vệ tài nguyên Release (`keep.xml`)** | Khai báo `tools:keep="@mipmap/ic_launcher"`. | Vẫn chỉ có `tools:keep="@mipmap/ic_launcher"`, **KHÔNG CÓ `ic_notification`**. | Trình R8 / Proguard khi build APK Release quét thấy không có code Java/Kotlin nào trỏ cứng tới `ic_notification` nên **tự động cắt bỏ (shrink)** ảnh này khỏi APK, gây `ResourceNotFoundException`. |
| **4. Cấu hình iOS trong `showTestNotification`** | Sử dụng `DarwinNotificationDetails()`. Nhưng v1.0.6 bắn thông báo ngay qua `generateScheduleCards` -> `showImmediate` (có `presentAlert: true`). | Chỉ gọi `showTestNotification()` với `iOS: DarwinNotificationDetails()`. | `DarwinNotificationDetails` mặc định để `presentAlert: null/false`. Khi app đang ở Foreground (màn hình Profile), iOS **chặn hiển thị toàn bộ banner và âm thanh**. |
| **5. Quyền Runtime Android 13+** | Đã được cấp từ các phiên debug trước đó. | Cài mới hoặc nâng cấp trên máy thật Android 13/14 chưa được hệ thống cấp quyền `POST_NOTIFICATIONS`. | Hệ điều hành Android âm thầm drop thông báo mà không hiển thị lại popup nếu đã bị từ chối trước đó. |

---

### 1.3. Lỗi Liệt Đồng Bộ Nền Khi User Cập Nhật (Background Sync Credentials Defect):
- **Trong v1.0.6:** `BackgroundSyncService` đọc tài khoản/mật khẩu từ `SharedPreferences` (`saved_mssv`, `saved_pw`).
- **Trong v1.1.0:** Chuyển sang đọc độc quyền từ `FlutterSecureStorage` (`BgCredentials.load()`). Nếu `creds == null` thì hủy task ngay lập tức.
- **Lỗ hổng:** `BgCredentials.save(...)` **chỉ được gọi trong hàm `login()`**. Khi người dùng v1.0.6 cập nhật lên v1.1.0, cơ chế Auto-Login (`quickAuthCheck`) đưa user thẳng vào màn hình chính mà không hề gọi hàm `login()`. Do đó, `FlutterSecureStorage` của 100% user cập nhật đều bị **RỖNG (NULL)**, khiến tiến trình chạy ngầm chết lặng vĩnh viễn cho đến khi họ đăng xuất rồi đăng nhập lại.

---

## 2. QUY CÁCH GIẢI PHÁP CHI TIẾT (SPECIFICATIONS)

### Phân Hệ 1: Khắc Phục Triệt Để Luồng Thông Báo (Android & iOS)

#### AC-NOTIF-01: Bảo toàn Icon Thông Báo Trên Android Release
- **Tệp áp dụng:** `android/app/src/main/res/raw/keep.xml`
- **Quy chuẩn:** Bổ sung khai báo bảo vệ `@drawable/ic_notification` để trình biên dịch R8 / Code Shrinker không bao giờ loại bỏ icon khi xuất bản APK/AAB:
  ```xml
  <?xml version="1.0" encoding="utf-8"?>
  <resources xmlns:tools="http://schemas.android.com/tools"
      tools:keep="@mipmap/ic_launcher,@drawable/ic_notification" />
  ```

#### AC-NOTIF-02: Đồng Bộ Cấu Hình Hiển Thị iOS Tiền Cảnh (Foreground Banner)
- **Tệp áp dụng:** `lib/services/local_notification_service.dart`
- **Quy chuẩn:** Tại hàm `showTestNotification()`, thiết lập đầy đủ quyền hiển thị tiền cảnh cho iOS giống hệt hàm `showImmediate()`:
  ```dart
  iOS: const DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  ),
  ```

#### AC-NOTIF-03: Triệt Tiêu Race Condition Khởi Tạo Notification Service
- **Tệp áp dụng:** `lib/main.dart`
- **Quy chuẩn:** Khởi tạo `LocalNotificationService.init(...)` đồng bộ hoặc ưu tiên hoàn tất trước khi render router, đảm bảo plugin đã sẵn sàng 100% trước khi người dùng có thể tương tác với nút gạt thông báo.

#### AC-NOTIF-04: Cảnh Báo Quyền Trực Quan Trên Android 13+
- **Tệp áp dụng:** `lib/screens/profile_screen.dart`
- **Quy chuẩn:** Khi người dùng bật Switch thông báo, nếu `requestPermissions()` trả về thất bại (do người dùng từng từ chối quyền trên Android Settings), hiển thị một Dialog hoặc SnackBar hướng dẫn: *"Vui lòng cấp quyền Thông báo trong Cài đặt của máy để nhận thông báo lịch học"*.

---

### Phân Hệ 2: Giải Cứu Màn Hình Trắng Splash (Zero White Screen Hang)

#### AC-SPLASH-01: Thoát Splash Bằng `quickAuthReady`
- **Tệp áp dụng:** `lib/main.dart` (tại `_AppRouterState._initAuth()`)
- **Quy chuẩn:** Thay thế `await p.authReady;` bằng `await p.quickAuthReady;`:
  ```dart
  Future<void> _initAuth() async {
    final p = context.read<AppProvider>();
    await p.quickAuthReady; // Thoát splash trong 10-30ms ngay khi đọc xong prefs
    if (mounted) {
      setState(() => _quickAuthDone = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FlutterNativeSplash.remove(); // Gỡ bỏ Splash lập tức
      });
    }
  }
  ```
- **Hành vi sau khi sửa:**
  - Ngay khi kiểm tra xong trạng thái đăng nhập, Splash Screen được gỡ bỏ ngay lập tức.
  - Người dùng lập tức nhìn thấy giao diện Dashboard với khung xương Shimmer (`AppShimmerScope`) sang trọng trong khi SQLite thực hiện nạp dữ liệu ở tầng nền.
  - Loại bỏ hoàn toàn cảm giác bị đơ / treo màn hình trắng.

---

### Phân Hệ 3: Tự Động Di Trú Thông Tin Đồng Bộ Nền (BgCredentials Auto-Migration)

#### AC-BG-01: Tự Động Nạp Credentials Cho User Cập Nhật
- **Tệp áp dụng:** `lib/providers/app_provider.dart` (tại hàm `init()`)
- **Quy chuẩn:** Trong bước khởi tạo dữ liệu của người dùng đã đăng nhập (`_authState == AuthState.loggedIn`):
  ```dart
  // Kiểm tra và tự động di trú thông tin đăng nhập sang Secure Storage nếu còn thiếu
  final bgCreds = await BgCredentials.load();
  if (bgCreds == null && _currentMssv != 'admin') {
    final prefs = await SharedPreferences.getInstance();
    final savedPw = prefs.getString(_kPw) ?? '';
    if (savedPw.isNotEmpty) {
      await BgCredentials.save(_currentMssv, savedPw);
      debugPrint('🔑 [Auto-Migration] Đã di trú thông tin đăng nhập vào Secure Storage cho Background Sync');
    }
  }
  ```
- **Hiệu quả:** 100% người dùng nâng cấp từ v1.0.6 lên v1.1.0 sẽ được tự động kích hoạt lại tính năng đồng bộ ngầm và nhận thông báo nhắc lịch mà không cần phải thực hiện đăng xuất/đăng nhập lại.

---

### Phân Hệ 4: Tinh Chỉnh Reconcile Tránh Bắn Thông Báo Ảo Khi Nâng Cấp

#### AC-RECON-01: Ngăn Chặn Thông Báo Lệch Số Lượng Bản Ghi Giả Tạo
- **Tệp áp dụng:** `lib/providers/app_provider.dart` (tại `_detectAndNotify()`)
- **Quy chuẩn:** Khi cờ `needsReconcile` được kích hoạt do nâng cấp phiên bản ứng dụng (`lastReconciledVer != currentVer`), tạm thời vô hiệu hóa việc so sánh chênh lệch `newCount > prevCount` trong lần sync đầu tiên này để tránh phát thông báo rác: *"Có X buổi học mới"* hoặc *"Có điểm mới"* khi thực tế chỉ là do đồng bộ lại cấu trúc dữ liệu mới.

---

## 3. MA TRẬN KIỂM THỬ (TEST PLAN)

1. **Test Case 1 (iOS Foreground Notif):** Mở app trên iPhone thật ➔ Vào Profile ➔ Bật Switch thông báo ➔ Kiểm tra banner "Thử nghiệm thông báo" xuất hiện ngay trên đầu màn hình kèm âm thanh.
2. **Test Case 2 (Android Release Notif):** Build file APK Release (`flutter build apk --release`) ➔ Cài lên máy thật Android 13/14 ➔ Bật thông báo ➔ Kiểm tra icon hiển thị sắc nét, không bị crash hoặc biến thành ô vuông xám.
3. **Test Case 3 (Splash Duration):** Đóng hẳn app (Force Stop) ➔ Khởi động lại ➔ Màn hình splash native chuyển sang Dashboard trong vòng dưới 300ms, Shimmer loading xuất hiện mượt mà.
4. **Test Case 4 (Upgrade Background Sync):** Cài bản 1.0.6 ➔ Đăng nhập ➔ Cài đè bản 1.1.0 ➔ Chạy kiểm tra `BgCredentials.load()` trả về dữ liệu hợp lệ, WorkManager chạy tác vụ ngầm thành công.
