# Đặc Tả Kỹ Thuật: Biến Thể Lịch 4x2 Timeline, Tối Giản Hóa Card Lịch & Mặc Định Tắt Mã Môn (SPEC-TIMELINE-WIDGET-01)

- **Trạng thái:** APPROVED (Người dùng đã duyệt)
- **Phiên bản:** 1.0.0
- **Ngày lập:** 26/10/2026
- **Mã dự án:** [HAU] (Flutter / Android / iOS)
- **Tác giả:** Senior BA / Master Orchestrator

---

## 1. MỤC TIÊU VÀ PHẠM VI
1. **Thiết kế & Bổ sung Biến thể Lịch Hôm Nay 4x2 Timeline chuyên biệt:**
   - Cung cấp sẵn widget kích thước 4x2 ngang độc lập cho cả Android Launcher và iOS WidgetKit (`.systemMedium`), không bắt người dùng phải kéo dãn thủ công.
   - Bố cục tối giản (Minimal Timeline): Cột trái hiển thị duy nhất giờ bắt đầu (`7h`, `9h`, ... - không giờ kết thúc, không đường nối hairline, không chấm tròn); Cột phải hiển thị tối đa 2 dòng (Dòng 1: Tên môn, Dòng 2: Toàn bộ thông tin phụ trợ gom trên đúng 1 hàng duy nhất).
2. **Áp dụng Bố cục Timeline cho Dashboard (In-App):**
   - Áp dụng bố cục Timeline tối giản này vào mục "Lịch học hôm nay" và "Lịch học ngày mai" trên Dashboard.
   - Khóa cứng giới hạn hiển thị tối đa đúng 2 ca học (`take(2)`). Nếu có $\ge 3$ môn, hiển thị dòng tóm tắt tinh tế: `(+N ca học khác • Xem tất cả)`.
3. **Quy chuẩn Mã môn học / Mã lớp học phần (`showClassCode`):**
   - Đặt lại mặc định toàn hệ thống là **TẮT (`false`)**. Ban đầu ẩn hoàn toàn để giao diện sạch sẽ, chỉ hiển thị khi người dùng chủ động vào bật switch.
   - Bổ sung chip hiển thị mã môn (`tenLopTinChi`, e.g. `TH4327_23CN 2`) vào các thẻ lịch trong app (`ScheduleCard` trên Dashboard và `_ScheduleCardFull` trên Màn hình Lịch), tự động ẩn/hiện đồng bộ theo cờ `showClassCode`.
4. **Bảo toàn 100% các tính năng đã nghiệm thu:** Thẻ 2x2 căn lề trên (top-aligned), Skeleton Shimmer quét liên tục toàn app, bản build CI iOS `v1.1.0`.

---

## 2. DANH SÁCH ACCEPTANCE CRITERIA (TIÊU CHÍ NGHIỆM THU)

### AC-01: Bổ Sung Biến Thể 4x2 Lịch Hôm Nay Timeline Cho Android
- **Tệp:** `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/res/layout/widget_schedule_single_day.xml`, `android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt`, `android/app/src/main/res/xml/widget_schedule_single_day_info.xml`
- **Mô tả:** Mở lại `SingleDayScheduleWidgetProvider` thành widget 4x2 chính thức với giao diện Timeline tối giản.
- **Yêu cầu kỹ thuật:**
  - Bật `android:enabled="true"` cho `SingleDayScheduleWidgetProvider` trong `AndroidManifest.xml` với nhãn `"Lịch hôm nay"` (không gắn thêm chữ 4x2 vì Android launcher đã tự hiển thị số ô lưới).
  - Cập nhật layout `widget_schedule_single_day.xml`:
    * Cột trái: Hiển thị duy nhất giờ bắt đầu (ví dụ: `7h`, `9h30`, `12h45`). Không có giờ kết thúc, không có đường nối hairline.
    * Cột phải: Mỗi ca học gồm 2 dòng:
      - Dòng 1: Tên môn học to rõ (font 12sp - 13sp, in đậm, `maxLines="1"`, ellipsis).
      - Dòng 2: Hàng thông tin phụ trợ nằm trên **đúng 1 hàng ngang duy nhất**: `[Phòng] • [Giảng viên] • [Mã môn (nếu bật)]`.
    * Giới hạn tối đa 2 ca học. Nếu ngày có $\ge 3$ ca học: Hiển thị dòng badge `(+N môn nữa)`.
  - Nếu người dùng đặt widget 2x2 và kéo dài sang 4x2: Tự động responsive chuyển sang bố cục Timeline tương tự.

### AC-02: Đồng Bộ Biến Thể 4x2 Timeline Trên iOS WidgetKit (`.systemMedium`)
- **Tệp:** `ios/Runner/ScheduleWidgetKit.swift`
- **Mô tả:** Trong Widget Gallery của iOS, khi người dùng chọn kích thước Vừa (`.systemMedium`), widget hiển thị bố cục Timeline tối giản tương tự Android.
- **Yêu cầu kỹ thuật:**
  - Trong view `.systemMedium`:
    * Cột trái: Text giờ bắt đầu (e.g. `"7h"`, `"9h"` trích xuất từ `timeSlot.split("-").first`).
    * Cột phải: Tên môn học + 1 dòng phụ trợ (`\(c.room) • \(c.teacher)` và `• \(c.classCode)` nếu `showClassCode == true`).
    * Giới hạn hiển thị tối đa 2 ca học. Nếu có ca thứ 3: Text `(+N môn nữa)`.

