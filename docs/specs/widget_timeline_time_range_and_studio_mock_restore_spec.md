# ĐẶC TẢ KỸ THUẬT (TECHNICAL SPECIFICATION)
## Phân Hệ: Tối Ưu Bố Cục Cột Trái Timeline Widget 4x2 & Khôi Phục Dữ Liệu Mẫu Chuẩn Cho Live Preview Widget Studio

- **Mã tài liệu:** `SPEC-WIDGET-TIMELINE-TIME-RANGE-AND-STUDIO-MOCK-RESTORE-01`
- **Phiên bản:** `1.0.0`
- **Tác giả:** Senior BA / Hermes Master Orchestrator
- **Dự án:** Trạm Kiến - Ứng dụng Quản lý Học tập & Lịch học HAU (Flutter / Android Kotlin / iOS Swift)
- **Tình trạng:** Chờ User duyệt (Pending Approval)

---

## 1. BỐI CẢNH & PHÂN TÍCH YÊU CẦU CỦA USER

### 1.1. Yêu cầu 1: Khắc phục sự trống trải ở Cột trái Widget 4x2 Timeline (Android & iOS)
- **Hiện trạng:**
  - Cột trái của Widget 4x2 hiện chỉ hiển thị duy nhất 1 mốc giờ bắt đầu (`12h45` hoặc `7h`), trong khi cột phải có tới 2 dòng nội dung (*Tên môn học* ở trên, *Phòng + Giảng viên* ở dưới).
  - Điều này khiến cột trái bị trống trải, mất cân đối chiều dọc với cột phải, và người dùng không biết ca học kéo dài đến mấy giờ thì kết thúc.
- **Giải pháp:**
  - Tối ưu cột trái thành cụm thời gian học hoàn chỉnh gồm **2 mốc giờ dóng hàng chuẩn**:
    + **Dòng 1 (Giờ bắt đầu):** `12:55` (hoặc `06:55`, font size `12.5sp - 13sp`, bold, mang màu Accent).
    + **Dòng 2 (Giờ kết thúc):** `17:05` (hoặc `11:55`, font size `9.5sp - 10sp`, chữ xám thanh lịch `textSecColor`).
  - Thanh trục Timeline Capsule ở giữa kéo dài phù hợp (`height="28dp"`), tạo trục thời gian trực quan nối liền giữa giờ bắt đầu và giờ kết thúc.
  - Đồng bộ 1:1 trên Android Native (`widget_schedule_single_day.xml`, `ScheduleWidgetProvider.kt`), iOS WidgetKit (`ScheduleWidgetKit.swift`) và Flutter Preview.

### 1.2. Yêu cầu 2: Khôi phục 100% Dữ liệu Mẫu (Mock Data) trong Live Preview Widget Studio
- **Hiện trạng:**
  - Ở lượt cập nhật trước, hàm `_initData` và `_refreshScheduleDataForMode` trong `WidgetStudioScreen.dart` đã đọc trực tiếp lịch thật từ SQLite nạp vào Live Preview, làm mất đi bộ dữ liệu mẫu chuẩn (Môn học 1, Môn học 2, Môn học 3, Môn học 4).
  - Người dùng yêu cầu: **Xưởng thiết kế Widget Studio luôn luôn hiển thị dữ liệu mẫu** để thuận tiện cho việc căn chỉnh màu sắc, nền và bố cục; không cần nút chuyển đổi dữ liệu thật trong studio.
  - Khi người dùng bấm nút **ÁP DỤNG**, hệ thống vẫn đọc dữ liệu thời khóa biểu thật từ SQLite `ScheduleDb` để ghi ra SharedPreferences / UserDefaults cho Native Widget ngoài Launcher.
- **Giải pháp:**
  - Khóa cứng `_isUsingSampleData = true` và luôn gọi `_buildFallbackPreviewData(_config.layoutMode)` cho Live Preview trong `WidgetStudioScreen.dart`.
  - Phân tách độc lập: Live Preview luôn dùng Mock Data; nút **ÁP DỤNG** luôn nạp Real Data từ SQLite ra Launcher.

---

## 2. CHI TIẾT KỸ THUẬT TRIỂN KHAI

### 2.1. Phân hệ 1: Bố cục Cột Trái 2 Mốc Giờ Trên Android Native
- **Tệp áp dụng:** 
  - `android/app/src/main/res/layout/widget_schedule_single_day.xml`
  - `android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt`
- **Cấu trúc XML cột trái (`widget_schedule_single_day.xml`):**
  - Cột thời gian chuyển thành `LinearLayout (vertical, width="46dp", gravity="start")`:
    + `single_class_1_time_start`: `TextView` giờ bắt đầu (ví dụ: `12:55`), cỡ chữ `12.5sp`, bold, màu Accent.
    + `single_class_1_time_end`: `TextView` giờ kết thúc (ví dụ: `17:05`), cỡ chữ `9.5sp`, màu `textSecColor`.
  - Trục `single_class_1_indicator`: Chiều cao `28dp` tương ứng trọn vẹn với 2 dòng text.
  - Tương tự cho Ca 2 (`single_class_2_time_start`, `single_class_2_time_end`, `single_class_2_indicator`).
