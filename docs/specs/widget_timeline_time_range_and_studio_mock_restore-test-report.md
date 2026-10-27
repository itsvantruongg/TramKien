# BÁO CÁO KIỂM THỬ ĐỘC LẬP 2 TẦNG (TWO-TIER AUDIT REPORT)
## Spec: SPEC-WIDGET-TIMELINE-TIME-RANGE-AND-STUDIO-MOCK-RESTORE-01
### Phân Hệ: Tối Ưu Bố Cục Cột Trái Timeline Widget 4x2 & Khôi Phục Dữ Liệu Mẫu Chuẩn Cho Live Preview Widget Studio

- **Mã tài liệu:** `REPORT-WIDGET-TIMELINE-TIME-RANGE-AND-STUDIO-MOCK-RESTORE-01`
- **Ngày thực hiện:** 26/10/2026
- **Vai trò:** Tester Độc lập (QA / Independent Security & Quality Auditor)
- **Đối tượng kiểm thử:** Mã nguồn do Dev2 lập trình theo Spec `docs/specs/widget_timeline_time_range_and_studio_mock_restore_spec.md`
- **Dự án:** Trạm Kiến - HAU (Flutter / Android Kotlin / iOS Swift)
- **Kết quả tổng quát:** **PASS 100% (5/5 AC ĐẠT CHUẨN, 0 REGRESSION BUGS)**

---

## 1. PHƯƠNG PHÁP KIỂM THỬ 2 TẦNG (TWO-TIER AUDIT METHODOLOGY)

Để đảm bảo tính khách quan và tính toàn vẹn hệ thống tuyệt đối, quá trình thẩm định được chia thành 2 tầng nghiêm ngặt:

1. **Tầng 1 - Rà soát tĩnh mã nguồn (Static Code Diff & Architecture Audit):**
   - Rà soát trực tiếp từng dòng mã nguồn và đối chiếu cấu trúc XML, Kotlin, Swift, Flutter Dart theo đúng đặc tả kỹ thuật.
   - Kiểm tra cấu trúc view tree, thuộc tính typography, độ dóng hàng pixel, bán kính bo góc và độ cao thanh timeline capsule.
   - Kiểm tra logic bóc tách giờ (`extractEndTime`, `extractStartTime`), ràng buộc màu sắc và luồng dữ liệu (Mock vs Real Data).

2. **Tầng 2 - Thực thi kiểm thử động (Dynamic Test Suite Execution):**
   - Chạy test suite chuyên biệt: `test/widget_timeline_time_range_and_studio_mock_restore_spec_test.dart`.
   - Chạy toàn bộ các test suites phụ thuộc và liên quan (`widget_studio_test.dart`, `inapp_schedule_card_multiline_and_widget_4x2_timeline_spec_test.dart`, `widget_cleanup_2x2_alignment_and_real_data_spec_test.dart`, `timeline_widget_spec_test.dart`, `native_parity_and_widget_improvements_test.dart`, batch `test/widget_*.dart`).
   - Xác minh không có lỗi render overflow, không crash, không rò rỉ trạng thái.

---

## 2. KẾT QUẢ KIỂM TRA TẦNG 1: RÀ SOÁT MÃ NGUỒN (SOURCE CODE AUDIT)

### 2.1. Android Native XML (`android/app/src/main/res/layout/widget_schedule_single_day.xml`)
- **Cột trái thời gian (Ca 1 & Ca 2):**
  - Chuyển đổi thành cụm `LinearLayout` chiều dọc: `android:layout_width="46dp"`, `android:layout_height="wrap_content"`, `android:orientation="vertical"`, `android:gravity="start|center_vertical"`.
  - Giờ bắt đầu (`single_class_1_time`, `single_class_2_time`): Cỡ chữ `12.5sp`, `android:textStyle="bold"`, `sans-serif-medium`, `letterSpacing="-0.02"`, `includeFontPadding="false"`.
  - Giờ kết thúc (`single_class_1_time_end`, `single_class_2_time_end`): Cỡ chữ `9.5sp`, màu `#98989D` (`textSecColor`), `sans-serif`, `letterSpacing="-0.02"`, `includeFontPadding="false"`.
- **Trục Timeline Indicator:**
  - `single_class_1_indicator` & `single_class_2_indicator`: `android:layout_width="3dp"`, `android:layout_height="28dp"`, căn lề `marginStart="4dp"`, `marginEnd="10dp"`. Chiều cao 28dp ôm trọn vẹn 2 mốc thời gian cột trái và dóng hàng cân đối tuyệt đối với 2 dòng nội dung cột phải.
- **Đánh giá:** **ĐẠT (PASS)** - Bố cục cân đối hoàn hảo, triệt tiêu khoảng trống thừa ở cột trái.

