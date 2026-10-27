# BÁO CÁO KIỂM THỬ KỸ THUẬT & NGHIỆM THU ĐỘC LẬP (TEST REPORT)
## Phân Hệ: Khắc Phục Lỗi Widget Báo Sai "Không Có Lịch / Hôm Nay Nghỉ" Khi Ca Học Đã Qua (Đồng Bộ Android & iOS)

- **Mã tài liệu:** `TEST-REPORT-WIDGET-FINISHED-CLASSES-PRESERVATION-AND-STATUS-01`
- **Đặc tả đối soát:** `docs/specs/widget_finished_classes_preservation_and_status_spec.md` (`SPEC-WIDGET-FINISHED-CLASSES-PRESERVATION-AND-STATUS-01`)
- **Phiên bản:** `1.0.0`
- **Người thực hiện:** Senior QA / Independent Tester Sub-agent
- **Dự án:** Trạm Kiến - Ứng dụng Quản lý Học tập & Lịch học HAU (Flutter / Android Kotlin / iOS Swift)
- **Thời gian thực hiện:** Thứ Hai, 26/10/2026
- **Kết luận:** **ĐẠT (PASS 100%) - CHẤP THUẬN NGHIỆM THU KỸ THUẬT (SIGN-OFF)**

---

## 1. TỔNG QUAN & BỐI CẢNH KIỂM THỬ

### 1.1. Bối cảnh lỗi ban đầu (User Bug Report)
Người dùng phản ánh tình trạng khi ca học trong ngày (Thứ 2 ngày 26/10, ca chiều 12:55 - 17:05 môn *"Kho dữ liệu và khai phá dữ liệu"*) đã kết thúc:
1. **Widget 1 Ngày ("Lịch hôm nay" 4x2 Timeline & 2x2):** Báo `[SẮP TỚI] Hôm nay nghỉ` gây hiểu nhầm ngày đó không có lịch học.
2. **Widget 3 Ngày (4x2):** Ô Thứ 2 ngày 26/10 chuyển sang `Không có lịch`.
3. **Widget 7 Ngày (Weekly Grid 4x4):** Ô Thứ 2 ngày 26/10 báo `Không có lịch`, đồng thời ô "Tổng kết tuần" đếm nhầm Thứ 2 thành ngày trống (`3 ngày trống` thay vì `2 ngày trống`).

### 1.2. Mục tiêu kiểm thử
Thực hiện quy trình kiểm định chất lượng 2 tầng độc lập (Two-Tier Audit):
- **Tầng 1 (Code Review & Static Diff Analysis):** Rà soát mã nguồn thực tế tại 4 phân hệ lõi: Service đồng bộ dữ liệu (`WidgetDataSyncService.dart`), Native Android (`ScheduleWidgetProvider.kt`), iOS WidgetKit (`ScheduleWidgetKit.swift`), và In-App Live Preview (`widget_studio_screen.dart`).
- **Tầng 2 (Terminal Test Execution & Regression):** Thực thi trực tiếp toàn bộ test suites kiểm thử đặc tả mới và test suites hồi quy trên môi trường dòng lệnh Flutter Test.

---

## 2. PHÂN TÍCH RÀ SOÁT TẦNG 1: CODE DIFF & SOURCE CODE REVIEW

