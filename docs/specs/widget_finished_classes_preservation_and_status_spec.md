# ĐẶC TẢ KỸ THUẬT (TECHNICAL SPECIFICATION)
## Phân Hệ: Khắc Phục Lỗi Widget Báo Sai "Không Có Lịch / Hôm Nay Nghỉ" Khi Ca Học Đã Qua (Đồng Bộ Android & iOS)

- **Mã tài liệu:** `SPEC-WIDGET-FINISHED-CLASSES-PRESERVATION-AND-STATUS-01`
- **Phiên bản:** `1.0.0`
- **Tác giả:** Senior BA / Hermes Master Orchestrator
- **Dự án:** Trạm Kiến - Ứng dụng Quản lý Học tập & Lịch học HAU (Flutter / Android / iOS)
- **Tình trạng:** Chờ User duyệt (Pending Approval)

---

## 1. BỐI CẢNH & NGUYÊN NHÂN GỐC RỄ (ROOT CAUSE ANALYSIS)

### 1.1. Bằng chứng thực tế từ hình ảnh người dùng:
1. **Trong ứng dụng (`image_639eaf.png`):** Thứ Hai ngày 26/10 có 1 ca học chiều từ `12:55 - 17:05` môn *"Kho dữ liệu và khai phá dữ liệu"*.
2. **Trên Widget Android & iOS (`image_b8f365.png` & `image_0b1133.png`):**
   - Widget "Lịch hôm nay" báo: `[SẮP TỚI] Hôm nay nghỉ`.
   - Widget "Lịch 3 ngày": Ngày T2 26/10 báo `Không có lịch`.
   - Widget "Lịch tuần" (4x4): Ô T2 26/10 báo `Không có lịch`, ô "Tổng kết tuần" đếm nhầm T2 là ngày trống (báo `3 ngày trống` thay vì 2 ngày trống).

### 1.2. Nguyên nhân gốc rễ trong mã nguồn:
- **Tầng dữ liệu dùng chung (`lib/services/widget_data_sync_service.dart:623`):**
  Tại hàm `_extractClassesForDate`:
  ```dart
  if (isTargetToday && isFinished) {
    continue; // 💥 TỰ ĐỘNG XÓA BỎ CA HỌC ĐÃ KẾT THÚC KHỎI DANH SÁCH CLASSES!
  }
  ```
- **Hậu quả:**
  - Sau khi ca học kết thúc (`now > gioKetThuc`), lệnh `continue` loại bỏ hoàn toàn ca học này khỏi danh sách `classes` của ngày hôm nay.
  - Gói dữ liệu JSON xuất ra cho Android (`SharedPreferences`) và iOS (`UserDefaults AppGroup`) đều có `classes: []` (mảng rỗng).
  - Tầng Native Android (`ScheduleWidgetProvider.kt`) và iOS (`ScheduleWidgetKit.swift`) kiểm tra `classes.isEmpty` và rơi thẳng vào nhánh hiển thị *"Không có lịch"* hoặc *"Hôm nay nghỉ"*, gây hiểu lầm nghiêm trọng rằng hôm nay là ngày nghỉ rảnh rỗi.

---

## 2. PHẠM VI & GIẢI PHÁP KỸ THUẬT CHI TIẾT

### 2.1. Phân hệ 1: Bảo toàn dữ liệu ca học tại Service lõi (`WidgetDataSyncService.dart`)
- **Tệp áp dụng:** `lib/services/widget_data_sync_service.dart`
- **Giải pháp:**
  - **XÓA BỎ HOÀN TOÀN** điều kiện `if (isTargetToday && isFinished) continue;`.
  - Giữ nguyên toàn bộ các ca học của ngày hôm nay trong mảng `classes`.
  - Đánh dấu chính xác thuộc tính `isFinished: true` khi `currentMinuteOfDay > endMinuteOfDay` (và `isCurrentOrNext: false`).
  - **Hiệu quả:**
    - Widget Tuần (4x4) và Widget 3 ngày nhận được đầy đủ các ca học của ngày hôm nay.
    - Ô "Tổng kết tuần" tính đúng 100% số ca học thực tế trong tuần, không bị đếm nhầm thành ngày trống.

### 2.2. Phân hệ 2: Xử lý hiển thị thông minh trên Android Native (`ScheduleWidgetProvider.kt`)
- **Tệp áp dụng:** `android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt`
- **Chi tiết triển khai:**
  1. **Widget 7 Ngày (Weekly Grid 4x4) & Widget 3 Ngày (4x2):**
     - Khi `dayObj` có `classes.length > 0`: Vẫn hiển thị tên môn học và giờ học bình thường.
     - Nếu môn học đã kết thúc (`is_finished == true`):
       + Tên môn học và giờ học được chuyển sang màu xám mờ thanh lịch (`textSecColor` hoặc `isDimmed`), thể hiện ca học **đã hoàn thành**, tuyệt đối không báo *"Không có lịch"*.
  2. **Widget Lịch hôm nay (4x2 Timeline & 2x2 Thu gọn):**
     - Phân biệt 2 trạng thái rõ ràng:
       + **Trường hợp thật sự không có lịch học:** Cả ngày không có môn nào trong TKB $\rightarrow$ Hiển thị `"Hôm nay nghỉ"`.
       + **Trường hợp đã học xong tất cả các ca hôm nay:** Tất cả các ca đều có `is_finished == true` $\rightarrow$ Hiển thị tên ca học vừa hoàn thành với nhãn/badge **`[ĐÃ XONG]`** (hoặc thông báo thanh lịch *"Đã hoàn thành các ca học hôm nay"*), không báo *"Hôm nay nghỉ"*.

