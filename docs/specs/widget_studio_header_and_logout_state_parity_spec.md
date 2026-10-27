# ĐẶC TẢ KỸ THUẬT (TECHNICAL SPECIFICATION)
## Phân Hệ: Chuẩn Hóa Header Widget Studio (Typography, Spacing, Icon) & Đồng Bộ Trạng Thái Đăng Xuất Cho Widget "Lịch Hôm Nay" 4x2 (Android & iOS)

- **Mã tài liệu:** `SPEC-WIDGET-STUDIO-HEADER-AND-LOGOUT-STATE-PARITY-01`
- **Phiên bản:** `1.0.0`
- **Tác giả:** Senior BA / Hermes Master Orchestrator
- **Dự án:** Trạm Kiến - Ứng dụng Quản lý Học tập & Lịch học HAU (Flutter / Android Kotlin / iOS Swift)
- **Tình trạng:** Chờ User duyệt (Pending Approval)

---

## 1. BỐI CẢNH & PHÂN TÍCH HIỆN TRẠNG (ROOT CAUSE)

### 1.1. Vấn đề 1: Header của trang Widget Studio bị lệch, khoảng cách quá xa nút Back và chứa Emoji
- **Hiện trạng:**
  - `AppBar` trong `lib/screens/widget_studio_screen.dart` dùng `AppBar` mặc định của Flutter, không có `leading` tường minh và thiếu `titleSpacing: 0`, dẫn đến cụm tiêu đề bị thụt sâu sang phải, khoảng cách từ nút back `←` tới chữ quá xa.
  - Màu nền AppBar và màu text đang hardcode (`Colors.white`, `Color(0xFF191C1D)`) thay vì đồng bộ bảng màu chuẩn của ứng dụng (`AppTheme.surface`, `AppTheme.primary`).
  - Dòng hướng dẫn ở cuối trang sử dụng emoji `💡` (`'💡 Để đưa widget ra màn hình: ...'`), không đạt chuẩn thiết kế Thụy Sĩ/Apple (Anti-AI Slop, No Emoji).

### 1.2. Vấn đề 2: Khi Đăng xuất, Widget "Lịch hôm nay" 4x2 chưa được gắn trạng thái "Vui lòng đăng nhập" như 2 widget còn lại
- **Hiện trạng từ hình ảnh thực tế (`image_bce268.png`):**
  - Khi người dùng đăng xuất trong ứng dụng, `WidgetDataSyncService.clearAllWidgetData()` xóa sạch dữ liệu SharedPreferences và phát tín hiệu cập nhật.
  - Widget 3 Ngày và Widget Tuần bắt đúng trạng thái rỗng và hiển thị thẻ thông báo: `"Trạm Kiến • Vui lòng đăng nhập"`.
  - Riêng Widget "Lịch hôm nay" (4x2 Timeline) vẫn để lộ nguyên vẹn lịch học cá nhân (*"Lập trình mạng", "12h45 - 17h05", "P.M-M5.07", "Phạm Trọng Tuấn"*) của phiên đăng nhập trước đó!
- **Nguyên nhân kỹ thuật:**
  - Trong `android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt`:
    Khi `effectiveDataJsonStr.isNullOrEmpty()`, nhánh `single_day` đặt text cho `class_empty_message`, nhưng **KHÔNG hề ẩn `single_day_content` (chưa gọi `View.GONE`)** và **KHÔNG hề bật `class_empty_message` (chưa gọi `View.VISIBLE`)**. Do đó, giao diện môn học cũ vẫn hiển thị nguyên vẹn.
  - Trong `ios/Runner/ScheduleWidgetKit.swift`: Nhánh `.systemMedium` chưa có khối xử lý rỗng khi chưa đăng nhập để hiển thị `"Trạm Kiến • Vui lòng đăng nhập"` đồng bộ với Android.

---

## 2. GIẢI PHÁP KỸ THUẬT CHI TIẾT (ĐỒNG BỘ 3 NỀN TẢNG)

### 2.1. Phân hệ 1: Chuẩn hóa Header & Typography Trang Widget Studio (`widget_studio_screen.dart`)
- **Tệp áp dụng:** `lib/screens/widget_studio_screen.dart`
- **Chi tiết triển khai:**
  1. **Cấu trúc AppBar chuẩn hệ thống:**
     ```dart
     appBar: AppBar(
       backgroundColor: AppTheme.surface,
       surfaceTintColor: Colors.transparent,
       elevation: 0,
       centerTitle: false,
       leading: IconButton(
         icon: const Icon(Icons.arrow_back, color: AppTheme.primary),
         onPressed: () => Navigator.pop(context),
       ),
       titleSpacing: 0, // 🎯 Tiêu đề bám sát nút back chuẩn 4dp-8dp
       title: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Text(
             'WIDGET STUDIO',
             style: TextStyle(
               fontFamily: 'Manrope',
               fontSize: 16,
               fontWeight: FontWeight.w800,
               letterSpacing: 1.2,
               color: AppTheme.primary,
             ),
           ),
           Text(
             'XƯỞNG TÙY BIẾN THỜI KHÓA BIỂU THỤY SĨ',
             style: TextStyle(
               fontFamily: 'Inter',
               fontSize: 10,
               fontWeight: FontWeight.w600,
               letterSpacing: 0.5,
               color: AppTheme.outline,
             ),
           ),
         ],
       ),
       actions: [ ... nút ÁP DỤNG giữ nguyên ... ],
     )
     ```
  2. **Thay thế Emoji bằng Icon Vector:**
     - Thay chuỗi `'💡 Để đưa widget...'` bằng `Row`:
       ```dart
       Row(
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
           Icon(Icons.lightbulb_outline_rounded, size: 16, color: AppTheme.primary),
           SizedBox(width: 6),
           Text(
             'Để đưa widget ra màn hình: Nhấn giữ màn hình chính ➔ Widget ➔ Chọn Trạm Kiến',
             style: TextStyle(...),
           ),
         ],
       )
       ```