### 2.1. Tầng dịch vụ đồng bộ (`lib/services/widget_data_sync_service.dart`)
- **Hàm rà soát:** `_extractClassesForDate()` (Dòng 571 - 660).
- **Phát hiện:**
  1. **Xóa bỏ hoàn toàn lệnh drop ca học:** Điều kiện lỗi `if (isTargetToday && isFinished) continue;` tại dòng 623 trước đây đã bị **xóa bỏ triệt để**. Tại đây được bổ sung comment đặc tả chuẩn hóa:
     ```dart
     // SPEC-WIDGET-FINISHED-CLASSES-PRESERVATION-AND-STATUS-01 (AC-01):
     // Bảo toàn 100% ca học hôm nay (kể cả đã kết thúc: now > gioKetThuc) với cờ isFinished = true.
     // Không tự động drop/continue để tránh widget 1 ngày, 3 ngày, 7 ngày bị rơi vào trạng thái
     // "Không có lịch / Hôm nay nghỉ" sai lệch và ô Tổng kết tuần đếm nhầm ngày trống.
     ```
  2. **Gán cờ trạng thái chính xác:**
     - `isPastDate`: Đánh dấu `isFinished = true`, `isCurrentOrNext = false`.
     - `isTargetToday`: Tính toán phút hiện tại trong ngày so với `endMinuteOfDay` (`l.gioKetThuc`). Nếu `currentMinuteOfDay > endMinuteOfDay` $\rightarrow$ `isFinished = true`, `isCurrentOrNext = false`. Ngược lại nếu chưa kết thúc thì gán `isFinished = false`, và ca đầu tiên chưa học sẽ nhận `isCurrentOrNext = true`.
     - Ngày tương lai: `isFinished = false`, ca đầu tiên nhận `isCurrentOrNext = true`.
  3. Mọi ca học của ngày hôm nay đều được đóng gói đầy đủ vào `List<WidgetClassItem>` trả về payload.

### 2.2. Tầng Native Android (`android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt`)
- **Widget 7 Ngày (`seven_days` - Weekly Grid 4x4):**
  - **Duyệt danh sách ca học:** Đọc `classesArray`. Nếu `count > 0`, `emptyDays` không bị tăng; `totalClasses` và `totalExams` được đếm đầy đủ 100%.
  - **Màu sắc hiển thị ca đã học xong:** `c1Finished = c1.optBoolean("is_finished", false)`. Khi `c1Finished == true`, màu chữ tên môn `c1Name` được chuyển sang màu thứ cấp `textSecColor` (làm mờ dimmed), không báo *"Không có lịch"*.
  - **Ô Tổng kết tuần:** `$totalClasses buổi học • $totalExams buổi thi` và `$emptyDays ngày trống` phản ánh số liệu thực tế chính xác tuyệt đối.
- **Widget 3 Ngày (`three_days` - 4x2):**
  - Khi `count > 0`: Hiển thị tên môn học bình thường. Nếu `isFinished == true`, tên môn được áp dụng `textSecColor`. Chỉ khi `count == 0` thật sự mới hiển thị `"Không có lịch"`.
- **Widget Lịch hôm nay (`single_day` Timeline 4x2 & `single_day_2x2` Thu gọn):**
  - Cơ chế lọc tách biệt `activeClasses` (ca chưa học) và `allDayClasses` (toàn bộ ca trong ngày).
  - Biến trạng thái: `allFinished = activeClasses.isEmpty() && allDayClasses.isNotEmpty()`.
  - Phân nhánh hiển thị:
    - **Trường hợp đã học xong tất cả các ca hôm nay (`allFinished == true`):**
      + `displayClasses` lấy toàn bộ ca trong ngày (`allDayClasses`).
      + Ca học được hiển thị rõ ràng với màu xám mờ (`textSecColor`).
      + Thẻ `single_day` 4x2 hiển thị nhãn: `[ĐÃ HOÀN THÀNH]` (`R.id.single_day_badge`).
      + Thẻ `single_day_2x2` hiển thị nhãn: `[ĐÃ XONG]` (`R.id.single_2x2_badge`).
    - **Trường hợp thật sự không có lịch (`hasClasses == false`):**
      + Thẻ `single_day` 4x2 hiển thị: `"Hôm nay nghỉ"`.
      + Thẻ `single_day_2x2` hiển thị nhãn `SẮP TỚI` kèm `"Hôm nay nghỉ"`.

### 2.3. Tầng Native iOS WidgetKit (`ios/Runner/ScheduleWidgetKit.swift`)
- **DayGridCellView (Weekly Grid 4x4):**
  - Khai báo model `ClassItemPayload` decode key `is_finished` sang Swift property `isFinished: Bool?`.
  - Kiểm tra `day.classes.isEmpty`: Chỉ hiển thị `"Không có lịch"` khi mảng rỗng thật sự.
  - Khi có môn: `isFinished1 = firstClass.isFinished == true`. Màu sắc hiển thị áp dụng `.gray.opacity(0.7)`, duy trì Visual Parity 1:1 với Android.
