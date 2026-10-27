# ĐẶC TẢ KỸ THUẬT (TECHNICAL SPECIFICATION)
## Phân Hệ: Tối Ưu Bố Cục Ghim Dòng (+N Môn Nữa) Xuống Footer Sát Đáy Thẻ Widget 4x2 (Đồng Bộ Android, iOS & Studio)

- **Mã tài liệu:** `SPEC-WIDGET-FOOTER-BADGE-PIN-BOTTOM-01`
- **Phiên bản:** `1.0.0`
- **Tác giả:** Senior BA / Hermes Master Orchestrator
- **Dự án:** Trạm Kiến - Ứng dụng Quản lý Học tập & Lịch học HAU (Flutter / Android Kotlin / iOS Swift)
- **Tình trạng:** Chờ User duyệt (Pending Approval)

---

## 1. BỐI CẢNH & PHÂN TÍCH HIỆN TRẠNG (ROOT CAUSE)

### 1.1. Hiện trạng từ hình ảnh thực tế của người dùng (`image_bd2e4e.png`)
- Trong giao diện Live Preview (và cả widget thật ngoài màn hình chính Android/iOS):
  - Khi ngày học có $\ge 3$ môn (hiển thị 2 môn đầu + dòng chú thích `(+2 môn nữa)`):
  - Dòng chữ `(+2 môn nữa)` hiện đang **nằm ngay bên dưới Môn học 2** với một khoảng cách dòng rất nhỏ (`marginTop="5dp"`).
  - Phía dưới dòng chữ này để lại một **khoảng trống rất lớn (chiếm 30% - 40% diện tích đáy thẻ)**.
  - Vị trí này không đúng với thiết lập chuẩn của một **Footer**: Dòng chú thích phụ cần được ghim sát cạnh đáy của thẻ (pinned to bottom), giúp phân tách rõ ràng giữa khu vực nội dung môn học và chân trang, tạo sự cân bằng thị giác và lấp đầy không gian hợp lý.

### 1.2. Nguyên nhân kỹ thuật trong mã nguồn
1. **Trong Flutter Widget Studio (`lib/screens/widget_studio_screen.dart:1230-1256`):**
   ```dart
   return Column(
     mainAxisAlignment: MainAxisAlignment.start,
     children: [
       ... hiển thị Môn 1 & Môn 2,
       if (classes.length > 2) Text('(+${classes.length - 2} môn nữa)'), // 💥 Nằm ngay sau Môn 2, không có Spacer đẩy xuống đáy!
     ],
   );
   ```
2. **Trong Android Native Layout XML (`widget_schedule_single_day.xml:285`):**
   - Thẻ `single_day_badge` nằm chung trong `single_day_content` (orientation `vertical`), không có `layout_weight="1"` hay thẻ đệm khoảng cách (`ImageView/Space`) để đẩy xuống đáy.
3. **Trong iOS WidgetKit (`ios/Runner/ScheduleWidgetKit.swift:529-535`):**
   - Dòng `Text("(+\(displayClasses.count - 2) môn nữa)")` nằm bên trong `VStack` chứa các môn học trước `Spacer(minLength: 0)`, dẫn đến việc nó bám dính lấy Môn 2 thay vì nằm sau `Spacer()` ở sát đáy.

---

## 2. GIẢI PHÁP KỸ THUẬT CHI TIẾT (ĐỒNG BỘ CẢ 3 NỀN TẢNG)

