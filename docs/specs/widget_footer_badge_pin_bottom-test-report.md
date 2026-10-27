# BÁO CÁO KIỂM THỬ ĐỘC LẬP 2 TẦNG (TWO-TIER AUDIT REPORT)
## Spec: SPEC-WIDGET-FOOTER-BADGE-PIN-BOTTOM-01
### Phân Hệ: Tối Ưu Bố Cục Ghim Dòng (+N Môn Nữa) Xuống Footer Sát Đáy Thẻ Widget 4x2 (Đồng Bộ Android, iOS & Studio)

- **Mã tài liệu:** `REPORT-WIDGET-FOOTER-BADGE-PIN-BOTTOM-01`
- **Ngày thực hiện:** 27/10/2026
- **Vai trò:** Tester Độc lập (QA / Independent Security & Quality Auditor)
- **Đối tượng kiểm thử:** Mã nguồn do Dev2 lập trình theo Spec `docs/specs/widget_footer_badge_pin_bottom_spec.md`
- **Dự án:** Trạm Kiến - HAU (Flutter / Android Kotlin / iOS Swift)
- **Kết quả tổng quát:** **PASS 100% (5/5 AC ĐẠT CHUẨN, 0 REGRESSION BUGS)**

---

## 1. PHƯƠNG PHÁP KIỂM THỬ 2 TẦNG (TWO-TIER AUDIT METHODOLOGY)

Để đảm bảo tính khách quan, tính toàn vẹn hệ thống và chất lượng bàn giao kỹ thuật chuẩn mực, quá trình kiểm thử được triển khai độc lập thành 2 tầng:

1. **Tầng 1 - Rà soát tĩnh mã nguồn (Static Code Diff & Architecture Audit):**
   - Đọc và đối soát trực tiếp source code / code diff của các file dev sửa:
     + `lib/screens/widget_studio_screen.dart`: Kiểm tra hàm `_buildSingleDay4x2TimelineContent`, vị trí của `const Spacer()`, tọa độ Y và logic hiển thị dòng `(+N môn nữa)`.
     + `android/app/src/main/res/layout/widget_schedule_single_day.xml`: Kiểm tra cấu trúc view tree, phần tử đệm `single_day_spacer` (`layout_weight="1"`), vị trí trước `single_day_badge`, và đối chiếu nghiêm ngặt quy tắc RemoteViews whitelist (tuyệt đối không dùng `<View>` hoặc `<Space>`).
     + `android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt`: Kiểm tra logic điều khiển hiển thị `single_day_spacer` và `single_day_badge` (`View.VISIBLE` khi `displayClasses.size > 2`, và `View.GONE` khi `<= 2`).
     + `ios/Runner/ScheduleWidgetKit.swift`: Kiểm tra nhánh `.systemMedium`, xác nhận vị trí của `Spacer(minLength: 0)` đứng trước `if displayClasses.count > 2`.

2. **Tầng 2 - Thực thi kiểm thử động (Dynamic Test Suite Execution):**
   - Chạy test suite nghiệm thu chuyên biệt: `test/widget_footer_badge_pin_bottom_spec_test.dart`.
   - Chạy các test suites quan trọng liên quan: `test/timeline_widget_spec_test.dart`, `test/inapp_schedule_card_multiline_and_widget_4x2_timeline_spec_test.dart`, `test/widget_timeline_time_range_and_studio_mock_restore_spec_test.dart`, `test/widget_studio_test.dart`, `test/widget_enhancement_spec_test.dart`, `test/widget_cleanup_2x2_alignment_and_real_data_spec_test.dart`, `test/hotfix_widget_overflow_and_load_test.dart`.
   - Đảm bảo 100% test cases PASS, không có lỗi render overflow, không crash, không regression.

---

## 2. KẾT QUẢ KIỂM TRA TẦNG 1: RÀ SOÁT MÃ NGUỒN (SOURCE CODE AUDIT)