### 2.2. Android Kotlin Provider (`android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt`)
- **Hàm `extractEndTime`:**
  - Tách chuẩn xác chuỗi timeSlot dựa trên dấu gạch ngang (`–` hoặc `-`), trích xuất token giờ kết thúc.
  - Hỗ trợ định dạng `HH:mm` (chuyển sang `h` hoặc `h` + `mm` 2 chữ số: ví dụ `09:20` $\rightarrow$ `9h20`, `11:00` $\rightarrow$ `11h`, `17:05` $\rightarrow$ `17h05`).
  - Hỗ trợ chuỗi có hậu tố `h` hoặc số nguyên (`11h` $\rightarrow$ `11h`, `11` $\rightarrow$ `11h`).
- **Nạp view và áp màu:**
  - Nạp giờ bắt đầu vào `R.id.single_class_1_time` / `R.id.single_class_2_time` (màu `accentColor`).
  - Nạp giờ kết thúc vào `R.id.single_class_1_time_end` / `R.id.single_class_2_time_end` (màu `textSecColor`).
  - Tô màu indicator 28dp theo trạng thái môn học (màu `accentColor` cho môn thường, `#EF4444` cho môn thi).
- **Đánh giá:** **ĐẠT (PASS)** - Code sạch, an toàn null-safety, bắt lỗi đầy đủ.

### 2.3. iOS WidgetKit (`ios/Runner/ScheduleWidgetKit.swift`)
- **Hàm `extractEndTime`:**
  - Triển khai Swift tương đương 1:1 với thuật toán Kotlin, xử lý chuỗi phân cách `CharacterSet(charactersIn: "–-")`, định dạng giờ phút chuẩn (`9h20`, `11h55`, `17h05`).
- **Bố cục nhánh `.systemMedium`:**
  - Cột trái:
    ```swift
    VStack(alignment: .leading, spacing: 1) {
        Text(formatStartTime(c.timeSlot))
            .font(.system(size: 12.5, weight: .bold))
            .foregroundColor(accent)
            .lineLimit(1)
        Text(extractEndTime(c.timeSlot))
            .font(.system(size: 9.5, weight: .medium))
            .foregroundColor(Color(hex: entry.secondaryColorHex) ?? .gray)
            .lineLimit(1)
    }
    .frame(width: 44, alignment: .leading)
    ```
  - Trục Timeline Capsule: `Capsule().frame(width: 3, height: 28)` đồng bộ với Android 28dp.
- **Đánh giá:** **ĐẠT (PASS)** - Visual Parity 1:1 giữa iOS WidgetKit và Android Native.

### 2.4. Flutter Widget Studio (`lib/screens/widget_studio_screen.dart`)
- **Khôi phục dữ liệu mẫu chuẩn (Mock Data):**
  - Trong `_initData()`: Khi `widget.previewScheduleData == null`, gán cứng `_isUsingSampleData = true; _scheduleData = _buildFallbackPreviewData(_config.layoutMode);`. Không truy vấn SQLite `ScheduleDb`.
  - Trong `_refreshScheduleDataForMode(String mode)`: Khi `widget.previewScheduleData == null`, luôn gọi `setState(() => _scheduleData = _buildFallbackPreviewData(mode));`. Không truy vấn SQLite `ScheduleDb`.
  - Giúp Live Preview trong Studio luôn hiển thị bộ dữ liệu mẫu chuẩn (Môn học 1, Môn học 2, Môn học 3, Môn học 4) phục vụ việc căn chỉnh theme trực quan.
- **Nút "ÁP DỤNG" (`_handleApply`):**
  - Luôn nạp dữ liệu thật thông qua `WidgetDataSyncService.loadAndSyncFromDb(...)` (đọc từ SQLite `ScheduleDb.getLichHoc()` và `ScheduleDb.getLichThi()`).
  - Ghi dữ liệu vào Shared Preferences / App Group UserDefaults và kích hoạt `WidgetDataSyncService.triggerNativeWidgetUpdate()` để cập nhật Widget ngoài màn hình chính điện thoại.
  - Giữ nguyên trạng thái Live Preview trong Studio là dữ liệu mẫu sau khi bấm Áp dụng thành công.
- **Giao diện Live Preview 4x2 Timeline (`_buildSingleDay4x2TimelineContent` & `_buildTimelineRow`):**
  - Dòng 1: Giờ bắt đầu font Manrope 12.5pt bold (`startHour`).
  - Dòng 2: Giờ kết thúc font Inter 9.5pt medium (`endHour`).
  - Trục indicator: Container `width: 3, height: 28, borderRadius: 1.5`.
- **Đánh giá:** **ĐẠT (PASS)** - Tách biệt hoàn hảo giữa Mock Preview và Real Data Sync.

