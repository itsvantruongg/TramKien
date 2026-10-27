# Đặc Tả Kỹ Thuật: Chuẩn Hóa Thẻ Lịch Học Trong App & Timeline 4x2 Android Widget (SPEC-TIMELINE-WIDGET-02)

- **Trạng thái:** APPROVED (Người dùng đã duyệt)
- **Phiên bản:** 2.1.0
- **Ngày lập:** 26/10/2026
- **Mã dự án:** [HAU] (Flutter / Android)
- **Tác giả:** Senior BA / Master Orchestrator

---

## 1. MỤC TIÊU VÀ PHẠM VI
1. **Thẻ Lịch Học Trong App (Dashboard & Màn hình Lịch):**
   - Trả `ScheduleCard` về dạng Card độc lập nguyên bản (bỏ cột giờ `7h` bên trái trong app).
   - **Luôn hiển thị Mã lớp học phần (`tenLopTinChi`, ví dụ `TH4327_23CN 2`)** trên hàng thông tin phụ trợ giống hệt Phòng học và Tên giảng viên (khi môn có mã lớp thì luôn hiện, không cần qua switch).
   - Giới hạn danh sách lịch hôm nay & ngày mai trên Dashboard hiển thị **tối đa đúng 2 ca học** (`take(2)`), nếu có từ 3 ca trở lên thì hiện nút link `(+N ca học khác • Xem tất cả)`.
2. **Widget Ngoài Màn Hình Chính (Android Launcher):**
   - **Widget 4x2 Lịch hôm nay (`widget_schedule_single_day.xml`):** Bố cục Timeline 2 cột chuẩn: Cột trái duy nhất giờ bắt đầu (`7h`, `12h45`); Cột phải gồm đúng 2 dòng (Dòng 1: Tên môn, Dòng 2: Hàng phụ trợ gom trên đúng 1 hàng duy nhất).
   - **Widget 2x2 khi kéo dãn sang 3x2 hoặc 4x2 (`widget_schedule_single_day_2x2.xml`):** Khóa cứng `maxLines="1"`, nội dung luôn chỉ chiếm **đúng 2 dòng** (1 dòng tên môn to rõ và 1 dòng nhỏ thông tin bên dưới), tuyệt đối không để bung thành 2 hàng thông tin.

---

## 2. DANH SÁCH ACCEPTANCE CRITERIA (TIÊU CHÍ NGHIỆM THU)

### AC-01: Khôi Phục Thẻ Lịch Học Trong App & Luôn Hiển Thị Mã Lớp Học Phần
- **Tệp:** `lib/widgets/shared_widgets.dart`, `lib/screens/dashboard_screen.dart`, `lib/screens/schedule_screen.dart`
- **Mô tả:** Trong app, thẻ lịch học là Card bo góc hoàn chỉnh, không chia cột giờ bên trái; mã lớp học phần luôn được hiển thị trên hàng thông tin phụ trợ như phòng học và giáo viên.
- **Yêu cầu kỹ thuật:**
  - `ScheduleCard` trên Dashboard:
    * Bỏ cột `SizedBox(width: 48, ...)` bên trái.
    * Trở về cấu trúc SurfaceCard nguyên bản: Header có StatusChip `LỊCH HỌC` và giờ học đầy đủ `lichHoc.gioHocFull` ở góc phải; tiếp theo là Tên môn học to rõ; bên dưới là hàng thông tin phụ trợ.
    * Hàng thông tin phụ trợ: Hiển thị Phòng học, Tiết học, Giảng viên và **luôn hiển thị `_InfoChip(Icons.tag, lichHoc.tenLopTinChi)` khi `lichHoc.tenLopTinChi.isNotEmpty`**.
  - `_ScheduleCardFull` trên Màn hình Lịch:
    * Luôn hiển thị chip `_Chip(Icons.tag, lichHoc.tenLopTinChi)` khi `lichHoc.tenLopTinChi.isNotEmpty`.
  - Dashboard: Giới hạn danh sách hôm nay/ngày mai `list.take(2)`. Nếu `list.length > 2`, hiển thị dòng link `(+N ca học khác • Xem tất cả)` dẫn về Tab Lịch học.

### AC-02: Bố Cục Timeline 4x2 Cho Android Widget (`SingleDayScheduleWidgetProvider`)
- **Tệp:** `android/app/src/main/res/layout/widget_schedule_single_day.xml`, `android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt`
- **Mô tả:** Widget 4x2 Lịch hôm nay trên Android Launcher hiển thị bố cục Timeline 2 cột tối giản.
- **Yêu cầu kỹ thuật:**
  - Cột trái: Duy nhất giờ bắt đầu (`7h`, `12h45`, v.v. từ `formatStartTime()`), không giờ kết thúc, không đường kẻ dọc.
  - Cột phải: Mỗi ca học gồm đúng 2 dòng:
    * Dòng 1: Tên môn học to rõ (`maxLines="1"`, ellipsis).
    * Dòng 2: Hàng thông tin phụ trợ gom trên **đúng 1 hàng ngang duy nhất**: `Phòng • Giảng viên • Mã lớp`.
  - Giới hạn tối đa 2 ca học. Nếu ngày có $\ge 3$ ca học: Hiển thị badge `(+N môn nữa)`.

### AC-03: Thẻ 2x2 Kéo Dãn (2x2 -> 3x2 -> 4x2) Chuẩn Đúng 2 Dòng Duy Nhất
- **Tệp:** `android/app/src/main/res/layout/widget_schedule_single_day_2x2.xml`, `android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt`
- **Mô tả:** Khi người dùng kéo dãn thẻ 2x2 sang ngang (3x2, 4x2), nội dung môn học vẫn chỉ chiếm đúng 2 dòng: 1 dòng tên môn và 1 dòng nhỏ thông tin bên dưới (không bị bung thành 2 hàng thông tin).
- **Yêu cầu kỹ thuật:**
  - Khóa cứng `single_2x2_class_1_hybrid` và `single_2x2_class_2_hybrid` với `maxLines="1"`, ellipsis.
  - Bỏ lệnh `setMaxLines(2)` khi kéo rộng sang ngang.
  - Thông tin phụ trợ luôn nằm gọn trên **đúng 1 hàng ngang nhỏ duy nhất** dưới tên môn.

### AC-04: Bảo Toàn Tính Năng & Zero Regressions
- **Tệp:** Toàn bộ test suites
- **Mô tả:** Chạy toàn bộ test suites đảm bảo 100% tests PASS, không phát sinh lỗi layout hay biên dịch.

---

## 3. QUY TRÌNH THỰC HIỆN & KIỂM THỬ KHÉP KÍN (CLOSED-LOOP PROTOCOL)
1. **BA:** Trình Spec cho User phê duyệt.
2. **DEV (dev2):** Khi User duyệt, tự động lập trình đáp ứng 100% các tiêu chí từ AC-01 đến AC-05.
3. **TESTER (tester):** 
   - Kiểm thử tự động qua test suite.
   - **Bắt buộc đọc và đối soát trực tiếp từng dòng Code Diff** trong Git để kiểm tra layout RemoteViews và UI trong app.
   - Xuất biên bản kiểm thử `docs/specs/timeline_widget_v2-test-report.md`.
4. **BA:** Đối soát kiểm tra lại từ đầu toàn bộ mã nguồn DEV đã sửa xem có đúng, đủ và xung đột gì không trước khi xuất biên bản UAT Sign-off cho User.