- **Xử lý Kotlin (`ScheduleWidgetProvider.kt`):**
  - Hàm tách thời gian:
    + `extractStartTime(timeSlot)` $\rightarrow$ Giờ bắt đầu (`12:55` hoặc `06:55`).
    + `extractEndTime(timeSlot)` $\rightarrow$ Giờ kết thúc (`17:05` hoặc `11:55`).
  - Nạp chính xác vào `single_class_1_time_start` và `single_class_1_time_end`.

### 2.2. Phân hệ 2: Bố cục Cột Trái Trên iOS WidgetKit
- **Tệp áp dụng:** `ios/Runner/ScheduleWidgetKit.swift`
- **Triển khai nhánh `.systemMedium`:**
  - Cột trái:
    ```swift
    VStack(alignment: .leading, spacing: 1) {
        Text(extractStartTime(c.timeSlot))
            .font(.system(size: 12.5, weight: .bold))
            .foregroundColor(Color(hex: entry.accentColorHex) ?? .blue)
        Text(extractEndTime(c.timeSlot))
            .font(.system(size: 9.5, weight: .medium))
            .foregroundColor(Color(hex: entry.secondaryColorHex) ?? .gray)
    }
    .frame(width: 44, alignment: .leading)
    ```
  - Capsule indicator: `Capsule().frame(width: 3, height: 28)`.

### 2.3. Phân hệ 3: Khôi phục Dữ liệu Mẫu trong Widget Studio
- **Tệp áp dụng:** `lib/screens/widget_studio_screen.dart`
- **Triển khai:**
  - Khôi phục `_initData()` và `_refreshScheduleDataForMode()`: Luôn gán `_isUsingSampleData = true; _scheduleData = _buildFallbackPreviewData(_config.layoutMode);`.
  - Trong `_handleApply()`: Đọc `ScheduleDb.getLichHoc()` và `ScheduleDb.getLichThi()` để nạp dữ liệu thật của sinh viên vào `loadAndSyncFromDb` và đẩy ra Native Launcher.
  - Trong Live Preview 4x2 Timeline (`_buildSingleDay4x2TimelineContent`): Hiển thị đầy đủ giờ bắt đầu và giờ kết thúc ở cột trái đồng bộ với layout Native XML.

---

## 3. TIÊU CHÍ NGHIỆM THU (ACCEPTANCE CRITERIA - AC)

| Mã AC | Tiêu chí nghiệm thu | Tiêu chuẩn đánh giá |
| :--- | :--- | :--- |
| **AC-01** | **Cột trái Widget 4x2 hiển thị đầy đủ Giờ bắt đầu & Giờ kết thúc (Android)** | - `widget_schedule_single_day.xml` và `ScheduleWidgetProvider.kt` hiển thị 2 dòng thời gian (Bắt đầu trên, Kết thúc dưới).<br>- Trục Timeline Capsule cao 28dp cân đối hoàn hảo với 2 dòng nội dung cột phải. |
| **AC-02** | **Đồng bộ Cột trái 2 mốc giờ trên iOS WidgetKit (Swift)** | - `ScheduleWidgetKit.swift` nhánh `.systemMedium` hiển thị 2 dòng giờ (bắt đầu và kết thúc) kèm Capsule 28dp, Visual Parity 1:1 với Android. |
| **AC-03** | **Khôi phục 100% Dữ liệu Mẫu trong Live Preview Widget Studio** | - Live Preview trong Widget Studio luôn hiển thị dữ liệu mẫu chuẩn (Môn học 1, Môn học 2, Môn học 3, Môn học 4) trên mọi layout (1 ngày, 3 ngày, 7 ngày). |
| **AC-04** | **Bấm "ÁP DỤNG" đẩy chính xác Dữ liệu Thật ra Native Widget** | - Khi bấm "ÁP DỤNG", dữ liệu thời khóa biểu thật từ SQLite được ghi vào SharedPreferences / UserDefaults và kích hoạt cập nhật Native Widget ngoài Launcher. |
| **AC-05** | **Bảo toàn Test Suite & Không gây Regression Bug** | - Toàn bộ test suites liên quan đến Studio, Widget Provider và Parity đều PASS 100%. |

---

## 4. QUY TRÌNH ĐIỀU PHỐI TỰ ĐỘNG (AUTONOMOUS CLOSED-LOOP EXECUTION)

1. **Bước 1 (BA Spec):** User duyệt Spec.
2. **Bước 2 (Dev2 Code):** Tự động kích hoạt Sub-agent `dev2` lập trình toàn diện (Android XML/Kotlin + iOS Swift + Flutter Studio).
3. **Bước 3 (Tester Verify):** Tự động kích hoạt Sub-agent `tester` kiểm thử độc lập 2 tầng (Code diff review + Chạy test suite Terminal) và lập Test Report.
4. **Bước 4 (BA Sign-off):** BA đối soát toàn diện và nghiệm thu bàn giao lại cho User.