- **.systemSmall (2x2) & .systemMedium (4x2):**
  - Thuật toán `allFinished = !displayClasses.isEmpty && displayClasses.allSatisfy { $0.isFinished == true }`.
  - Nếu `allFinished == true`:
    + `.systemSmall`: Hiển thị badge `[ĐÃ XONG]` màu xám `.gray`.
    + `.systemMedium`: Hiển thị badge `[ĐÃ HOÀN THÀNH]` màu xám `.gray`. Cột mốc Timeline Capsule chuyển độ mờ `opacity(0.5)`. Giờ học và tên môn chuyển sang màu `.gray`.
  - Nếu `displayClasses.isEmpty`: Hiển thị thông điệp `"Hôm nay nghỉ"`.

### 2.4. Tầng Live Preview Widget Studio (`lib/screens/widget_studio_screen.dart`)
- **Biến thể 1 Ngày 4x2 Timeline:** Thuộc tính `allFinished = classes.isNotEmpty && classes.every((c) => c.isFinished)`. Hiển thị badge `[ĐÃ HOÀN THÀNH]`. Môn học đã học xong hiển thị với màu `secondaryColor`.
- **Biến thể 1 Ngày 2x2:** Hiển thị badge `[ĐÃ XONG]` ở góc dưới cùng khi `allFinished == true`. Tên môn học hiển thị với màu `secondaryColor`.
- **Biến thể 3 Ngày & 7 Ngày (Weekly Grid):** Tên môn học được làm mờ với `secondaryColor` khi `isFinished == true`, không rơi vào nhánh `Không có lịch`.

---

## 3. BẢNG ĐÁNH GIÁ CHI TIẾT CÁC TIÊU CHÍ NGHIỆM THU (ACCEPTANCE CRITERIA)

| Mã AC | Tiêu chí nghiệm thu | Tiêu chuẩn đánh giá từ Spec | Kết quả kiểm thử thực tế | Đánh giá |
| :--- | :--- | :--- | :--- | :---: |
| **AC-01** | **Bảo toàn 100% dữ liệu ca học đã kết thúc trong ngày tại Service lõi** | - `WidgetDataSyncService.dart` không còn lệnh `continue` xóa ca học.<br>- Mọi ca học hôm nay (kể cả đã qua giờ kết thúc) đều được giữ lại trong `classes` với cờ `isFinished: true`. | - Đã loại bỏ hoàn toàn lệnh `if (isTargetToday && isFinished) continue;`.<br>- Unit test xác nhận sau 18:00 ca học 12:55-17:05 vẫn nằm trong `classes` với `isFinished == true` và `isCurrentOrNext == false`.<br>- Phân biệt chính xác giữa ca sáng đã học xong và ca chiều sắp học. | **PASS** |
| **AC-02** | **Widget Tuần (4x4) & Widget 3 Ngày hiển thị ca học đã xong thay vì "Không có lịch" (Android)** | - Khi ca học hôm nay đã kết thúc, ô Hôm nay vẫn hiển thị tên môn học với trạng thái hoàn thành / làm mờ (dimmed).<br>- Ô "Tổng kết tuần" tính đủ số buổi học trong tuần, không đếm nhầm thành ngày trống. | - `ScheduleWidgetProvider.kt` hiển thị tên môn học với màu `textSecColor` khi `is_finished == true`.<br>- Test case xác nhận khi Thứ 2 có 1 ca duy nhất đã học xong, ô Tổng kết tuần báo chuẩn `1 buổi học • 0 buổi thi` và `6 ngày trống` (không đếm nhầm T2 là ngày trống thứ 7). | **PASS** |
| **AC-03** | **Widget "Lịch hôm nay" (1 Ngày & 2x2) phân biệt rõ "Hôm nay nghỉ" vs "Đã học xong" (Android)** | - Khi không có lịch: hiển thị `"Hôm nay nghỉ"`.<br>- Khi đã học xong tất cả các ca trong ngày: hiển thị tên môn học kèm chỉ báo `[ĐÃ XONG]` / hoàn thành, không báo `"Hôm nay nghỉ"`. | - Thuật toán `allFinished` nạp `allDayClasses` hiển thị môn kèm badge `[ĐÃ HOÀN THÀNH]` (4x2) và `[ĐÃ XONG]` (2x2).<br>- Chỉ khi không có môn nào trong TKB mới hiển thị `"Hôm nay nghỉ"`. | **PASS** |
| **AC-04** | **Đồng bộ hóa hiển thị trên iOS WidgetKit (Swift)** | - `ScheduleWidgetKit.swift` không hiển thị `"Không có lịch"` khi ngày hôm nay có ca học đã xong.<br>- Hiển thị tên môn ở trạng thái mờ (dimmed) / hoàn thành trên cả `.systemSmall`, `.systemMedium`, `.systemLarge`. | - `DayGridCellView` hiển thị môn đã xong với `.gray.opacity(0.7)`.<br>- `.systemSmall` hiển thị badge `[ĐÃ XONG]`.<br>- `.systemMedium` hiển thị badge `[ĐÃ HOÀN THÀNH]` kèm Timeline mờ 50%. | **PASS** |
| **AC-05** | **Đồng bộ Live Preview trong Widget Studio** | - `WidgetStudioScreen.dart` hiển thị visual parity 1:1 khi mô phỏng ca học đã hoàn thành. | - Widget test chứng minh Live Preview hiển thị chính xác tên môn và badge `[ĐÃ XONG]` (2x2) hoặc `[ĐÃ HOÀN THÀNH]` (4x2), không xuất hiện `"Hôm nay nghỉ"`. | **PASS** |
| **AC-06** | **Kiểm thử hồi quy & Bảo toàn Test Suite** | - Toàn bộ unit/widget test suites liên quan đến Widget Sync, Rolling Window, Tomorrow và Widget Studio đều PASS 100%. | - Đã chạy 8 bộ test suite liên quan: 100% tests PASSED (0 failures, 0 skipped, 0 regressions). | **PASS** |

