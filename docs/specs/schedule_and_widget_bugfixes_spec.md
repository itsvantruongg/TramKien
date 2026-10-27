# Đặc Tả Kỹ Thuật: Khôi Phục Directional Slide Transition & Bảo Vệ Tuyệt Đối Lịch Học (SPEC-SCHEDULE-WIDGET-05)

- **Trạng thái:** APPROVED (Đã duyệt)
- **Phiên bản:** 5.0.0
- **Ngày lập:** 26/10/2026
- **Mã dự án:** [HAU] (Flutter / Android)
- **Tác giả:** Senior BA / Master Orchestrator

---

## 1. MỤC TIÊU VÀ PHẠM VI
1. Khôi phục lại chính xác trải nghiệm animation **Trượt qua lại theo hướng bấm (Directional Slide + Fade Transition 220ms, Curves.easeOutCubic)** khi chuyển giữa 5 tab lớn ở viên thuốc đáy màn hình trong `main_shell.dart`.
2. Bảo vệ tuyệt đối màn hình Lịch học (`schedule_screen.dart`), ngăn chặn 100% hiện tượng xung đột ma trận ngang và lỗi rơi về năm 2018 bằng 2 chốt chặn: khóa cứng `keepPage: false` trên PageController và cố định danh sách màn hình trong State (`late final List<Widget> _screens`).
3. Duy trì toàn bộ hệ thống Skeleton Shimmer đã đồng bộ trên Dashboard, Lịch học, Tài chính và tính năng Android Native Widget.

---

## 2. DANH SÁCH ACCEPTANCE CRITERIA (TIÊU CHÍ NGHIỆM THU)

### AC-01: Khôi phục Animation Directional Slide + Fade 220ms (`lib/screens/main_shell.dart`)
- **Tệp:** `lib/screens/main_shell.dart`
- **Mô tả:** Chuyển qua lại giữa 5 tab lớn phải trượt ngang theo hướng tab được chọn kết hợp làm mờ êm, loại bỏ hoàn toàn animation nở (`ScaleTransition`).
- **Yêu cầu kỹ thuật:**
  - Khởi tạo controller: `AnimationController(vsync: this, duration: const Duration(milliseconds: 220), value: 1.0)`.
  - Khai báo biến hướng trượt: `double _slideDirection = 1.0;`.
  - Trong `_navigate(int idx, {DateTime? focusDate})`:
    * Tính hướng trượt: `_slideDirection = idx > _idx ? 1.0 : -1.0;`.
    * Cập nhật `setState(() => _idx = idx);`.
    * Chạy animation: `_animController.forward(from: 0.0);`.
  - Trong `build()`:
    * `slideAnimation`: `Tween<Offset>(begin: Offset(_slideDirection * 0.05, 0), end: Offset.zero).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic))`.
    * `fadeAnimation`: `Tween<double>(begin: 0.6, end: 1.0).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic))`.
    * `bodyContent`: `SlideTransition(position: slideAnimation, child: FadeTransition(opacity: fadeAnimation, child: IndexedStack(index: _idx, children: _screens)))`.
  - Cố định danh sách màn hình trong State (`late final List<Widget> _screens = [...]` hoặc persistent list) kèm `PageStorageKey` riêng biệt cho 5 tab: `page_dashboard`, `page_schedule`, `page_grades`, `page_finance`, `page_profile` để chống re-render per frame.
  - Bảo toàn `WidgetDataSyncService.getInitialTargetTab()` trong `initState()`.

### AC-02: Bảo Vệ Tuyệt Đối Màn Hình Lịch Học Khỏi Xung Đột Ngang (`lib/screens/schedule_screen.dart`)
- **Tệp:** `lib/screens/schedule_screen.dart`
- **Mô tả:** Đảm bảo khi `SlideTransition` ở ngoài chuyển cảnh, Lịch học bên trong không bao giờ bị gián đoạn hay rơi về năm 2018.
- **Yêu cầu kỹ thuật:**
  - Khóa cứng `keepPage: false` trên cả `_MonthViewState` và `_WeekViewState`:
    `_pageCtrl = PageController(initialPage: _currentPage, keepPage: false);`
  - Ngưỡng chặn cuộn an toàn: `if (page <= 0 && _currentPage > 12) return;`.
  - Chọn ngày tức thì 0ms qua `setState`, Container phẳng, không banner mẹo.

### AC-03: Duy Trì Đồng Bộ Skeleton Shimmer Toàn App
- **Tệp:** `lib/screens/dashboard_screen.dart`, `lib/screens/schedule_screen.dart`, `lib/screens/finance_screen.dart`, `lib/widgets/shared_widgets.dart`
- **Mô tả:** Duy trì toàn bộ hệ thống Skeleton Shimmer đã đồng bộ:
  - Dashboard: Bento Card GPA (80x12, 72x36, infinity x 6, 110x12) và Card Tín chỉ tròn (50x12, 80x80 tròn, 70x12) khi chưa có cache.
  - Lịch học: 2 thẻ ca học Shimmer `double.infinity x 88, radius 16` khi loading.
  - Tài chính: Hero Card Shimmer `double.infinity x 140` và 3 thẻ khoản thu Shimmer `double.infinity x 72` khi loading.
  - Skeleton Shimmer toàn cục quét liên tục với `Curves.easeInOut` không dead pause.

### AC-04: Bảo Toàn 100% Native Widget & Cấu Hình Đã Duyệt
- **Tệp:** `android/app/src/main/res/xml/widget_schedule_weekly_info.xml`, `android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt`, `lib/screens/widget_studio_screen.dart`
- **Mô tả:**
  - Widget 4x4 hiển thị ảnh preview `@drawable/widget_preview_weekly`.
  - Tên giảng viên hiển thị đầy đủ trên widget khi bật cờ `showTeacher`.
  - Widget Studio không còn nút `btn_add_to_home`, nút chính "ÁP DỤNG CẤU HÌNH VÀO WIDGET" kèm Swiss hint.

---

## 3. QUY TRÌNH THỰC HIỆN
1. **DEV (dev2):** Triển khai mã nguồn theo đúng AC-01 đến AC-04.
2. **TESTER (tester):** Kiểm thử tự động toàn diện, cập nhật test suites và xuất báo cáo `docs/specs/schedule_and_widget_bugfixes-test-report.md`.
3. **ORCHESTRATOR:** Nghiệm thu UAT Sign-off và báo cáo lại kết quả cho người dùng.

