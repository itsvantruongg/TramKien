# Đặc Tả Kỹ Thuật: Tối Ưu Bố Cục Thẻ 2x2, Co Giãn Động 3 Dạng Widget & Đồng Bộ iOS Parity (SPEC-WIDGET-ENHANCEMENT-01)

- **Trạng thái:** APPROVED (Người dùng đã duyệt)
- **Phiên bản:** 1.0.0
- **Ngày lập:** 26/10/2026
- **Mã dự án:** [HAU] (Flutter / Android / iOS)
- **Tác giả:** Senior BA / Master Orchestrator

---

## 1. MỤC TIÊU VÀ PHẠM VI
1. **Khắc phục triệt để lỗi thẻ 2x2 bị trống hoác ở giữa:** Loại bỏ cơ chế căn giữa cưỡng bức và các spacer thừa, chuyển sang bố cục căn lề trên (Top-aligned) chuẩn mực, giải quyết triệt để lỗi môn học rơi lơ lửng xuống nửa dưới thẻ khi chỉ có 1 môn học.
2. **Kích hoạt cơ chế Responsive co giãn thông minh cho cả 3 dạng Widget (2x2, 3 Ngày, 7 Ngày):** Khi người dùng kéo dãn kích thước widget trên màn hình chính (Android Launcher Resize), tự động bung thêm diện tích hiển thị, thông tin chi tiết và thêm môn học thay vì bị cắt chữ hay hiện dòng `(+N môn nữa)`.
3. **Đồng bộ hóa tính năng trên WidgetKit iOS (`ScheduleWidgetKit.swift`):** Bổ sung hiển thị Tên Giảng Viên khi cờ `showTeacher` bật, đảm bảo tính năng đồng bộ 100% giữa Android và iOS.
4. **Cập nhật đồng bộ phiên bản phát hành tại CI GitHub Actions (`.github/workflows/dart.yml`):** Đưa phiên bản lên `v1.1.0` (khớp với `pubspec.yaml` 1.1.0+5).

---

## 2. DANH SÁCH ACCEPTANCE CRITERIA (TIÊU CHÍ NGHIỆM THU)

### AC-01: Tối Ưu Bố Cục Thẻ 2x2 Android & Triệt Tiêu Khoảng Trống Chết
- **Tệp:** `android/app/src/main/res/layout/widget_schedule_single_day_2x2.xml`
- **Mô tả:** Thẻ 2x2 khi chỉ có 1 môn học hoặc 2 môn học phải hiển thị ngay ngắn từ trên xuống, không bị spacer đẩy lơ lửng xuống giữa thẻ.
- **Yêu cầu kỹ thuật:**
  - Gỡ bỏ thuộc tính `android:gravity="center_vertical"` tại `widget_content_container` và `single_2x2_content`, chuyển sang `android:gravity="top"`.
  - Gỡ bỏ `single_2x2_top_spacer` (ImageView `layout_weight="1"` nằm trên Môn 1).
  - Gỡ bỏ spacer thứ hai (ImageView `layout_weight="1"` nằm giữa Môn 2 và Footer).
  - Khi có 1 môn học: Môn 1 nằm ngay sát dưới đường kẻ hairline, khoảng cách đệm trên/dưới đồng đều, thoáng đãng.
  - Khi có 2 môn học: Môn 2 xếp dưới Môn 1 với `layout_marginTop="6dp"`.
  - Khi có từ 3 môn trở lên: Dòng badge `(+N môn nữa)` nằm gọn gàng ở đáy thẻ.
  - Đồng bộ layout này trên Live Preview trong app (`lib/screens/widget_studio_screen.dart`).

### AC-02: Cơ Chế Co Giãn Động Cho Cả 3 Dạng Widget (Responsive Launcher Resize)
- **Tệp:** `android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt`, các file XML layout tương ứng.
- **Mô tả:** Lắng nghe sự thay đổi kích thước từ Launcher (`onAppWidgetOptionsChanged` qua `minWidthDp` và `minHeightDp`) để điều chỉnh nội dung hiển thị tương ứng.
- **Yêu cầu kỹ thuật:**
  1. **Thẻ 1 Ngày (2x2 kéo thành 4x2 hoặc 4x4):**
     - Khi `minWidthDp >= 220dp`: Bung rộng dòng thông tin `Giờ • Phòng • Giảng viên • Mã lớp`, không bị cắt cụt ba chấm.
     - Khi `minHeightDp >= 200dp`: Tự động unhide hiển thị thêm môn thứ 3, thứ 4 nếu có ca học.
  2. **Thẻ Lịch 3 Ngày (4x2 kéo thành 4x4):**
     - Khi `minHeightDp >= 200dp`: Cho phép hiển thị cả Môn 1 và Môn 2 chi tiết cho mỗi ngày (thay vì dồn môn vào `(+N môn nữa)`).
  3. **Thẻ Lịch Tuần (4x4 Grid 8 Ô):**
     - Khi widget được kéo rộng/cao: Tự động tối ưu số dòng tên môn học (`maxLines="2"`) và kích thước hiển thị để tận dụng tối đa diện tích tăng thêm.

### AC-03: Đồng Bộ Hiển Thị Giảng Viên Trên WidgetKit iOS
- **Tệp:** `ios/Runner/ScheduleWidgetKit.swift`
- **Mô tả:** Khi cờ `showTeacher` được bật (`show_teacher: true`), giao diện SwiftUI của Widget iOS phải in thông tin tên giảng viên vào danh sách ca học.
- **Yêu cầu kỹ thuật:**
  - Trong các View `.systemSmall`, `.systemMedium`, `.systemLarge`, khi `entry.showTeacher == true` (hoặc cấu hình payload) và `c.teacher.isNotEmpty`, hiển thị tên giảng viên nối tiếp thông tin giờ/phòng (`• \(c.teacher)`).

### AC-04: Cập Nhật Đồng Bộ Phiên Bản Tại GitHub Actions CI
- **Tệp:** `.github/workflows/dart.yml`
- **Mô tả:** Đồng bộ số phiên bản và tag phát hành iOS lên `v1.1.0`.
- **Yêu cầu kỹ thuật:**
  - Sửa dòng 88: `tag: v1.1.0`
  - Sửa dòng 90: `body: "IOS Update 1.1.0 - New update for ios"`

---

## 3. QUY TRÌNH THỰC HIỆN & KIỂM THỬ KHÉP KÍN (CLOSED-LOOP PROTOCOL)
1. **BA:** Trình Spec cho User phê duyệt.
2. **DEV (dev2):** Khi User duyệt, tự động lập trình đáp ứng 100% các tiêu chí từ AC-01 đến AC-04.
3. **TESTER (tester):** 
   - Kiểm thử tự động qua test suite.
   - **Bắt buộc đọc và đối soát trực tiếp từng dòng Code Diff** để phát hiện lỗi ngầm, xung đột layout hay vỡ giao diện. Nếu phát hiện lỗi, bắt DEV sửa lại đến khi PASS 100%.
   - Xuất biên bản kiểm thử `docs/specs/widget_enhancement-test-report.md`.
4. **BA:** Đối soát kiểm tra lại từ đầu toàn bộ mã nguồn DEV đã sửa xem có đúng, đủ và xung đột gì không trước khi xuất biên bản UAT Sign-off cho User.