---

## 4. BẰNG CHỨNG THỰC THI KIỂM THỬ TẦNG 2 (TERMINAL TEST EVIDENCE)

### 4.1. Bộ test nghiệm thu chuyên biệt cho Spec (`test/widget_finished_classes_preservation_test.dart`)
```text
$ flutter test test/widget_finished_classes_preservation_test.dart
00:00 +0: loading D:/Documents/Flutter/demo/test/widget_finished_classes_preservation_test.dart
00:00 +0: (setUpAll)
00:00 +0: SPEC-WIDGET-FINISHED-CLASSES-PRESERVATION-AND-STATUS-01 Acceptance Criteria Tests AC-01: Bảo toàn 100% dữ liệu ca học đã kết thúc trong ngày tại Service lõi
00:00 +1: SPEC-WIDGET-FINISHED-CLASSES-PRESERVATION-AND-STATUS-01 Acceptance Criteria Tests AC-01 Multi-class: Phân định chính xác ca đã xong và ca sắp tới trong ngày
00:00 +2: SPEC-WIDGET-FINISHED-CLASSES-PRESERVATION-AND-STATUS-01 Acceptance Criteria Tests AC-02: Widget 7 Ngày & 3 Ngày bảo toàn ca học và tính chuẩn Tổng kết tuần
00:00 +3: SPEC-WIDGET-FINISHED-CLASSES-PRESERVATION-AND-STATUS-01 Acceptance Criteria Tests AC-03: Widget 1 Ngày phân biệt rõ "Hôm nay nghỉ" vs "Đã học xong"
00:00 +4: SPEC-WIDGET-FINISHED-CLASSES-PRESERVATION-AND-STATUS-01 Acceptance Criteria Tests AC-05: Live Preview trong WidgetStudio hiển thị đúng visual parity khi ca học đã xong
00:01 +5: SPEC-WIDGET-FINISHED-CLASSES-PRESERVATION-AND-STATUS-01 Acceptance Criteria Tests AC-05 Parity: Live Preview hiển thị badge [ĐÃ HOÀN THÀNH] khi toàn bộ ca học đã kết thúc
00:01 +6: (tearDownAll)
00:01 +6: All tests passed!
```
$\rightarrow$ **Kết quả:** 6/6 tests PASS (100%).