### AC-03: Áp Dụng Timeline Tối Giản & Giới Hạn 2 Hàng Trên Dashboard (In-App)
- **Tệp:** `lib/screens/dashboard_screen.dart`, `lib/widgets/shared_widgets.dart`
- **Mô tả:** Nâng cấp mục "Lịch học hôm nay" và "Lịch học ngày mai" trên Dashboard sang bố cục Timeline 2 cột tối giản, giới hạn tối đa 2 hàng.
- **Yêu cầu kỹ thuật:**
  - Khóa cứng `list.take(2)` trong `_buildScheduleList`.
  - Thiết kế `ScheduleTimelineCard`:
    * Cột trái: Giờ bắt đầu duy nhất (e.g. `7h`, `12h45`, `AppTheme.primary`, w800, 14sp). Không có giờ kết thúc, không đường kẻ hairline dọc.
    * Cột phải: SurfaceCard bo góc, dòng 1 là tên môn học, dòng 2 là các chip thông tin nằm trên **đúng 1 hàng ngang duy nhất** (Phòng, Giảng viên, Mã môn nếu bật).
  - Nếu `list.length > 2`: Hiển thị nút link nhẹ nhàng bên dưới `(+${list.length - 2} ca học khác • Xem tất cả)` chuyển hướng sang Tab Lịch học.

### AC-04: Mặc Định Tắt Mã Môn Học Toàn Hệ Thống (`showClassCode: false`)
- **Tệp:** `lib/models/widget_models.dart`, `lib/screens/widget_studio_screen.dart`
- **Mô tả:** Mã lớp học phần (`TH4327_23CN 2`) có giá trị mặc định là `false` (Tắt) trên toàn hệ thống.
- **Yêu cầu kỹ thuật:**
  - Trong `WidgetThemeConfig`:
    * Khởi tạo `showClassCode: false` tại tất cả các named constructors / presets (`minimalSwiss`, `frostedGlass`, `cyberpunkNeon`, etc.).
    * Trong `fromJson`: `showClassCode = json['show_class_code'] ?? false`.
  - Trong `WidgetStudioScreen`: Switch "Hiện Mã lớp học phần" mặc định ở vị trí `false`. Chỉ khi người dùng chủ động gạt bật thì mới chuyển thành `true`.

### AC-05: Bổ Sung Hiển Thị Mã Môn Học Vào Các Thẻ Lịch Học Trong App
- **Tệp:** `lib/widgets/shared_widgets.dart`, `lib/screens/schedule_screen.dart`
- **Mô tả:** Khi cờ `showClassCode == true`, mã môn học (`tenLopTinChi`, e.g. `TH4327_23CN 2`) được hiển thị trên hàng thông tin phụ trợ của tất cả các thẻ lịch trong app.
- **Yêu cầu kỹ thuật:**
  - Trong `ScheduleTimelineCard` / `ScheduleCard` (Dashboard): Thêm chip mã lớp vào hàng phụ trợ khi `showClassCode == true` và `tenLopTinChi.isNotEmpty`.
  - Trong `_ScheduleCardFull` (Màn hình Lịch): Thêm chip `_Chip(Icons.tag, lichHoc.tenLopTinChi)` vào hàng phụ trợ khi `showClassCode == true`.
  - Đảm bảo hàng phụ trợ luôn nằm trên **đúng 1 hàng duy nhất**, tự động scale/ellipsis nếu text dài.

### AC-06: Bảo Toàn Tính Năng & Zero Regressions
- **Tệp:** Toàn bộ test suites
- **Mô tả:** Toàn bộ 292 bài kiểm thử tự động hiện có phải tiếp tục PASS 100%, không phát sinh lỗi biên dịch, không lỗi layout, không lỗi 2018.

---

## 3. QUY TRÌNH THỰC HIỆN & KIỂM THỬ KHÉP KÍN (CLOSED-LOOP PROTOCOL)
1. **BA:** Trình Spec cho User phê duyệt.
2. **DEV (dev2):** Khi User duyệt, tự động lập trình đáp ứng 100% các tiêu chí từ AC-01 đến AC-06.
3. **TESTER (tester):** 
   - Kiểm thử tự động qua test suite.
   - **Bắt buộc đọc và đối soát trực tiếp từng dòng Code Diff** trong Git để tìm lỗi ngầm, xung đột layout hay vỡ giao diện. Nếu phát hiện lỗi, bắt DEV sửa lại đến khi PASS 100%.
   - Xuất biên bản kiểm thử `docs/specs/timeline_widget-test-report.md`.
4. **BA:** Đối soát kiểm tra lại từ đầu toàn bộ mã nguồn DEV đã sửa xem có đúng, đủ và xung đột gì không trước khi xuất biên bản UAT Sign-off cho User.
