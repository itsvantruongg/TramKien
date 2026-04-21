# Trạm Kiến — Cổng Thông Tin Sinh Viên HAU

App quản lý thông tin học tập, tài chính và lịch học cho sinh viên Trường Đại học Kiến trúc Hà Nội (HAU), với giao diện hiện đại .

## � Giới thiệu

**Trạm Kiến** là ứng dụng mobile toàn diện giúp sinh viên HAU quản lý toàn bộ thông tin học tập trên một nền tảng duy nhất. Thay vì phải truy cập nhiều trang web khác nhau, sinh viên có thể:

- ✅ Xem lịch học, lịch thi trực quan trên ứng dụng
- ✅ Theo dõi điểm số, GPA tích lũy theo thời gian
- ✅ Quản lý học phí, tiến độ nộp một cách rõ ràng
- ✅ Nhận thông báo tức thời về sự kiện học tập quan trọng
- ✅ Sử dụng offline - dữ liệu được lưu local trên điện thoại
- ✅ Giao diện đẹp, hiện đại, dễ sử dụng

Dự án sử dụng **Flutter** để phát triển, đảm bảo chạy mượt mà trên cả Android và iOS.

## �🚀 Tính năng chính

| Tính năng | Mô tả |
|---|---|
| **Đăng nhập bảo mật** | Đăng nhập bằng tk/mk trường, lưu secure với `flutter_secure_storage` |
| **Dashboard** | Hiển thị GPA, tín chỉ đạt được, lịch học hôm nay, thi sắp tới, học phí |
| **Lịch học** | View theo tuần (weekly) và view theo tháng (monthly), chi tiết ngày |
| **Điểm số** | Xem GPA chart, điểm từng môn học, tính toán học lực |
| **Tài chính** | Tổng học phí, tiến độ nộp, lịch sử giao dịch chi tiết |
| **Thông tin cá nhân** | Quản lý profile sinh viên, thông tin liên lạc |
| **Thông báo** | Push notification cho lịch học, kết quả thi, học phí |
| **SQLite Cache** | Cache-first strategy, TTL per data type, hỗ trợ offline |
| **Smart refresh** | Tự động cập nhật theo TTL, manual refresh |

## 📁 Cấu trúc Project

```
lib/
├── main.dart                          # Entry point + routing (Splash, Login, Main)
├── theme/
│   └── app_theme.dart                 # Design tokens (colors, typography, spacing)
├── models/
│   └── models.dart                    # Data models: Student, LichHoc, LichThi, DiemMonHoc, HocPhi
├── providers/
│   ├── app_provider.dart              # State management chính (auth, user data)
│   ├── schedule_provider.dart         # Quản lý lịch học
│   ├── grade_provider.dart            # Quản lý điểm số
│   └── finance_provider.dart          # Quản lý tài chính
├── services/
│   ├── database_service.dart          # SQLite CRUD operations
│   ├── hau_api_service.dart           # Web scraping tinchi.hau.edu.vn
│   ├── local_notification_service.dart # Push notifications
│   ├── notification_service.dart      # Notification logic
│   ├── api/                           # API helpers
│   ├── db/                            # Database migrations
│   └── mock_data.dart                 # Mock data for testing
├── screens/
│   ├── login_screen.dart              # Màn hình đăng nhập
│   ├── main_shell.dart                # Bottom nav shell
│   ├── dashboard_screen.dart          # Trang chủ dashboard
│   ├── schedule_screen.dart           # Lịch học weekly/daily
│   ├── curriculum_screen.dart         # Danh sách môn học
│   ├── grades_screen.dart             # Xem điểm
│   ├── finance_screen.dart            # Quản lý học phí
│   ├── profile_screen.dart            # Thông tin cá nhân
│   ├── terms_screen.dart              # Kỳ học
│   ├── feedback_screen.dart           # Góp ý
│   ├── notifications_screen.dart      # Trung tâm thông báo
│   └── ...
└── widgets/
    └── shared_widgets.dart            # Reusable UI components
```
## 🔑 Tài khoản trải nghiệm (Demo Account)

Để giúp mọi người có thể trải nghiệm nhanh ứng dụng mà không cần tài khoản sinh viên thực tế, bạn có thể sử dụng thông tin sau:

- **Tên đăng nhập:** `admin` 
- **Mật khẩu:** `admin@123` 

> [!NOTE]
> Tài khoản này được cung cấp cho mục đích demo tính năng. Mọi thông tin trong tài khoản này đều là dữ liệu giả lập.


## 📦 Dependencies chính

- **UI**: `google_fonts`, `material_symbols_icons`
- **HTTP & Parsing**: `http`, `beautiful_soup_dart`, `html` (web scraping)
- **Storage**: `sqflite`, `shared_preferences`, `flutter_secure_storage`
- **Notifications**: `flutter_local_notifications`, `timezone`, `android_intent_plus`
- **State Management**: `provider`
- **Utils**: `intl` (localization), `url_launcher`, `crypto`

## 🔧 Cài đặt & Chạy

### Yêu cầu
- Flutter 3.0.0+
- Dart 3.0.0+
- Android SDK / iOS 11+

### Setup

```bash
# 1. Clone repo và dependencies
git clone <repo-url>
cd demo
flutter pub get

# 2. Chạy app
flutter run

# 3. Build APK/IPA
flutter build apk        # Android
flutter build ios        # iOS
```

## 📚 Hướng dẫn sử dụng

### 🔓 Bước 1: Đăng nhập
1. Mở ứng dụng Trạm Kiến
2. Nhập **tên đăng nhập** (MSSV mà trường cấp)
3. Nhập **mật khẩu** (từ trang tinchi.hau.edu.vn)
4. Tap **"Đăng nhập"**
5. ✅ App sẽ lưu thông tin an toàn (không hiển thị mật khẩu lần sau)