### 2.1. Flutter Widget Studio (`lib/screens/widget_studio_screen.dart`)
- **Vị trí rà soát:** Dòng 1230 – 1256 (`_buildSingleDay4x2TimelineContent`)
- **Chi tiết triển khai:**
  ```dart
  return Column(
    mainAxisAlignment: MainAxisAlignment.start,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (int i = 0; i < displayClasses.length; i++) ...[
        if (i > 0) const SizedBox(height: 8),
        _buildTimelineRow(
          displayClasses[i],
          primaryColor,
          secondaryColor,
          accent,
        ),
      ],
      if (classes.length > 2) ...[
        const Spacer(),
        Text(
          '(+${classes.length - 2} môn nữa)',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            color: accent,
          ),
        ),
      ],
    ],
  );
  ```
- **Phân tích kỹ thuật:**
  - `_buildLayoutContent` được bọc bên trong một container `Expanded` có giới hạn chiều cao xác định (bounded height) tại dòng 1147.
  - Khi `classes.length > 2`, `const Spacer()` chiếm toàn bộ khoảng trống còn lại giữa Môn học 2 và dòng chữ chú thích, đẩy Text `(+N môn nữa)` xuống sát đáy thẻ widget (Footer).
  - Khi `classes.length <= 2`, khối `if (classes.length > 2)` không kích hoạt, không có `Spacer()` thừa, các ca học giữ nguyên vị trí top-aligned gọn gàng.
- **Đánh giá:** **ĐẠT (PASS)** - Đã giải quyết triệt để lỗi khoảng trống chết ở đáy thẻ trên Live Preview.

---

### 2.2. Android Native XML (`android/app/src/main/res/layout/widget_schedule_single_day.xml`)
- **Vị trí rà soát:** Dòng 283 – 303 (`widget_schedule_single_day.xml`)
- **Chi tiết triển khai:**
  ```xml
  <!-- Spacer co dãn đẩy badge xuống đáy Footer khi có >= 3 ca (RemoteViews safe: dung ImageView) -->
  <ImageView
      android:id="@+id/single_day_spacer"
      android:layout_width="match_parent"
      android:layout_height="0dp"
      android:layout_weight="1"
      android:visibility="gone" />

  <!-- Badge hiển thị khi có >= 3 ca: (+N môn nữa) -->
  <TextView
      android:id="@+id/single_day_badge"
      android:layout_width="wrap_content"
      android:layout_height="wrap_content"
      android:text="(+1 môn nữa)"
      android:textColor="#1D64F2"
      android:textSize="9sp"
      android:fontFamily="sans-serif-medium"
      android:letterSpacing="-0.02"
      android:includeFontPadding="false"
      android:visibility="gone" />
  ```
- **Phân tích kỹ thuật & An toàn RemoteViews:**
  - Android AppWidget RemoteViews áp dụng whitelist nghiêm ngặt về thẻ XML: Việc sử dụng `<View>` hoặc `<Space>` sẽ làm crash RemoteViews (`InflateException: Class not allowed to be inflated`).
  - Dev2 đã sử dụng thẻ `<ImageView>` nằm trong whitelist được hỗ trợ chính thức bởi Android RemoteViews.
  - `android:layout_height="0dp"` kết hợp `android:layout_weight="1"` bên trong `LinearLayout` (`orientation="vertical"`) đảm bảo giãn nở trơn tru chiếm toàn bộ khoảng trống dư thừa, đẩy `single_day_badge` về sát viền dưới của thẻ widget.
  - Phần tử `single_day_spacer` nằm ngay phía trước `single_day_badge` trong luồng XML flow.
- **Đánh giá:** **ĐẠT (PASS)** - Đạt chuẩn kỹ thuật RemoteViews, không vi phạm tag cấm.

---

### 2.3. Android Kotlin Provider (`android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt`)
- **Vị trí rà soát:** Dòng 636, dòng 718 – 727
- **Chi tiết triển khai:**
  ```kotlin
  // Reset trạng thái mặc định
  views.setViewVisibility(R.id.single_day_spacer, View.GONE)

  // Điều khiển hiển thị động theo số lượng môn học
  if (displayClasses.size > 2) {
      val remaining = displayClasses.size - 2
      views.setViewVisibility(R.id.single_day_spacer, View.VISIBLE)
      views.setTextViewText(R.id.single_day_badge, "(+$remaining môn nữa)")
      views.setTextColor(R.id.single_day_badge, accentColor)
      views.setViewVisibility(R.id.single_day_badge, View.VISIBLE)
  } else {
      views.setViewVisibility(R.id.single_day_spacer, View.GONE)
      views.setViewVisibility(R.id.single_day_badge, View.GONE)
  }
  ```