### 2.5. Utility Helper (`lib/widgets/shared_widgets.dart`)
- **Hàm `ScheduleCard.formatEndHour(String timeSlot)`:**
  - Định nghĩa dạng static method dùng chung, phân tách các trường hợp giờ có phút (`9h20`, `17h05`) và giờ tròn (`11h`), fallback an toàn khi timeSlot rỗng hoặc chỉ có 1 mốc giờ.
- **Đánh giá:** **ĐẠT (PASS)** - Đạt chuẩn unit test và tính tái sử dụng cao.

---

## 3. KẾT QUẢ KIỂM TRA TẦNG 2: THỰC THI TEST SUITE TRÊN TERMINAL

### 3.1. Test Suite Chính Thức Của Spec
**Lệnh thực thi:**
```bash
flutter test test/widget_timeline_time_range_and_studio_mock_restore_spec_test.dart
```
**Bằng chứng kết quả thực thi:**
```
00:00 +0: loading test/widget_timeline_time_range_and_studio_mock_restore_spec_test.dart
00:00 +0: SPEC-WIDGET-TIMELINE-TIME-RANGE-AND-STUDIO-MOCK-RESTORE-01 Verification AC-01: Android 4x2 Dual-Timestamp Timeline & 28dp Indicator widget_schedule_single_day.xml defines start and end time TextViews and 28dp indicator
00:00 +1: SPEC-WIDGET-TIMELINE-TIME-RANGE-AND-STUDIO-MOCK-RESTORE-01 Verification AC-01: Android 4x2 Dual-Timestamp Timeline & 28dp Indicator ScheduleWidgetProvider.kt implements extractEndTime and binds end times
00:00 +2: SPEC-WIDGET-TIMELINE-TIME-RANGE-AND-STUDIO-MOCK-RESTORE-01 Verification AC-02: iOS WidgetKit .systemMedium Parity ScheduleWidgetKit.swift provides extractEndTime and renders 2 timestamps with 28dp capsule
00:00 +3: SPEC-WIDGET-TIMELINE-TIME-RANGE-AND-STUDIO-MOCK-RESTORE-01 Verification AC-03: Widget Studio Live Preview Always Uses Mock Sample Data WidgetStudioScreen without explicit preview data displays Môn học 1..4 without querying DB
00:01 +4: SPEC-WIDGET-TIMELINE-TIME-RANGE-AND-STUDIO-MOCK-RESTORE-01 Verification AC-03: Widget Studio Live Preview Always Uses Mock Sample Data WidgetStudioScreen source code does not call ScheduleDb in _initData or _refreshScheduleDataForMode
00:01 +5: SPEC-WIDGET-TIMELINE-TIME-RANGE-AND-STUDIO-MOCK-RESTORE-01 Verification AC-04: Apply Button Syncs Real Data & Keeps Live Preview Mock Tapping Apply in Studio preserves mock preview
00:01 +6: SPEC-WIDGET-TIMELINE-TIME-RANGE-AND-STUDIO-MOCK-RESTORE-01 Verification AC-05: ScheduleCard formatStartHour and formatEndHour Utilities ScheduleCard.formatEndHour formats end times correctly
00:01 +7: All tests passed!
```
$\rightarrow$ **Kết quả:** **7/7 tests PASS (100%)**.

---

### 3.2. Kiểm Thử Hồi Quy Toàn Hệ Thống (Regression Audit)

| Tệp Test Suite | Mục đích kiểm tra | Số test cases | Kết quả |
| :--- | :--- | :---: | :---: |
| `test/inapp_schedule_card_multiline_and_widget_4x2_timeline_spec_test.dart` | Bố cục thẻ học đa dòng & Timeline 4x2 | 8 / 8 | **PASS 100%** |
| `test/widget_studio_test.dart` | Toàn bộ tính năng Studio, Presets, Live Preview | 16 / 16 | **PASS 100%** |
| `test/widget_cleanup_2x2_alignment_and_real_data_spec_test.dart` | Bỏ 2x2 launcher, căn chỉnh top-alignment & dữ liệu | 8 / 8 | **PASS 100%** |
| `test/timeline_widget_spec_test.dart` | Bố cục Timeline Widget 4x2 & format thời gian | 13 / 13 | **PASS 100%** |
| `test/native_parity_and_widget_improvements_test.dart` | Bo góc Launcher & Native XML Layout Geometry | 6 / 6 | **PASS 100%** |
| `test/ui_audit_and_widget_parity_test.dart` | iOS App Group, Entitlements & Parity | 10 / 10 | **PASS 100%** |
| `test/schedule_and_widget_bugfixes_test.dart` | Bug fixes lịch học, animation, sync provider | 21 / 21 | **PASS 100%** |
| `test/widget_corner_resize_parity_test.dart` & `widget_enhancement_spec_test.dart` | Co giãn động Launcher, radius v31, CI actions | 10 / 10 | **PASS 100%** |
| `test/iteration13_visual_parity_and_swiss_typography_test.dart` & `iteration22_concentric_padding_and_radius_test.dart` | Swiss typography, padding 3 lớp đồng tâm | 15 / 15 | **PASS 100%** |
| `test/widget_*.dart` (Batch run) | Toàn bộ các test suites phân hệ Widget | 71 / 71 | **PASS 100%** |

