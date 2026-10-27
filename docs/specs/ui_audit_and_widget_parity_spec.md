# Technical Specification: Toàn Diện UI Audit, Native Widget Parity (Android & iOS) & Tối Ưu Hóa Giao Diện Trạm Kiến

- **Mã tài liệu:** SPEC-UI-AUDIT-WIDGET-PARITY-01
- **Phân hệ:** Native Widget Integration (Android & iOS), Widget Studio, UI/UX Design System Refinements, Dead Code Cleanup
- **Tác giả:** Master Orchestrator & Senior Business Analyst
- **Đối chiếu chuẩn:** `codelabs/homescreen_codelab`, `home_widget`, `flutter-home-widget-vignette`, Swiss Typography & Apple HIG
- **Trạng thái:** Approved / Ready for Implementation

---

## 1. MỤC TIÊU & PHẠM VI DỰ ÁN

1. **Native iOS Parity 100%:**
   - Hoàn thiện cầu nối MethodChannel trên iOS (`AppDelegate.swift`), kích hoạt `WidgetCenter.shared.reloadAllTimelines()`.
   - Cấp quyền App Groups (`group.vn.edu.hau.tramkien`) trong `ios/Runner/Runner.entitlements`.
   - Nâng cấp `ios/Runner/ScheduleWidgetKit.swift` với Provider đọc dữ liệu thật từ `UserDefaults`, hỗ trợ đầy đủ 4 kích cỡ: `.systemSmall` (2x2), `.systemMedium` (4x2), `.systemLarge` (4x4 Weekly Grid 8 Ô), `.accessoryRectangular` (Lock Screen).
   - Xóa bỏ văn mẫu AI (`"TẬN HƯỞNG NGÀY NGHỈ"` $\rightarrow$ `"Không có ca học"`).

2. **Dọn dẹp Dead Code & Tinh chỉnh Widget Studio (`lib/screens/widget_studio_screen.dart`):**
   - Lược bỏ triệt để các hàm chết không được gọi: `_buildSingleDayContent`, `_buildSevenDaysContent`, `_buildSubVariantChip`.
   - Sửa lỗi responsive của ô ngày 4x4 Grid trong Studio: Loại bỏ `SizedBox(width: 165)` gán cứng trong `_buildGridDayCell` và `_buildGridSummaryCell`, dùng layout co giãn tự nhiên tương thích mọi kích thước màn hình.

3. **Chuẩn hóa Design System & Typography toàn bộ App:**
   - `lib/widgets/shared_widgets.dart`: Bổ sung viền hairline 0.5dp cho `SurfaceCard` (`AppTheme.outlineVariant.withOpacity(0.4)`).
   - `lib/screens/main_shell.dart`: Đồng bộ 100% tiếng Việt cho BottomNav: `Tổng quan`, `Lịch học`, `Điểm số`, `Học phí`, `Tài khoản`.
   - `lib/screens/finance_screen.dart`: Loại bỏ emoji `📄`, thay bằng `Icon(Icons.receipt_long_outlined, size: 14)`.
   - `lib/screens/login_screen.dart`: Đồng nhất tên thương hiệu thành `Trạm Kiến - HAU`.
   - `lib/screens/grades_screen.dart`: Dọn dẹp toàn bộ comment nháp và class mồ côi `_GpaHeroCard`.

---

## 2. TIÊU CHUẨN NGHIỆM THU (ACCEPTANCE CRITERIA - AC)

- [ ] **AC-01 (iOS App Group & Entitlements):** `ios/Runner/Runner.entitlements` chứa `com.apple.security.application-groups` với group `group.vn.edu.hau.tramkien`.
- [ ] **AC-02 (iOS AppDelegate MethodChannel & WidgetCenter):** `ios/Runner/AppDelegate.swift` thiết lập MethodChannel `com.tramkien.hau/widget`, xử lý phương thức `updateWidget` bằng cách gọi `WidgetCenter.shared.reloadAllTimelines()`.
- [ ] **AC-03 (iOS WidgetKit Native Implementation):** `ios/Runner/ScheduleWidgetKit.swift` hỗ trợ đọc JSON từ `UserDefaults(suiteName: "group.vn.edu.hau.tramkien")`, hỗ trợ các layout `.systemSmall`, `.systemMedium`, `.systemLarge` (vẽ lưới tuần 8 ô), `.accessoryRectangular`, loại bỏ câu filler AI.
- [ ] **AC-04 (Widget Studio Dead Code Elimination):** Không còn các hàm chết `_buildSingleDayContent`, `_buildSevenDaysContent`, `_buildSubVariantChip` trong `widget_studio_screen.dart`.
- [ ] **AC-05 (Responsive Grid Cells in Studio):** Ô ngày trong lưới 4x4 của `widget_studio_screen.dart` không còn `width: 165` gán cứng gây co giật font chữ.
- [ ] **AC-06 (BottomNav Localization Consistency):** 5 nhãn điều hướng của `MainShell` là 100% tiếng Việt: `Tổng quan`, `Lịch học`, `Điểm số`, `Học phí`, `Tài khoản`.
- [ ] **AC-07 (No UI Emojis & Swiss Minimalist):** Màn hình `finance_screen.dart` không chứa emoji `📄`, thay bằng Icon outlined.
- [ ] **AC-08 (Branding Consistency):** Màn hình `login_screen.dart` hiển thị đúng thương hiệu `Trạm Kiến - HAU`.
- [ ] **AC-09 (Clean Shared Widgets & Grades Screen):** `SurfaceCard` có viền hairline 0.5dp; `grades_screen.dart` không còn comment nháp và class thừa `_GpaHeroCard`.
- [ ] **AC-10 (Automated Tests 100% PASS):** Bộ test suite tự động kiểm thử toàn diện AC-01 đến AC-09 đạt 100% PASS, zero regressions.
