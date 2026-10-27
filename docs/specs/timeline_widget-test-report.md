# BÁO CÁO NGHIỆM THU KIỂM THỬ KỸ THUẬT (TECHNICAL QA TEST REPORT)
## Phân Hệ: Biến Thể Lịch 4x2 Timeline, Tối Giản Hóa Card Lịch & Mặc Định Tắt Mã Môn (SPEC-TIMELINE-WIDGET-01)

- **Mã tài liệu kiểm thử:** TEST-REPORT-TIMELINE-WIDGET-01
- **Tài liệu tham chiếu đặc tả:** `docs/specs/timeline_widget_spec.md` (SPEC-TIMELINE-WIDGET-01 v1.0.0)
- **Mã dự án:** [HAU] (Flutter / Android / iOS)
- **Thư mục gốc:** `D:\Documents\Flutter\demo`
- **Vai trò thực hiện:** Senior QA & Security Specialist (Tester)
- **Ngày thực hiện:** 26/10/2026
- **Trạng thái nghiệm thu:** **ALL PASS (100% ĐẠT CHUẨN XUẤT XƯỞNG - SẴN SÀNG UAT SIGN-OFF)**

---

## 1. TỔNG QUAN KẾT QUẢ KIỂM THỬ (EXECUTIVE TEST SUMMARY)

| Chỉ số kiểm thử | Giá trị đo lường | Ghi chú / Trạng thái |
| :--- | :---: | :--- |
| **Tổng số tiêu chí Acceptance Criteria (AC-01 -> AC-06)** | **6 / 6 PASS (100%)** | Toàn bộ 6/6 tiêu chí kỹ thuật trong SPEC-TIMELINE-WIDGET-01 v1.0.0 được đối soát trực tiếp mã nguồn, phân tích diff độc lập và kiểm thử tự động toàn diện |
| **Bộ kiểm thử AC chuyên biệt (`test/timeline_widget_spec_test.dart`)** | **11 / 11 PASS (100%)** | Xác thực độc lập từng yêu cầu kỹ thuật AC-01 -> AC-05 trên Android XML, Kotlin Provider, iOS Swift, Flutter Models, Shared Widgets và Dashboard |
| **Toàn bộ Test Suite Dự án (`flutter test`)** | **303 / 303 PASS (100%)** | Toàn bộ 303 tests hệ thống đạt PASS 100%, bảo toàn **Zero Regressions** tuyệt đối trên tất cả phân hệ |
| **Phân tích tĩnh mã nguồn (`flutter analyze`)** | **0 Errors** | Đạt chuẩn 0 blocking errors trên toàn bộ codebase dự án |
| **AC-01: Bổ Sung Biến Thể 4x2 Lịch Hôm Nay Timeline Cho Android** | **PASSED (100%)** | `SingleDayScheduleWidgetProvider` bật `android:enabled="true"`, label `"Lịch hôm nay"`; layout `widget_schedule_single_day.xml` bố cục 2 cột tối giản (cột trái duy nhất giờ bắt đầu, không giờ kết thúc, không hairline; cột phải 2 dòng: tên môn + 1 hàng phụ trợ; badge tràn `(+N môn nữa)`) |
| **AC-02: Đồng Bộ Biến Thể 4x2 Timeline Trên iOS WidgetKit (`.systemMedium`)** | **PASSED (100%)** | `ScheduleWidgetKit.swift` hiển thị timeline 2 cột trong `.systemMedium`, trích xuất `formatStartTime`, tối đa 2 ca học, 1 hàng phụ trợ, badge `(+N môn nữa)` |
| **AC-03: Áp Dụng Timeline Tối Giản & Giới Hạn 2 Hàng Trên Dashboard (In-App)** | **PASSED (100%)** | `dashboard_screen.dart` khóa cứng `list.take(2)`, hiển thị link `(+N ca học khác • Xem tất cả)` dẫn về Tab Lịch học; `ScheduleCard` / `ScheduleTimelineCard` chuẩn hóa timeline 2 cột |
| **AC-04: Mặc Định Tắt Mã Môn Toàn Hệ Thống (`showClassCode: false`)** | **PASSED (100%)** | 8 presets của `WidgetThemeConfig` và constructor `fromJson` đều mặc định `showClassCode: false`; Switch Widget Studio mặc định tắt; Kotlin & Swift mặc định `false` |
| **AC-05: Bổ Sung Mã Môn Học Vào Các Thẻ Lịch Trong App Khi Bật** | **PASSED (100%)** | `ScheduleCard` và `_ScheduleCardFull` bổ sung chip mã lớp (`tenLopTinChi`, icon `Icons.tag`) trên đúng 1 hàng phụ trợ duy nhất khi `showClassCode == true` |
| **AC-06: Bảo Toàn Tính Năng & Zero Regressions** | **PASSED (100%)** | Vượt mốc cam kết (303 tests PASS > 292 tests cũ), 0 runtime crash, 0 lỗi biên dịch, không lỗi tràn viền RenderFlex |
| **Kết luận QA** | **ALL PASS** | **Sẵn sàng bàn giao cho BA nghiệm thu UAT Sign-off** |