> **💡 Mẹo:** Mật khẩu được mã hóa và lưu trong Keystore (Android) / Keychain (iOS), cực kỳ bảo mật.

### 📊 Bước 2: Xem Dashboard
Sau khi đăng nhập, bạn sẽ thấy trang chủ với:
- **GPA hiện tại** - Chỉ số GPA tích lũy
- **Tín chỉ đạt được** - Tổng số tín chỉ hoàn thành
- **Lịch hôm nay** - Các tiết học hôm nay (nếu có)
- **Thi sắp tới** - Kỳ thi gần nhất
- **Học phí** - Tổng nợ / đã nộp

### 📅 Bước 3: Xem Lịch học
**Tab "Lịch học"** (giữa màn hình):
1. Chọn **"Tuần"** hoặc **"Tháng"** ở trên cùng
2. Vuốt trái/phải để xem các tuần khác

### 📈 Bước 4: Xem Điểm số
**Tab "Điểm số"** (phần tử 3):
1. Xem **GPA chart** - Biểu đồ GPA theo kỳ
2. Cuộn xuống xem **điểm từng môn**:
   - Tên môn học
   - Điểm 10 (nếu có)
   - Điểm chữ (A, B, C...)
   - Trạng thái (Đạt / Chưa đạt)
3. Tap vào môn để xem chi tiết bài tập, kiểm tra

### 💰 Bước 5: Quản lý Học phí
**Tab "Tài chính"** (phần tử 4):
1. Xem **tổng nợ** - Học phí còn phải nộp
2. Xem **tiến độ nộp** - % đã hoàn thành
3. Xem **lịch sử giao dịch** - Danh sách các lần nộp
   - Ngày nộp
   - Số tiền
   - Phương thức thanh toán
4. **Tính toán còn nợ**: Tổng học phí - Đã nộp = Còn nợ

### 👤 Bước 6: Cập nhật Thông tin
**Tab "Thông tin"** (phần tử 5):
1. Xem **thông tin cá nhân**:
   - MSSV, họ tên, ngày sinh
   - Giới tính, chuyên ngành, khoá
   - Email, số điện thoại
2. Tap **"Chỉnh sửa"** để cập nhật (nếu có)
3. Lưu lại

### 🔔 Bước 7: Bật Thông báo
1. Tap biểu tượng **🔔 Bell** ở góc trên phải
2. Chọn **"Đã bật"** để nhận:
   - 📅 Thông báo lịch học và lịch thi (20h ngày hôm trước và 1tiếng trước khi học/thi)
   - 📝 Kết quả thi (ngay khi có)
   - 💳 Học phí (1 tuần trước deadline)
   - 🔗 Thông báo khác từ trường
3. Có thể tắt từng loại notification riêng biệt

### 🔄 Bước 8: Làm mới dữ liệu
- **Auto-refresh**: App tự cập nhật mỗi 1-3 ngày (tùy loại dữ liệu)
- **Manual refresh**: Kéo từ trên xuống (pull-to-refresh) để cập nhật ngay

### 🔗 Bước 9: Các chức năng khác
- **Feedback** - Góp ý cho đội phát triển
- **Logout** - Đăng xuất tài khoản (trong Settings)
- **Dark mode** - Tự động theo cài đặt hệ thống

> **📌 Tip Pro:** Dữ liệu được lưu offline, nên bạn vẫn có thể xem lịch/điểm ngay cả khi không có internet. Khi online, app sẽ tự cập nhật lại.

## 🎨 Design System

Theo "Editorial Academic Fluidity":
- **Color Palette**:
  - Primary: `#005DAC` → `#1976D2` gradient
  - Surface: Neutral grays
  - Semantic: Green (success), Red (error), Amber (warning)
- **Typography**:
  - Headlines: Manrope (bold, distinctive)
  - Body: Inter (readable, modern)
- **Design Principles**:
  - No-line rule: Phân cách bằng tonal shifts thay vì border
  - Glassmorphism: Bottom nav với blur effect
  - Spacing: 8px grid system

## 🔐 Bảo mật

- ✅ Credentials lưu với `flutter_secure_storage` (Keystore Android, Keychain iOS)
- ✅ HTTPS for API calls
- ✅ Password encryption với `crypto` package
- ✅ Session timeout handling

## 📊 Cơ sở dữ liệu

- **Local**: SQLite (`sqflite`) cho caching
- **TTL Strategy**:
  - Student info: 7 ngày
  - Schedule: 1 ngày
  - Grades: 3 ngày
  - Finance: 1 ngày
- **Sync**: Background sync khi app online

## 🐛 Troubleshooting

| Vấn đề | Giải pháp |
|---|---|
| Lỗi scraping data | Kiểm tra kết nối internet, website HAU có thay đổi HTML? |
| Cache không cập nhật | Xóa app data, clear SQLite |
| Notification không hiện | Check permission Android 12+, iOS notification settings |
| Build error | `flutter clean && flutter pub get && flutter run` |

## 📝 Ghi chú phát triển

- Scraping HAU dùng `beautiful_soup_dart` - cần maintain khi website thay đổi
- All screens use Provider for state management
- Localization setup for Vietnamese (vi_VN)
- Custom bottom nav shell sử dụng Flutter Router pattern
- **Bento grid**: Dashboard layout

## Lưu ý

- Session HAU hết hạn ~20-30 phút, app tự re-login bằng secure storage-> bạn ko cần phải nhập lại mssv+pass (nếu như đã ấn lưu)
- Data nhạy cảm (mk) lưu trong FlutterSecureStorage (Keychain/Keystore)
- SQLite chỉ lưu data cá nhân của user trên thiết bị của họ