- **Phân tích kỹ thuật:**
  - Xử lý reset visibility về `View.GONE` ở đầu hàm render để tránh lưu trạng thái cũ khi view được tái sử dụng.
  - Khi có $\ge 3$ môn (`displayClasses.size > 2`): cả `single_day_spacer` và `single_day_badge` đều được set `View.VISIBLE`. Spacer co dãn đẩy badge xuống đáy thẻ.
  - Khi có 1 hoặc 2 môn (`displayClasses.size <= 2`): cả `single_day_spacer` và `single_day_badge` đều được set `View.GONE`. Spacer ẩn đi hoàn toàn, không chiếm diện tích weight, giữ cho các môn học 1 và 2 hiển thị top-aligned tự nhiên.
- **Đánh giá:** **ĐẠT (PASS)** - Logic chặt chẽ, tối ưu hiệu năng RemoteViews.

---

### 2.4. iOS WidgetKit (`ios/Runner/ScheduleWidgetKit.swift`)
- **Vị trí rà soát:** Dòng 524 – 536 (Nhánh `default: // systemMedium (4x2 Timeline Minimalist Layout)`)
- **Chi tiết triển khai:**
  ```swift
              Spacer(minLength: 0)
          }
      }
      Spacer(minLength: 0)
      if displayClasses.count > 2 {
          Text("(+\(displayClasses.count - 2) môn nữa)")
              .font(.system(size: 8.5, weight: .bold))
              .foregroundColor(Color(hex: entry.accentColorHex) ?? .blue)
      }
  }
  ```
- **Phân tích kỹ thuật:**
  - Trong cấu trúc `VStack(alignment: .leading, spacing: 8)`, `Spacer(minLength: 0)` được chuyển lên phía trước điều kiện `if displayClasses.count > 2`.
  - Khi `displayClasses.count > 2`, `Spacer(minLength: 0)` đẩy dòng `Text("(+\(displayClasses.count - 2) môn nữa)")` xuống chân thẻ widget, tạo visual parity 1:1 với Android Native và Studio Live Preview.
  - Khi `displayClasses.count <= 2`, `Spacer(minLength: 0)` nằm ở đáy danh sách môn học, giúp hấp thu khoảng trống bên dưới mà không làm thay đổi vị trí top-aligned của Môn 1 & Môn 2.
- **Đánh giá:** **ĐẠT (PASS)** - Đạt chuẩn SwiftUI layout và đồng bộ hoàn toàn với Android.

---

## 3. KẾT QUẢ KIỂM TRA TẦNG 2: THỰC THI KIỂM THỬ ĐỘNG (TEST SUITE EXECUTION)

### 3.1. Test Suite Chuyên Biệt Spec: `test/widget_footer_badge_pin_bottom_spec_test.dart`
- **Lệnh thực thi:**
  ```bash
  flutter test test/widget_footer_badge_pin_bottom_spec_test.dart
  ```
