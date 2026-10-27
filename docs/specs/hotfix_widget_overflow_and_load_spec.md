# SPEC-HOTFIX-WIDGET-OVERFLOW-AND-LOAD-01: KHẮC PHỤC TRIỆT ĐỂ LỖI NẠP WIDGET, OVERFLOW UI, BOTTOM BAR VÀ TỐI ƯU HIỆU NĂNG TAB/SHIMMER

## 1. TỔNG QUAN & BỐI CẢNH
- **Mã đặc tả:** `SPEC-HOTFIX-WIDGET-OVERFLOW-AND-LOAD-01`
- **Mục tiêu:** Khắc phục dứt điểm 4 lỗi kỹ thuật nghiêm trọng được phát hiện từ kiểm thử thực tế trên thiết bị Samsung:
  1. Lỗi Widget ngoài Màn hình chính báo "Sự cố khi tải tiện ích con" (Problem loading widget).
  2. Lỗi RenderFlex Overflow (sọc vàng đen) trong Live Preview của Xưởng Widget (`WidgetStudioScreen`).
  3. Lỗi tràn đáy 4.1px ở thanh Bottom Navigation Bar và Floating SnackBar bị đẩy ra ngoài màn hình (`main_shell.dart`).
  4. Lỗi giật lag khi chuyển các tab chính do `AnimatedSwitcher` hủy/dựng lại view liên tục và Shimmer sinh rác bộ nhớ gây GC pause 100-200ms.
- **Tiêu chuẩn đối chiếu:** Google Codelabs (`animations`, `animated-responsive-layout`), Flutter Cookbook (Shimmer ShaderMask), Android AppWidget Guidelines (Samsung One UI Parity).

---

## 2. TIÊU CHÍ NGHIỆM THU CHI TIẾT (ACCEPTANCE CRITERIA)

### AC-01: Triệt Tiêu 100% Lỗi "Sự Cố Khi Tải Tiện Ích Con" Trên Android & Samsung One UI
- **Tập tin can thiệp:** 
  - `android/app/src/main/res/xml/widget_schedule_*_info.xml` (tất cả các file info widget)
  - `android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt`
- **Yêu cầu kỹ thuật:**
  1. **Metadata XML:** Gỡ bỏ cờ `android:widgetFeatures="reconfigurable|configuration_optional"` khỏi tất cả các file `widget_schedule_*_info.xml`. Việc cấu hình widget được quản lý tập trung 100% bên trong App (`WidgetStudioScreen`) như các ứng dụng quốc tế (Notion, Spotify). Điều này loại bỏ hoàn toàn lỗi tìm kiếm Activity cấu hình null trên Launcher Samsung One UI.
  2. **Safe RemoteViews Rendering:**
     - Trong `ScheduleWidgetProvider.kt`, loại bỏ mọi lệnh gọi trực tiếp đến `android.R.id.background` hoặc bọc trong khối try-catch an toàn. Chỉ áp dụng background/drawable lên `R.id.widget_root` hoặc view container nội bộ của app.
     - Bọc toàn bộ logic trong `buildRemoteViews` bằng khối `try { ... } catch (e: Throwable) { ... }`. Nếu có bất kỳ ngoại lệ nào phát sinh, trả về RemoteViews fallback an toàn (hiển thị thông báo lịch học cơ bản) thay vì để văng ngoại lệ ra ngoài làm hỏng Binder IPC.
  3. **Preview Image:** Đổi `android:previewImage` trong các file info sang `@mipmap/ic_launcher` hoặc drawable an toàn để các launcher Android cũ/trung cấp không bị crash khi nạp vector drawable phức tạp.

### AC-02: Triệt Tiêu 100% Lỗi RenderFlex Overflow Trong Live Preview Studio
- **Tập tin can thiệp:** `lib/screens/widget_studio_screen.dart`
- **Yêu cầu kỹ thuật:**
  1. **Kích thước khung Live Preview:**
     - Nâng chiều cao `previewHeight` cho Lưới tuần (`seven_days` grid) từ `350` lên `400` để các ô lịch có đủ không gian hiển thị tự nhiên.
     - Nâng chiều cao khung thẻ 2x2 (`is2x2`) từ `220` lên `240` (chiều cao card simulated 170 thay vì 160).
  2. **Chống tràn cấp độ Widget Card:**
     - Bọc `_buildSimulatedWidgetCard()` hoặc khối hiển thị card bằng `FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.topCenter)` để nếu màn hình điện thoại người dùng có độ phân giải hẹp hoặc font chữ to, toàn bộ card sẽ tự động scale nhẹ nhàng, triệt tiêu 100% sọc vàng đen `RenderFlex overflowed`.
  3. **Tối ưu hiển thị ô lưới 8 ô (`_buildGridDayCell`):**
     - Đảm bảo các `Column` có `mainAxisSize: MainAxisSize.min`.
     - Với các ô có 2 môn: nếu tổng chiều cao có nguy cơ tràn, hiển thị tên môn 1 + giờ/phòng, và môn 2 chỉ hiển thị tên môn (hoặc thu gọn giờ phòng thành định dạng ngắn), dòng phụ `(+... môn nữa)` dùng cỡ chữ 8sp gọn gàng.