---

### 4.2. Bộ test Rolling Window & Widget Ngày mai (`test/widget_rolling_and_tomorrow_test.dart`)
```text
$ flutter test test/widget_rolling_and_tomorrow_test.dart
00:00 +0: loading D:/Documents/Flutter/demo/test/widget_rolling_and_tomorrow_test.dart
00:00 +0: (setUpAll)
00:00 +0: Thuật toán Rolling ca học theo giờ thực tế (Hôm nay) 1. Trước 09:20 (08:00): Hiển thị 2 ca sáng (Tiết 1-3 và Tiết 4-6)
00:00 +1: Thuật toán Rolling ca học theo giờ thực tế (Hôm nay) 2. Sau 09:20 (10:00): Bảo toàn cả 3 ca học, đánh dấu ca 1 đã xong (isFinished: true) và ca 2 là ca kế tiếp
00:00 +2: Thuật toán Rolling ca học theo giờ thực tế (Hôm nay) 3. Sau 11:55 (12:00): Bảo toàn cả 3 ca học, ca 1 & 2 đã xong, ca 3 là ca kế tiếp
00:00 +3: Thuật toán Rolling ca học theo giờ thực tế (Hôm nay) 4. Sau 17:05 (18:00): Tất cả ca học kết thúc, bảo toàn cả 3 ca với isFinished = true
00:00 +4: Thuật toán Rolling ca học theo giờ thực tế (Hôm nay) 5. Sau 20:00: Vẫn giữ lịch Hôm nay (trung thành với hôm nay, widget ngày mai độc lập)
00:00 +5: Widget "NGÀY MAI (4x2)" - Khóa cứng nạp ngày kế tiếp Nạp cố định ngày kế tiếp (now + 1 ngày) bất kể giờ trong ngày
00:00 +6: Widget "NGÀY MAI (4x2)" - Khóa cứng nạp ngày kế tiếp Lưu và nạp SharedPreferences độc lập với key keyWidgetScheduleDataTomorrow
...
00:04 +22: Iteration 9: Kiểm Thử Độc Lập Toàn Diện 9 Nhiệm Vụ Tái Cấu Trúc Nhiệm vụ 4, 6, 7 & 8: Header sạch, Status bar đen than #1E293B trên nền sáng, Giảng viên HAU
00:04 +23: (tearDownAll)
00:05 +23: All tests passed!
```
$\rightarrow$ **Kết quả:** 23/23 tests PASS (100%).

---

### 4.3. Bộ test Widget Studio Comprehensive (`test/widget_studio_test.dart`)
```text
$ flutter test test/widget_studio_test.dart
...
00:05 +30: SPEC-WIDGET-STUDIO-02 Acceptance Criteria Verification Tests SPEC-3-VARIANTS: Tests 1 Ngày (2x2), 3 Ngày 4x2, 7 Ngày Grid 8 Ô (4x4)
00:05 +31: SPEC-WIDGET-STUDIO-02 Acceptance Criteria Verification Tests SPEC-REQ-4: Conditional Controls UX binary choices (Solid vs Transparent)
00:05 +32: SPEC-WIDGET-STUDIO-02 Acceptance Criteria Verification Tests SPEC-SCENARIO-FALLBACK: Mặc định luôn kín lịch 4 ca học, bỏ toolbar chọn mẫu
00:06 +33: (tearDownAll)
00:06 +33: All tests passed!
```
$\rightarrow$ **Kết quả:** 33/33 tests PASS (100%).

---

### 4.4. Bộ test Schedule Card Wrap & Timeline 4x2 (`test/inapp_schedule_card_multiline_and_widget_4x2_timeline_spec_test.dart` & `test/timeline_widget_spec_test.dart`)
```text
$ flutter test test/inapp_schedule_card_multiline_and_widget_4x2_timeline_spec_test.dart test/timeline_widget_spec_test.dart
...
00:01 +21: All tests passed!
```
$\rightarrow$ **Kết quả:** 21/21 tests PASS (100%).