- **Kết quả thực thi chi tiết:**
  ```
  00:00 +0: loading D:/Documents/Flutter/demo/test/widget_footer_badge_pin_bottom_spec_test.dart
  00:00 +0: SPEC-WIDGET-FOOTER-BADGE-PIN-BOTTOM-01 Acceptance Criteria Tests AC-01: Pinned Footer Badge in WidgetStudioScreen Live Preview lib/screens/widget_studio_screen.dart source contains Spacer() before (+N môn nữa)
  00:00 +1: SPEC-WIDGET-FOOTER-BADGE-PIN-BOTTOM-01 Acceptance Criteria Tests AC-01: Pinned Footer Badge in WidgetStudioScreen Live Preview Live preview renders Spacer and footer badge (+2 môn nữa) at bottom for 4 courses
  00:01 +2: SPEC-WIDGET-FOOTER-BADGE-PIN-BOTTOM-01 Acceptance Criteria Tests AC-02: Android Native XML & ScheduleWidgetProvider Parity widget_schedule_single_day.xml defines single_day_spacer with weight=1 before badge
  00:01 +3: SPEC-WIDGET-FOOTER-BADGE-PIN-BOTTOM-01 Acceptance Criteria Tests AC-02: Android Native XML & ScheduleWidgetProvider Parity ScheduleWidgetProvider.kt controls single_day_spacer visibility based on class count
  00:01 +4: SPEC-WIDGET-FOOTER-BADGE-PIN-BOTTOM-01 Acceptance Criteria Tests AC-03: iOS WidgetKit .systemMedium Timeline Parity ScheduleWidgetKit.swift places Spacer(minLength: 0) before (+N môn nữa) in .systemMedium
  00:01 +5: SPEC-WIDGET-FOOTER-BADGE-PIN-BOTTOM-01 Acceptance Criteria Tests AC-04: Clean Top-Aligned Layout when <= 2 courses Live preview renders cleanly without overflow or badge when 1 course
  00:01 +6: SPEC-WIDGET-FOOTER-BADGE-PIN-BOTTOM-01 Acceptance Criteria Tests AC-04: Clean Top-Aligned Layout when <= 2 courses Live preview renders cleanly without overflow or badge when exactly 2 courses
  00:01 +7: SPEC-WIDGET-FOOTER-BADGE-PIN-BOTTOM-01 Acceptance Criteria Tests AC-05: Parity & Integrity Preservation across All 3 Platforms All target files exist and maintain structure integrity
  00:01 +8: All tests passed!
  ```
- **Kết luận:** **8/8 test cases PASS (100%)**.

---

### 3.2. Test Suites Liên Quan & Kiểm Tra Hồi Quy (Regression Testing)
Thực hiện kiểm thử chéo toàn bộ các test suites phụ thuộc trong phân hệ Widget & Schedule:

1. **Batch 1 (Timeline & Widget Studio Core):**
   - Lệnh:
     ```bash
     flutter test test/timeline_widget_spec_test.dart test/inapp_schedule_card_multiline_and_widget_4x2_timeline_spec_test.dart test/widget_timeline_time_range_and_studio_mock_restore_spec_test.dart test/widget_studio_test.dart
     ```
   - Kết quả: **44/44 test cases PASS (100%)**.
   - Xác nhận:
     + Khôi phục mockup dữ liệu mẫu chuẩn và dải giờ bắt đầu - kết thúc hiển thị chính xác.
     + Không phát sinh RenderFlex overflow trên màn hình Live Preview Studio.
     + Toàn bộ 13 tiêu chí AC của Widget Studio hoạt động ổn định.

2. **Batch 2 (Widget Enhancements & Layout Alignment):**
   - Lệnh:
     ```bash
     flutter test test/widget_enhancement_spec_test.dart test/widget_cleanup_2x2_alignment_and_real_data_spec_test.dart test/hotfix_widget_overflow_and_load_test.dart
     ```
   - Kết quả: **26/26 test cases PASS (100%)**.
   - Xác nhận:
     + Bố cục top-aligned không bị ảnh hưởng tiêu cực bởi cơ chế spacer mới.
     + Loại bỏ triệt để các badge dư thừa như `[ĐÃ XONG]`.
     + Không xuất hiện lỗi tràn viền trên mọi kích thước màn hình test.

- **Tổng cộng kiểm thử động:** **78/78 test cases PASS (100%)**, **0 regression bug**.

---

## 4. MA TRẬN ĐỐI SOÁT TIÊU CHÍ NGHIỆM THU (ACCEPTANCE CRITERIA MATRIX)