### AC-03: Triệt Tiêu Tràn Đáy 4.1px Ở Bottom Bar & Khắc Phục SnackBar Off-Screen
- **Tập tin can thiệp:** `lib/screens/main_shell.dart`
- **Yêu cầu kỹ thuật:**
  1. **Nâng chiều cao Bottom Navigation Bar:**
     - Tăng chiều cao vùng hiển thị item từ `52` lên `58` (hoặc `60` dp theo chuẩn Material Design 3).
  2. **Chống tràn chữ khi Font Scale tăng:**
     - Trong `_navItem`: TextStyle của label phải có `height: 1.0`.
     - Bọc `Text` nhãn trong `FittedBox(fit: BoxFit.scaleDown, child: Text(...))` để khi người dùng bật cỡ chữ 1.1x – 1.3x trên Samsung, chữ tự thu nhỏ nhẹ mà không đội chiều cao làm tràn 4.1px.
  3. **Khắc phục SnackBar Off-Screen:**
     - Chuẩn hóa vị trí Bottom Navigation Bar trong Scaffold (không dùng bọc `Align(bottomCenter)` cưỡng bức làm sai lệch neo đáy của Scaffold). SnackBar nổi (Floating SnackBar) phải xuất hiện ngay trên thanh điều hướng một cách tự nhiên.

### AC-04: Tối Ưu Chuyển Tab Chính $0\text{ms}$ Không Giật Lag (Chuẩn Google Codelabs)
- **Tập tin can thiệp:** `lib/screens/main_shell.dart`
- **Yêu cầu kỹ thuật:**
  1. **Sử dụng `IndexedStack` giữ trạng thái:**
     - Thay thế `AnimatedSwitcher` (vốn hủy và khởi tạo lại toàn bộ màn hình mỗi lần đổi tab) bằng `IndexedStack(index: _selectedIndex, children: _screens)`.
     - Giữ nguyên trạng thái (KeepAlive) của 4 màn hình chính: Trang chủ (Dashboard), Lịch học (Schedule), Điểm số (Grades), Học phí (Finance).
  2. **Trải nghiệm tức thì:**
     - Bấm chuyển tab phản hồi ngay lập tức trong $0\text{ms}$, 60/120fps mượt mà, không load lại SQLite, không re-render cây widget nặng.

### AC-05: Tối Ưu Hiệu Năng Skeleton Shimmer (Chống Rác Bộ Nhớ & Dập Tắt GC Pause)
- **Tập tin can thiệp:** `lib/widgets/shared_widgets.dart`
- **Yêu cầu kỹ thuật:**
  1. Tái cấu trúc cơ chế Shimmer theo Flutter Cookbook:
     - Giảm thiểu việc cấp phát bộ nhớ mới trong từng frame của `SkeletonBox`.
     - Sử dụng `ColorFiltered` hoặc gradient tái sử dụng, không `new LinearGradient` liên tục mỗi 16ms trong từng ô con.
     - Đảm bảo khi skeleton chạy, RAM ổn định, không kích hoạt Garbage Collector của Android chạy dồn dập (GC freed ... paused 100ms).

### AC-06: Kiểm Thử Độc Lập 100% & Zero Regressions
- **Tập tin kiểm thử:** `test/hotfix_widget_overflow_and_load_test.dart`
- **Yêu cầu:**
  1. Kiểm thử kích thước và tính chống tràn của Live Preview trong `WidgetStudioScreen`.
  2. Kiểm thử chống tràn của Bottom Navigation Bar với Font Scale lớn (1.2x).
  3. Kiểm thử cơ chế `IndexedStack` duy trì trạng thái các màn hình trong `MainShell`.
  4. Toàn bộ `flutter test` đạt 100% PASS (>= 253 tests), `flutter analyze` 0 errors.

---

## 3. PHÂN CÔNG THỰC HIỆN
- **DEV2:** Lập trình theo các tiêu chí AC-01 đến AC-05.
- **TESTER:** Kiểm thử độc lập 2 tầng (Code Diff Audit + Automated Verification) theo AC-01 đến AC-06 và xuất báo cáo `docs/specs/hotfix_widget_overflow_and_load-test-report.md`.
- **BA:** Trực tiếp đối soát code diffs và ký duyệt nghiệm thu UAT Sign-off.