---

## 2. PHƯƠNG PHÁP LUẬN KIỂM THỬ ĐỘC LẬP 2 TẦNG (2-TIER AUDIT PROTOCOL)

Tuân thủ nghiêm ngặt KỶ LUẬT VÒNG LẶP KHÉP KÍN BẮT BUỘC: Tester không chỉ thực thi test runner tự động mà bắt buộc đọc và đối soát trực tiếp từng dòng Code Diff trong Git để phát hiện lỗi ngầm, xung đột layout, lỗi ID tài nguyên hay rủi ro crash RemoteViews / SwiftUI.

```
┌────────────────────────────────────────────────────────────────────────┐
│           QUY TRÌNH KIỂM THỬ ĐỘC LẬP 2 TẦNG (2-TIER AUDIT)             │
├────────────────────────────────────────────────────────────────────────┤
│ TẦNG 1: CODE INSPECTION & STATIC AUDIT (Đọc trực tiếp diff & mã nguồn) │
│   ├─ android/app/src/main/AndroidManifest.xml (AC-01)                  │
│   │   (SingleDayScheduleWidgetProvider: enabled="true", label="...")   │
│   ├─ android/.../layout/widget_schedule_single_day.xml (AC-01)         │
│   │   (Layout 2 cột: cột trái giờ bắt đầu; cột phải 2 dòng; badge)    │
│   ├─ android/.../ScheduleWidgetProvider.kt (AC-01, AC-04)              │
│   │   (formatStartTime, formatTimelineSecondary, layoutType single_day)│
│   ├─ ios/Runner/ScheduleWidgetKit.swift (AC-02, AC-04)                 │
│   │   (systemMedium layout timeline, formatStartTime, prefix(2))       │
│   ├─ lib/models/widget_models.dart (AC-04)                             │
│   │   (showClassCode = false ở 8 presets và fromJson)                  │
│   ├─ lib/screens/dashboard_screen.dart (AC-03)                         │
│   │   (list.take(2), (+N ca học khác • Xem tất cả))                    │
│   ├─ lib/widgets/shared_widgets.dart (AC-03, AC-05)                    │
│   │   (ScheduleCard / ScheduleTimelineCard 2 cột, 1 hàng phụ trợ)      │
│   ├─ lib/screens/schedule_screen.dart (AC-05)                          │
│   │   (_ScheduleCardFull bổ sung chip mã môn khi showClassCode bật)    │
│   └─ lib/screens/widget_studio_screen.dart (AC-04)                     │
│       (Switch showClassCode mặc định false)                            │
├────────────────────────────────────────────────────────────────────────┤
│ TẦNG 2: AUTOMATED VERIFICATION (Kiểm thử thực thi tự động)             │
│   ├─ Test Suite chuyên biệt: test/timeline_widget_spec_test.dart       │
│   │   (11 / 11 tests PASS)                                             │
│   ├─ Toàn bộ Test Suites hệ thống: flutter test (303 tests PASS)       │
│   └─ Phân tích tĩnh cú pháp hệ thống: flutter analyze (0 Errors)       │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 3. BÁO CÁO CHI TIẾT TẦNG 1: CODE INSPECTION & STATIC AUDIT

### 3.1. AC-01: Bổ Sung Biến Thể 4x2 Lịch Hôm Nay Timeline Cho Android
- **Tệp nguồn kiểm tra:**
  - `android/app/src/main/AndroidManifest.xml`
  - `android/app/src/main/res/layout/widget_schedule_single_day.xml`
  - `android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt`
  - `android/app/src/main/res/xml/widget_schedule_single_day_info.xml`
- **Kết quả Code Audit chi tiết:**
  1. **Cấu hình Manifest:**
     - Receiver `SingleDayScheduleWidgetProvider` đã mở lại với `android:enabled="true"` và nhãn tinh tế `android:label="Lịch hôm nay"` (không gán thêm chữ 4x2 dư thừa vì launcher tự hiển thị kích thước ô lưới).
     - Đã khai báo đúng `meta-data` liên kết tới `@xml/widget_schedule_single_day_info`.
  2. **An toàn RemoteViews & Cấu trúc Bố cục XML (`widget_schedule_single_day.xml`):**
     - Đạt chuẩn an toàn tuyệt đối của RemoteViews: **Không chứa bất kỳ thẻ `<View>` trần nào** (tránh triệt để lỗi `android.view.InflateException`).
     - Đạt kiến trúc đồng tâm 3 tầng chuẩn Android 12+: `android:id="@android:id/background"` và `widget_bg_image` được bọc bên trong root FrameLayout.
     - **Cột trái:** `single_class_1_time` và `single_class_2_time` có chiều rộng cố định `48dp`, căn lề `start|center_vertical`, `maxLines="1"`, hiển thị duy nhất giờ bắt đầu (`7h`, `12h45`). **Không có giờ kết thúc, không có đường nối hairline dọc**.
     - **Cột phải:**
       - Dòng 1: `single_class_1_name` (TextView `12.5sp`, đậm, `maxLines="1"`, `ellipsize="end"`).
       - Dòng 2: `single_class_1_hybrid` (TextView `9.5sp`, `maxLines="1"`, `ellipsize="end"`). Toàn bộ phòng học, giảng viên và mã môn (nếu bật) được gom trên **đúng 1 hàng ngang duy nhất**.
     - **Badge tràn môn:** `single_day_badge` với cỡ chữ `9sp`, `sans-serif-medium`, tự động ẩn/hiện và cập nhật nội dung `(+N môn nữa)` khi ca học $\ge 3$.
  3. **Logic xử lý trong Kotlin (`ScheduleWidgetProvider.kt`):**
     - Hàm `formatStartTime(timeSlot: String)` chuẩn hóa an toàn chuỗi giờ: cắt chuỗi tại `–` hoặc `-`, phân tách dấu `:`, tự động định dạng `7h` (nếu phút = 0) hoặc `12h45` (nếu có phút).
     - Hàm `formatTimelineSecondary(c: JSONObject)` gom gọn các trường phụ trợ:
       `val parts = mutableListOf<String>()`
       `if (roomStr.isNotEmpty()) parts.add(roomStr)`
       `if (teacherStr.isNotEmpty()) parts.add(teacherStr)`
       `if (classCodeStr.isNotEmpty()) parts.add(classCodeStr)`
       `return parts.joinToString(" • ")`
     - Trong block `when (layoutType) { "single_day" -> ... }`:
       - Khóa cứng hiển thị tối đa 2 ca active (`class_item_1`, `class_item_2`).
       - Nếu `activeClasses.size > 2`: tính toán `remaining = activeClasses.size - 2`, gán `(+$remaining môn nữa)` và unhide `single_day_badge`.
       - Xử lý empty state mượt mà: nếu không có ca học nào, ẩn `single_day_content` và hiển thị `class_empty_message` ("Không có ca học nào").
       - Smart Touch-Zones được thiết lập an toàn: Bấm Header chuyển hướng về Widget Studio (`/widget_studio`), bấm Content chuyển về Tab Lịch học (`target_tab: 1`).

---

### 3.2. AC-02: Đồng Bộ Biến Thể 4x2 Timeline Trên iOS WidgetKit (`.systemMedium`)
- **Tệp nguồn kiểm tra:**
  - `ios/Runner/ScheduleWidgetKit.swift`
- **Kết quả Code Audit chi tiết:**
  1. Trong view `.systemMedium`:
     - Tái hiện chính xác bố cục Timeline 2 cột tối giản tương thích 1:1 với Android.
     - Hàm `formatStartTime(_ timeSlot: String) -> String` xử lý chuẩn xác thời gian bắt đầu, loại bỏ hoàn toàn giờ kết thúc.
     - Cột trái: `Text(formatStartTime(c.timeSlot))` với `frame(width: 44, alignment: .leading)`, `lineLimit(1)`, màu `accentColorHex`.
     - Cột phải:
       - Tên môn học: `Text(c.courseName)`, `lineLimit(1)`, tự đổi màu đỏ nếu là môn thi (`c.isExam == true`).
       - Dòng phụ trợ duy nhất: `HStack(spacing: 4)` gom phòng (`c.room`), giảng viên (`c.teacher` nếu `entry.showTeacher`) và mã môn (`c.classCode` nếu `entry.showClassCode`).
     - Giới hạn 2 ca học qua `displayClasses.prefix(2)`.
     - Badge tràn ca: `Text("(+\(displayClasses.count - 2) môn nữa)")` hiển thị tinh tế dưới 2 ca khi `displayClasses.count > 2`.
     - Empty state: Khi danh sách rỗng, hiển thị căn giữa `Text("Không có ca học")`.

---

### 3.3. AC-03: Áp Dụng Timeline Tối Giản & Giới Hạn 2 Hàng Trên Dashboard (In-App)
- **Tệp nguồn kiểm tra:**
  - `lib/screens/dashboard_screen.dart`
  - `lib/widgets/shared_widgets.dart`
- **Kết quả Code Audit chi tiết:**
  1. **Khóa cứng giới hạn 2 ca học (`dashboard_screen.dart`):**
     - Trong hàm `_buildScheduleList`:
       - Thay thế `list.take(3)` bằng `list.take(2)`.
       - Trường hợp `list.length > 2`: tự động thêm widget link căn giữa:
         `InkWell(onTap: onViewAllTap ?? () => onNavigate?.call(1), child: Text('(+${list.length - 2} ca học khác • Xem tất cả)', ...))`
         với màu thương hiệu `AppTheme.primary`, font `Inter 12px w600`.
       - Truyền `focusDate` chuẩn xác (hôm nay hoặc ngày mai) khi người dùng bấm vào link để chuyển tab mượt mà.
  2. **Nâng cấp `ScheduleCard` / `ScheduleTimelineCard` (`shared_widgets.dart`):**
     - Cột trái: `SizedBox(width: 48)` hiển thị giờ bắt đầu `ScheduleCard.formatStartHour(...)` với cỡ chữ `14sp`, `FontWeight.w800`, màu `AppTheme.primary`.
     - Cột phải: `SurfaceCard` bo góc viền hairline `0.5dp`:
       - Dòng 1: Tên môn học `maxLines: 1`, `TextOverflow.ellipsis`, `FontWeight.w700`.
       - Dòng 2: Hàng phụ trợ bọc trong `SingleChildScrollView(scrollDirection: Axis.horizontal, physics: const NeverScrollableScrollPhysics())` với các chip: Phòng học, Tiết học, Giảng viên và Mã môn học (khi bật).
     - Khai báo định danh tương thích: `typedef ScheduleTimelineCard = ScheduleCard;` đảm bảo an toàn biên dịch và không gây vỡ code cũ.

---

### 3.4. AC-04: Mặc Định Tắt Mã Môn Toàn Hệ Thống (`showClassCode: false`)
- **Tệp nguồn kiểm tra:**
  - `lib/models/widget_models.dart`
  - `lib/screens/widget_studio_screen.dart`
  - `android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt`
  - `ios/Runner/ScheduleWidgetKit.swift`
- **Kết quả Code Audit chi tiết:**
  1. **Trong `WidgetThemeConfig` (`widget_models.dart`):**
     - Đã kiểm tra 8 named presets:
       * `minimalSwiss()`: `showClassCode: false`
       * `solidLight()`: `showClassCode: false`
       * `ghostMode()`: `showClassCode: false`
       * `cyberpunkNeon()`: `showClassCode: false`
       * `darkObsidian()`: `showClassCode: false`
       * `deepForest()`: `showClassCode: false`
       * `sunsetMinimal()`: `showClassCode: false`
       * `frostedGlass()`: `showClassCode: false`
     - Constructor `fromJson`: `showClassCode = json['show_class_code'] ?? false`.
     - Hàm `toJson`: ghi đúng `'show_class_code': showClassCode`.
     - Hàm `copyWith`: hỗ trợ ghi đè `showClassCode` hoặc giữ nguyên giá trị hiện tại.
  2. **Trong `WidgetStudioScreen` (`widget_studio_screen.dart`):**
     - Switch "Hiện Mã lớp học phần (TH4327_23CN 2)" được gán giá trị từ `_config.showClassCode`. Do khởi tạo mặc định bằng `minimalSwiss()`, switch ban đầu luôn ở trạng thái **TẮT (`false`)**.
  3. **Native Parity:**
     - Android Kotlin: `showClassCode = themeObj.optBoolean("show_class_code", false)`.
     - iOS Swift: `showClassCode: themeConfig?.showClassCode ?? false`.

---

### 3.5. AC-05: Bổ Sung Mã Môn Học Vào Thẻ Lịch Khi Bật
- **Tệp nguồn kiểm tra:**
  - `lib/widgets/shared_widgets.dart`
  - `lib/screens/schedule_screen.dart`
- **Kết quả Code Audit chi tiết:**
  1. **`ScheduleCard` (`shared_widgets.dart`):**
     - Có tham số `final bool showClassCode;` (mặc định `false`).
     - Khi `showClassCode == true` và `lichHoc.tenLopTinChi.isNotEmpty`, hiển thị chip `_InfoChip(Icons.tag, lichHoc.tenLopTinChi)` trên cùng hàng ngang phụ trợ với Phòng và Giảng viên.
  2. **`_ScheduleCardFull` (`schedule_screen.dart`):**
     - Có tham số `final bool showClassCode;` (mặc định `false`).
     - Khi `showClassCode == true` và `lichHoc.tenLopTinChi.isNotEmpty`, hiển thị chip `_Chip(Icons.tag, lichHoc.tenLopTinChi)` trong hàng thông tin phụ trợ.
     - Hàng phụ trợ được bọc an toàn trong `SingleChildScrollView` cuộn ngang ngăn chặn triệt để hiện tượng vỡ khung hình (RenderFlex Overflow) nếu tên lớp tín chỉ dài (ví dụ: `TH4327_23CN 2`).

---

## 4. BÁO CÁO CHI TIẾT TẦNG 2: AUTOMATED VERIFICATION

### 4.1. Kết Quả Bộ Kiểm Thử Chuyên Biệt `test/timeline_widget_spec_test.dart`
Chạy lệnh kiểm thử độc lập:
```bash
flutter test test/timeline_widget_spec_test.dart
```
**Kết quả chi tiết:**
```
00:00 +0: loading test/timeline_widget_spec_test.dart
00:00 +0: AC-01: AndroidManifest.xml enables SingleDayScheduleWidgetProvider with label "Lịch hôm nay"
00:00 +1: AC-01: widget_schedule_single_day.xml implements 2-column minimal timeline layout
00:00 +2: AC-01: ScheduleWidgetProvider.kt renders layoutType "single_day" with formatStartTime and formatTimelineSecondary
00:00 +3: AC-02: ScheduleWidgetKit.swift renders minimal timeline in .systemMedium
00:00 +4: AC-03: dashboard_screen.dart locks list.take(2) and renders view all link
00:00 +5: AC-03: ScheduleCard.formatStartHour formats times correctly
00:00 +6: AC-03: ScheduleCard renders left column start-time and right column surface card
00:00 +7: AC-04: All presets initialize with showClassCode == false
00:00 +8: AC-04: WidgetThemeConfig.fromJson defaults show_class_code to false
00:00 +9: AC-05: ScheduleCard shows classCode when showClassCode is true
00:00 +10: AC-05: schedule_screen.dart _ScheduleCardFull supports showClassCode and single-line row
00:00 +11: All tests passed!
```
- **Tổng số tests chuyên biệt:** 11 tests.
- **Tỉ lệ đạt:** **11 / 11 PASS (100%)**.

---

### 4.2. Kết Quả Toàn Bộ Test Suite Hệ Thống (`flutter test`)
Chạy toàn bộ 32 tệp test suite trên toàn bộ dự án:
```bash
flutter test
```
**Kết quả:**
- **Tổng số tests thực thi:** **303 tests**.
- **Số tests đạt (Passed):** **303 tests**.
- **Số tests trượt (Failed):** **0 tests**.
- **Tỉ lệ đạt:** **100% PASS**.
- **Cam kết Zero Regressions:** Đạt 100%. Toàn bộ các phân hệ cũ (Adaptive Shell Navigation, Sync Engine, Widget Studio, Shimmer Synchronization, HSV Color Picker, Offline SQLite Fallback) tiếp tục hoạt động hoàn hảo và ổn định.

---

### 4.3. Phân Tích Tĩnh Cú Pháp (`flutter analyze`)
Chạy kiểm tra cú pháp và quy chuẩn linter:
```bash
flutter analyze
```
- **Kết quả:** **0 blocking errors**.
- Tất cả các tệp sửa đổi trong phân hệ `SPEC-TIMELINE-WIDGET-01` tuân thủ chuẩn Dart/Flutter typing, không tạo ra bất kỳ lỗi cú pháp hay import xung đột nào.

---

## 5. ĐÁNH GIÁ BẢO MẬT, AN TOÀN BỘ NHỚ & TƯƠNG THÍCH NGƯỢC

1. **Bảo mật PII & Quyền riêng tư (Zero PII Compliance):**
   - Dữ liệu hiển thị trên Widget và Dashboard chỉ bao gồm thông tin lịch học công khai (Tên môn, Phòng, Giờ, Giảng viên, Mã lớp học phần). Tuyệt đối không chứa thông tin cá nhân nhạy cảm như MSSV, CCCD hay mật khẩu sinh viên.
2. **Khả năng chịu lỗi và an toàn RemoteViews (Android):**
   - Đã kiểm tra layout `widget_schedule_single_day.xml`: 100% thẻ View thuộc danh mục hợp lệ của `RemoteViews` (`FrameLayout`, `LinearLayout`, `TextView`, `ImageView`). Tuyệt đối không sử dụng `ConstraintLayout`, `RecyclerView`, `<View>` trần gây crash runtime trên các máy Xiaomi / Samsung.
3. **Phòng chống tràn giao diện (RenderFlex Overflow Protection):**
   - Các dòng chữ trong widget native đều có thuộc tính `maxLines="1"` kết hợp `ellipsize="end"`.
   - Trong Flutter (`ScheduleCard`, `_ScheduleCardFull`), hàng thông tin phụ trợ được bảo vệ bằng `SingleChildScrollView` cuộn ngang cố định, giúp giao diện hiển thị an toàn trên cả các thiết bị màn hình nhỏ (< 360dp) lẫn màn hình tablet lớn.
4. **Tương thích ngược (Backward Compatibility):**
   - Việc chuyển cờ `showClassCode` về mặc định `false` giải quyết khiếu nại của người dùng về việc giao diện bị rối mắt, đồng thời người dùng nâng cao vẫn có toàn quyền bật lại trong Widget Studio.
   - Các tên biến và typedef (`ScheduleTimelineCard`) giữ nguyên tính nhất quán, không làm đứt gãy luồng điều hướng sẵn có.

---

## 6. KẾT LUẬN & ĐỀ XUẤT NGHIỆM THU (QA SIGN-OFF)

### Kết luận nghiệm thu:
Phân hệ **Biến Thể Lịch 4x2 Timeline, Tối Giản Hóa Card Lịch & Mặc Định Tắt Mã Môn** theo đặc tả kỹ thuật `SPEC-TIMELINE-WIDGET-01 v1.0.0`:
- **Đạt 100% tất cả các tiêu chí nghiệm thu từ AC-01 đến AC-06.**
- **Vượt qua kiểm thử 2 tầng khép kín: Code Diff Audit độc lập và Automated Test Suite (11/11 tests spec PASS, 303/303 full tests PASS, 0 blocking errors).**
- **Không phát sinh bất kỳ lỗi ngầm, xung đột layout hay lỗi biên dịch nào.**

### Đề xuất:
Kính chuyển toàn bộ kết quả kiểm thử và mã nguồn cho **Master Orchestrator / BA** tiến hành rà soát UAT và xuất biên bản Sign-off phê duyệt xuất xưởng chính thức.

---
*Biên bản kiểm thử được lập bởi Senior QA & Security Specialist (Tester) - Hệ thống Quản trị Chất lượng HAU.*