| Mã AC | Mô tả tiêu chí nghiệm thu theo Spec | Phương pháp kiểm tra | Kết quả thực tế | Trạng thái |
| :--- | :--- | :--- | :--- | :---: |
| **AC-01** | **Ghim (+N môn nữa) sát đáy Footer trong Live Preview Studio**<br>- Sử dụng `Spacer()` đẩy dòng chú thích xuống sát mép dưới thẻ.<br>- Cân đối thị giác, không để khoảng trắng vô nghĩa dưới đáy. | - Static Code Review: `widget_studio_screen.dart:1243-1254`<br>- Widget Test: Render 4 môn, đo khoảng cách Y giữa đáy Môn 2 và đỉnh Badge (`badgePos.dy - course2Pos.dy > 15dp`). | `Spacer()` được chèn chính xác. Badge (+2 môn nữa) được đẩy sát đáy thẻ widget; delta Y đạt > 15dp. | **PASS** |
| **AC-02** | **Ghim single_day_badge sát đáy Footer trên Android Native (4x2)**<br>- `widget_schedule_single_day.xml` sử dụng phần tử co dãn `weight="1"` trước `single_day_badge`.<br>- RemoteViews safe: Không dùng tag cấm `<View>` hoặc `<Space>`.<br>- `ScheduleWidgetProvider.kt` bật spacer khi $\ge 3$ môn, ẩn khi $\le 2$ môn. | - XML Inspection: `single_day_spacer` dùng `<ImageView>` với `layout_weight="1"`.<br>- Regex Scan: 0 tag `<View>` bare.<br>- Kotlin Review: `single_day_spacer` được set `VISIBLE` khi `displayClasses.size > 2`, `GONE` khi $\le 2$. | Đầy đủ `single_day_spacer` (ImageView weight 1). RemoteViews whitelist an toàn tuyệt đối. Kotlin provider toggle chính xác. | **PASS** |
| **AC-03** | **Đồng bộ ghim Footer (+N môn nữa) trên iOS WidgetKit**<br>- `ScheduleWidgetKit.swift` (.systemMedium) đặt `Spacer()` trước dòng text đếm số môn còn lại, neo sát đáy thẻ 1:1 với Android. | - Swift Code Review: `ScheduleWidgetKit.swift:528`<br>- Parity Test: Xác nhận `Spacer(minLength: 0)` nằm trước `if displayClasses.count > 2`. | `Spacer(minLength: 0)` đứng trước block kiểm tra số môn. Neo sát đáy thẻ 1:1 với Android. | **PASS** |
| **AC-04** | **Bảo toàn hiển thị khi có 1 hoặc 2 môn học**<br>- Khi chỉ có 1 hoặc 2 môn học, layout vẫn căn dóng đỉnh (top-aligned) gọn gàng, không bị lỗi đẩy lệch hay vỡ layout. | - Widget Test: Render kịch bản 1 môn và 2 môn.<br>- Verify không xuất hiện badge `(+N môn nữa)` và không có lỗi overflow layout. | 1 hoặc 2 môn đều hiển thị đỉnh gọn gàng, không có khoảng cách méo mó, không xuất hiện badge phụ. | **PASS** |
| **AC-05** | **Bảo toàn Test Suite & Không gây Regression Bug**<br>- 100% bài test liên quan đến Studio Preview, XML Layout và Parity đều PASS. | - Chạy toàn bộ test suites của phân hệ Widget: 78 tests. | 78/78 test cases PASS 100%. 0 warning, 0 regression bug. | **PASS** |

---

## 5. KẾT LUẬN NGHIỆM THU (TEST SIGN-OFF)

- **Đánh giá tổng thể:**
  1. Dev2 đã hoàn thành chính xác 100% các yêu cầu kỹ thuật được đặc tả trong `SPEC-WIDGET-FOOTER-BADGE-PIN-BOTTOM-01`.
  2. Cấu trúc Footer Pin Bottom được đồng bộ đồng nhất trên cả 3 nền tảng: **Flutter Studio Live Preview**, **Android Native AppWidget XML & Kotlin Provider**, và **iOS SwiftUI WidgetKit**.
  3. Đảm bảo an toàn tuyệt đối về kiến trúc hệ thống (RemoteViews whitelist không lỗi, layout không bị overflow).
  4. 100% các tiêu chí nghiệm thu AC-01 đến AC-05 đều đạt chuẩn xuất sắc (Verified & Sign-off).

- **Kết luận:** **CHÍNH THỨC PHÊ DUYỆT NGHIỆM THU (SIGN-OFF: PASS 100%)**. Đủ điều kiện bàn giao cho BA và đóng vòng lặp phát triển kỹ thuật.