### 2.2. Phân hệ 2: Xử lý trạng thái Đăng Xuất trên Android Native (`ScheduleWidgetProvider.kt`)
- **Tệp áp dụng:** `android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt`
- **Chi tiết triển khai:**
  - Trong nhánh `when (layoutType)` khi `effectiveDataJsonStr.isNullOrEmpty()`:
    ```kotlin
    "single_day" -> {
        views.setTextViewText(R.id.widget_title, "Trạm Kiến")
        views.setViewVisibility(R.id.widget_subtitle, View.GONE)
        // Ẩn toàn bộ nội dung môn học cá nhân
        views.setViewVisibility(R.id.single_day_content, View.GONE)
        // Hiển thị thông báo đăng nhập đồng bộ
        views.setTextViewText(R.id.class_empty_message, "Trạm Kiến • Vui lòng đăng nhập")
        views.setTextColor(R.id.class_empty_message, textSecColor)
        views.setViewVisibility(R.id.class_empty_message, View.VISIBLE)
    }
    ```
  - Khi người dùng đăng xuất, toàn bộ dữ liệu cá nhân bị ẩn lập tức, thẻ 4x2 hiển thị thông báo đăng nhập ngay ngắn, an toàn bảo mật.

### 2.3. Phân hệ 3: Đồng bộ trạng thái Đăng Xuất trên iOS WidgetKit (`ScheduleWidgetKit.swift`)
- **Tệp áp dụng:** `ios/Runner/ScheduleWidgetKit.swift`
- **Chi tiết triển khai:**
  - Bổ sung cờ `isLoggedIn` hoặc kiểm tra `scheduleJsonStr == nil`:
  - Trong `.systemMedium`: Khi chưa đăng nhập hoặc dữ liệu rỗng, hiển thị tiêu đề `"Trạm Kiến"` và nội dung trung tâm `"Trạm Kiến • Vui lòng đăng nhập"`, màu xám mờ `.gray`, đạt Visual Parity 1:1 với Android.

---

## 3. TIÊU CHÍ NGHIỆM THU (ACCEPTANCE CRITERIA - AC)

| Mã AC | Tiêu chí nghiệm thu | Tiêu chuẩn đánh giá |
| :--- | :--- | :--- |
| **AC-01** | **Chuẩn hóa Header Widget Studio (Spacing & Theme)** | - `AppBar` trong `widget_studio_screen.dart` có `leading: IconButton(icon: Icon(Icons.arrow_back), ...)` và `titleSpacing: 0`.<br>- Tiêu đề mang màu `AppTheme.primary`, nền `AppTheme.surface`. |
| **AC-02** | **Loại bỏ 100% Emoji trên trang Widget Studio** | - Thay thế emoji `💡` bằng `Icon(Icons.lightbulb_outline_rounded)` chuẩn vector Native. Không còn ký tự emoji nào trong UI. |
| **AC-03** | **Widget 4x2 ẩn lịch cá nhân và hiện "Trạm Kiến • Vui lòng đăng nhập" khi đăng xuất (Android)** | - Khi `effectiveDataJsonStr.isNullOrEmpty()`, `single_day_content` bị ẩn (`View.GONE`), `class_empty_message` hiển thị `Trạm Kiến • Vui lòng đăng nhập` (`View.VISIBLE`). |
| **AC-04** | **Đồng bộ trạng thái Đăng Xuất trên iOS WidgetKit (.systemMedium)** | - `ScheduleWidgetKit.swift` hiển thị thông báo `"Trạm Kiến • Vui lòng đăng nhập"` khi chưa có dữ liệu đăng nhập, đạt Visual Parity 1:1 với Android. |
| **AC-05** | **Bảo toàn Test Suite & Không gây Regression Bug** | - 100% unit/widget test suites liên quan đều PASS. |

---

## 4. QUY TRÌNH ĐIỀU PHỐI TỰ ĐỘNG (AUTONOMOUS CLOSED-LOOP EXECUTION)

1. **Bước 1 (BA Spec):** User duyệt Spec.
2. **Bước 2 (Dev2 Code):** Tự động kích hoạt Sub-agent `dev2` lập trình cả 3 phân hệ (Flutter Dart, Android Kotlin, iOS Swift).
3. **Bước 3 (Tester Verify):** Tự động kích hoạt Sub-agent `tester` kiểm thử độc lập 2 tầng và lập Test Report.
4. **Bước 4 (BA Sign-off):** BA đối soát toàn diện và nghiệm thu bàn giao lại cho User.