### 2.3. Phân hệ 3: Xử lý hiển thị thông minh trên iOS WidgetKit (`ScheduleWidgetKit.swift`)
- **Tệp áp dụng:** `ios/Runner/ScheduleWidgetKit.swift`
- **Chi tiết triển khai:**
  1. **Weekly Grid 4x4 (`DayGridCellView`):**
     - Đọc cờ `isFinished`. Nếu ca học đã kết thúc, vẫn hiển thị tên môn và chi tiết với màu xám mờ `.foregroundColor(.gray.opacity(0.7))`. Không hiển thị *"Không có lịch"*.
  2. **SystemSmall (2x2) & SystemMedium (4x2):**
     - Nếu toàn bộ ca học trong ngày đã xong: Hiển thị badge mờ `ĐÃ XONG` hoặc tên môn học với chỉ báo hoàn thành, đồng bộ Visual Parity 1:1 với Android.

### 2.4. Phân hệ 4: Đồng bộ Live Preview trong Widget Studio (`widget_studio_screen.dart`)
- **Tệp áp dụng:** `lib/screens/widget_studio_screen.dart`
- **Chi tiết triển khai:**
  - Đồng bộ logic xử lý ca học đã hoàn thành (`isFinished`) trong Live Preview 1 ngày, 3 ngày và 7 ngày, đảm bảo những gì người dùng thấy trong Studio giống hệt ngoài màn hình chính.

---

## 3. TIÊU CHÍ NGHIỆM THU (ACCEPTANCE CRITERIA - AC)

| Mã AC | Tiêu chí nghiệm thu | Tiêu chuẩn đánh giá |
| :--- | :--- | :--- |
| **AC-01** | **Bảo toàn 100% dữ liệu ca học đã kết thúc trong ngày tại Service** | - `WidgetDataSyncService.dart` không còn lệnh `continue` xóa ca học.<br>- Mọi ca học hôm nay (kể cả đã qua giờ kết thúc) đều được giữ lại trong `classes` với cờ `isFinished: true`. |
| **AC-02** | **Widget Tuần (4x4) & Widget 3 Ngày hiển thị ca học đã xong thay vì "Không có lịch" (Android)** | - Khi ca học hôm nay đã kết thúc, ô Hôm nay vẫn hiển thị tên môn học với trạng thái hoàn thành / làm mờ (dimmed).<br>- Ô "Tổng kết tuần" tính đủ số buổi học trong tuần, không đếm nhầm thành ngày trống. |
| **AC-03** | **Widget "Lịch hôm nay" (1 Ngày & 2x2) phân biệt rõ "Hôm nay nghỉ" vs "Đã học xong" (Android)** | - Khi không có lịch: hiển thị `"Hôm nay nghỉ"`.<br>- Khi đã học xong tất cả các ca trong ngày: hiển thị tên môn học kèm chỉ báo `[ĐÃ XONG]` / hoàn thành, không báo `"Hôm nay nghỉ"`. |
| **AC-04** | **Đồng bộ hóa hiển thị trên iOS WidgetKit (Swift)** | - `ScheduleWidgetKit.swift` không hiển thị `"Không có lịch"` khi ngày hôm nay có ca học đã xong.<br>- Hiển thị tên môn ở trạng thái mờ (dimmed) / hoàn thành trên cả `.systemSmall`, `.systemMedium`, `.systemLarge`. |
| **AC-05** | **Đồng bộ Live Preview trong Widget Studio** | - `WidgetStudioScreen.dart` hiển thị visual parity 1:1 khi mô phỏng ca học đã hoàn thành. |
| **AC-06** | **Kiểm thử hồi quy & Bảo toàn Test Suite** | - Toàn bộ unit/widget test suites liên quan đến Widget Sync, Rolling Window, Tomorrow và Widget Studio đều PASS 100%. |

---

## 4. QUY TRÌNH ĐIỀU PHỐI TỰ ĐỘNG (AUTONOMOUS CLOSED-LOOP EXECUTION)

1. **Bước 1 (BA Spec):** User duyệt Spec.
2. **Bước 2 (Dev2 Code):** Tự động kích hoạt Sub-agent `dev2` (Flutter / Android Kotlin / iOS Swift) sửa chữa triệt để.
3. **Bước 3 (Tester Verify):** Tự động kích hoạt Sub-agent `tester` kiểm thử 2 tầng (Code diff review + chạy Terminal tests) và lập Test Report.
4. **Bước 4 (BA Sign-off):** BA đối soát toàn diện và nghiệm thu bàn giao lại cho User.