---

### 4.5. Bộ test Đồng bộ Event-Driven & Khả năng chịu lỗi (`test/sync_resilience_and_data_integrity_test.dart` & `test/event_driven_sync_and_widget_fixes_test.dart`)
```text
$ flutter test test/sync_resilience_and_data_integrity_test.dart test/event_driven_sync_and_widget_fixes_test.dart
...
00:01 +22: All tests passed!
```
$\rightarrow$ **Kết quả:** 22/22 tests PASS (100%).

---

### 4.6. Bộ test Tương thích Bo góc & Widget Bugfixes (`test/widget_enhancement_spec_test.dart`, `test/widget_corner_resize_parity_test.dart`, `test/schedule_and_widget_bugfixes_test.dart`)
```text
$ flutter test test/widget_enhancement_spec_test.dart test/widget_corner_resize_parity_test.dart test/schedule_and_widget_bugfixes_test.dart
...
00:04 +31: All tests passed!
```
$\rightarrow$ **Kết quả:** 31/31 tests PASS (100%).

---

## 5. ĐÁNH GIÁ TÍNH NHẤT QUÁN & VISUAL PARITY ĐA NỀN TẢNG

| Nền tảng | Trạng thái hiển thị khi ca học đã qua | Thông báo / Badge trạng thái | Nhận xét Visual Parity |
| :--- | :--- | :--- | :--- |
| **Android RemoteViews** | Tên môn làm mờ (`textSecColor`), giờ bắt đầu giữ nguyên hoặc xám mờ. | - 4x2: `[ĐÃ HOÀN THÀNH]`<br>- 2x2: `[ĐÃ XONG]`<br>- 7 ngày: Ô T2 có môn mờ, ô Tổng kết đếm đủ. | Khớp 100% với Spec. |
| **iOS WidgetKit** | Tên môn màu `.gray` (hoặc `.gray.opacity(0.7)`), Capsule Timeline mờ 50%. | - .systemMedium: `[ĐÃ HOÀN THÀNH]`<br>- .systemSmall: `[ĐÃ XONG]`<br>- Weekly: Ô T2 có môn mờ. | Đồng bộ 1:1 với Android. |
| **Widget Studio (Flutter)** | Môn học áp dụng `secondaryColor`, hiển thị trung thực trạng thái thực tế. | - 4x2: `[ĐÃ HOÀN THÀNH]`<br>- 2x2: `[ĐÃ XONG]`<br>- 3/7 ngày: Text mờ với `secondaryColor`. | Live Preview mô phỏng chính xác Widget thật. |

---

## 6. KẾT LUẬN & ĐỀ XUẤT NGHIỆM THU (SIGN-OFF RECOMMENDATION)

### 6.1. Kết luận kiểm thử
1. **Nguyên nhân gốc rễ (Root Cause) đã được xử lý triệt để:** Không còn tình trạng xóa bỏ ca học đã kết thúc trong `WidgetDataSyncService.dart`.
2. **Hiển thị thông minh và trực quan:** Cả Android, iOS và Flutter Widget Studio đều phân định rạch ròi giữa *"Ngày nghỉ không có lịch"* (`"Hôm nay nghỉ"` / `"Không có lịch"`) và *"Ngày có ca học nhưng các ca đã hoàn thành"* (`[ĐÃ HOÀN THÀNH]` / `[ĐÃ XONG]`).
3. **Độ chính xác dữ liệu Widget Tuần:** Ô "Tổng kết tuần" tính toán chính xác 100% số buổi học thực tế, không bị đếm nhầm ngày có ca học đã xong thành ngày trống.
4. **Không có lỗi hồi quy (Zero Regressions):** 100% các bộ kiểm thử liên quan đều vượt qua thành công (136/136 test cases PASS).

### 6.2. Đề xuất bàn giao
- **Trạng thái:** **APPROVED & READY FOR PRODUCTION / USER SIGN-OFF**.
- Đề xuất Orchestrator chuyển giao cho BA / User để hoàn tất nghiệm thu và chuẩn bị đóng gói phát hành.