### 2.1. Phân hệ 1: Flutter Widget Studio (`lib/screens/widget_studio_screen.dart`)
- **Giải pháp:** Sử dụng `Spacer()` giữa danh sách môn học và dòng chú thích phụ:
  ```dart
  return Column(
    mainAxisAlignment: MainAxisAlignment.start,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (int i = 0; i < displayClasses.length; i++) ...[
        if (i > 0) const SizedBox(height: 8),
        _buildTimelineRow(...),
      ],
      if (classes.length > 2) ...[
        const Spacer(), // 🎯 Đẩy toàn bộ dòng (+N môn nữa) xuống sát đáy thẻ
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

### 2.2. Phân hệ 2: Android Native XML (`widget_schedule_single_day.xml`)
- **Giải pháp:**
  - Bổ sung thẻ đệm co dãn `ImageView` (hoặc `LinearLayout` trống) với `android:layout_width="match_parent"`, `android:layout_height="0dp"`, `android:layout_weight="1"` nằm giữa danh sách môn học và `single_day_badge`.
  - Hoặc đưa `single_day_badge` ra làm một hàng Footer độc lập ở đáy `single_day_content`.
  - Nhờ đó, `single_day_badge` luôn luôn được ghim sát viền dưới của thẻ widget, tạo bố cục Footer chuẩn mực.

### 2.3. Phân hệ 3: iOS WidgetKit (`ios/Runner/ScheduleWidgetKit.swift`)
- **Giải pháp:**
  - Đưa `Spacer(minLength: 0)` lên trước dòng `Text("(+\(displayClasses.count - 2) môn nữa)")`:
    ```swift
    // Danh sách 2 môn học đầu tiên
    ...
    Spacer(minLength: 0) // 🎯 Đẩy xuống đáy
    if displayClasses.count > 2 {
        Text("(+\(displayClasses.count - 2) môn nữa)")
            .font(.system(size: 8.5, weight: .bold))
            .foregroundColor(accent)
    }
    ```

---

## 3. TIÊU CHÍ NGHIỆM THU (ACCEPTANCE CRITERIA - AC)

| Mã AC | Tiêu chí nghiệm thu | Tiêu chuẩn đánh giá |
| :--- | :--- | :--- |
| **AC-01** | **Ghim (+N môn nữa) sát đáy Footer trong Live Preview Studio** | - `WidgetStudioScreen.dart` sử dụng `Spacer()` đẩy dòng chú thích xuống sát mép dưới của thẻ.<br>- Cân đối thị giác, không để hổng khoảng trắng lớn vô nghĩa dưới đáy. |
| **AC-02** | **Ghim single_day_badge sát đáy Footer trên Android Native (4x2)** | - `widget_schedule_single_day.xml` sử dụng phần tử co dãn `weight="1"` đẩy `single_day_badge` xuống đáy thẻ.<br>- Khoảng cách đáy widget chuẩn Swiss Padding (6dp - 8dp). |
| **AC-03** | **Đồng bộ ghim Footer (+N môn nữa) trên iOS WidgetKit** | - `ScheduleWidgetKit.swift` (.systemMedium) đặt `Spacer()` trước dòng text đếm số môn còn lại, neo sát đáy thẻ 1:1 với Android. |
| **AC-04** | **Bảo toàn hiển thị khi có 1 hoặc 2 môn học** | - Khi chỉ có 1 hoặc 2 môn học (không có môn thứ 3), layout vẫn căn dóng đỉnh gọn gàng, không bị lỗi đẩy lệch hay vỡ layout. |
| **AC-05** | **Bảo toàn Test Suite & Không gây Regression Bug** | - 100% bài test liên quan đến Studio Preview, XML Layout và Parity đều PASS. |

---

## 4. QUY TRÌNH ĐIỀU PHỐI TỰ ĐỘNG (AUTONOMOUS CLOSED-LOOP EXECUTION)

1. **Bước 1 (BA Spec):** User duyệt Spec.
2. **Bước 2 (Dev2 Code):** Tự động kích hoạt Sub-agent `dev2` lập trình cả 3 phân hệ (Flutter, Android XML, iOS Swift).
3. **Bước 3 (Tester Verify):** Tự động kích hoạt Sub-agent `tester` kiểm thử 2 tầng và xuất bản báo cáo nghiệm thu.
4. **Bước 4 (BA Sign-off):** BA đối soát và bàn giao lại cho User.