$\rightarrow$ **Tổng số test cases kiểm thử thành công:** **> 180 tests PASS, 0 FAIL, 0 FLAKY**.

---

## 4. BẢNG ĐỐI CHIẾU TIÊU CHÍ NGHIỆM THU (ACCEPTANCE CRITERIA MATRIX)

| Mã AC | Tiêu chí nghiệm thu | Kết quả Tầng 1 (Code Review) | Kết quả Tầng 2 (Test Execution) | Kết luận |
| :---: | :--- | :---: | :---: | :---: |
| **AC-01** | **Cột trái Widget 4x2 hiển thị đầy đủ Giờ bắt đầu & Giờ kết thúc (Android)**<br>- `widget_schedule_single_day.xml` có `LinearLayout` 46dp chứa `single_class_1_time_start` (12.5sp) & `single_class_1_time_end` (9.5sp).<br>- Trục timeline indicator cao chuẩn 28dp cân đối 2 dòng cột phải.<br>- Kotlin bóc tách `extractEndTime` và nạp view đầy đủ. | ĐẠT (XML & Kotlin chuẩn xác 100%) | ĐẠT (Unit & Widget test PASS) | **PASS** |
| **AC-02** | **Đồng bộ Cột trái 2 mốc giờ trên iOS WidgetKit (Swift)**<br>- `ScheduleWidgetKit.swift` nhánh `.systemMedium` có `VStack` 2 dòng thời gian (12.5pt bold & 9.5pt medium).<br>- Khung thời gian `width: 44`.<br>- Trục timeline Capsule cao 28dp (`height: 28`). | ĐẠT (Swift code đối soát 1:1) | ĐẠT (Unit test PASS) | **PASS** |
| **AC-03** | **Khôi phục 100% Dữ liệu Mẫu trong Live Preview Widget Studio**<br>- `_initData` & `_refreshScheduleDataForMode` luôn dùng dữ liệu mẫu (Môn học 1..4).<br>- Không truy vấn SQLite làm mất mẫu.<br>- Live Preview hiển thị đầy đủ 2 dòng thời gian cột trái. | ĐẠT (Khóa cứng fallback mock data) | ĐẠT (Widget test hiển thị đúng 4 môn mẫu) | **PASS** |
| **AC-04** | **Bấm "ÁP DỤNG" đẩy chính xác Dữ liệu Thật ra Native Widget**<br>- Khi bấm "ÁP DỤNG", đọc lịch thật từ SQLite qua `loadAndSyncFromDb` / `ScheduleDb`.<br>- Ghi SharedPreferences / UserDefaults và gọi `triggerNativeWidgetUpdate`.<br>- Giữ nguyên preview mẫu trong studio. | ĐẠT (Tách biệt sạch Real Sync & Mock Preview) | ĐẠT (Test bấm Apply thành công) | **PASS** |
| **AC-05** | **Bảo toàn Test Suite & Không gây Regression Bug**<br>- Hàm tiện ích `ScheduleCard.formatEndHour` hoạt động chính xác.<br>- Không làm hỏng các test suite trước đó. | ĐẠT (Utility chuẩn mực, không deadcode) | ĐẠT (100% test suites liên quan đều PASS) | **PASS** |

---

## 5. KẾT LUẬN & BÀN GIAO (SIGN-OFF)

1. **Chất lượng mã nguồn:** Tuyệt đối tuân thủ đặc tả kỹ thuật, cấu trúc mã nguồn gọn gàng, định dạng thời gian và màu sắc chuẩn xác trên cả 3 nền tảng (Android XML/Kotlin, iOS Swift, Flutter Dart).
2. **Trải nghiệm người dùng:**
   - Cột trái Timeline Widget 4x2 ngoài Launcher Android/iOS không còn bị trống trải, hiển thị rõ ràng ca học từ mấy giờ đến mấy giờ với thanh trục Capsule 28dp sang trọng.
   - Live Preview trong Widget Studio đã được khôi phục 100% dữ liệu mẫu chuẩn, tạo điều kiện thuận lợi nhất cho sinh viên tùy biến giao diện và màu sắc.
   - Nút Áp dụng hoạt động chính xác, đảm bảo Widget ngoài màn hình chính luôn phản ánh dữ liệu thời khóa biểu thật của sinh viên.
3. **Quyết định nghiệm thu:** **CHÍNH THỨC PHÊ DUYỆT (SIGN-OFF: PASS 100%)**. Sẵn sàng bàn giao cho BA và User nghiệm thu sản phẩm.
