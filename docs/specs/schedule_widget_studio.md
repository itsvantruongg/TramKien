# Technical Specification: Hệ Thống Widget Lịch Học Đa Nền Tảng, Xưởng Tùy Biến (Widget Studio) & Trải Nghiệm Màn Hình Khóa

- **Mã tài liệu:** SPEC-WIDGET-STUDIO-02
- **Phân hệ:** OS Widget System, Home Screen & Lock Screen Integration, UI Customization Engine, In-App Onboarding
- **Tác giả:** Senior Business Analyst & Software Architect
- **Trạng thái:** Approved by User / Ready for Implementation

---

## 1. YÊU CẦU NGHIỆP VỤ & PHẠM VI HỆ THỐNG (BUSINESS REQUIREMENTS & SCOPE)

### 1.1. Mục tiêu sản phẩm
1. **Trải nghiệm Zero-Friction (Liếc nhìn là hiểu):** Sinh viên không cần mở khóa máy hoặc mở app vẫn theo dõi được ca học tiếp theo, phòng học và thời khóa biểu toàn tuần.
2. **Thẩm mỹ Tối giản chuẩn Thụy Sĩ (Swiss Typography):** Tuyệt đối **không dùng emoji hay icon màu mè**. Sử dụng phân cấp kiểu chữ (Bold/Regular), căn lề sắc nét, vạch kẻ hairline `0.5dp` và vạch Accent `3dp`.
3. **Cá nhân hóa theo ảnh nền:** Hỗ trợ tùy chỉnh màu sắc, độ trong suốt ($0\%$ đến $100\%$) và hiệu ứng **Kính mờ độc quyền của hệ thống (iOS System Native Glassmorphism / Frosted Glass)**.
4. **Bảo toàn dữ liệu lớp tín chỉ:** Cụm mã lớp học phần (ví dụ: `TH4327_23CN 2`) được hiển thị nguyên vẹn cả cụm khi người dùng bật tùy chọn.
5. **Hiệu năng Offline-First:** Widget chạy $100\%$ từ dữ liệu lưu cục bộ, thời gian render $< 50\text{ms}$, không gọi mạng khi vẽ giao diện.

---

## 2. QUY TẮC HIỂN THỊ & MỐC THỜI GIAN ĐẢO LỊCH (SMART TIME-WINDOW ENGINE)

### 2.1. Ma trận xử lý thời gian (Time-Window Matrix)

| Chế độ Widget | Kích cỡ chuẩn | Quy tắc lúc 20:00 tối | Quy tắc lúc 00:00 (Nửa đêm) |
| :--- | :--- | :--- | :--- |
| **1 Ngày (Smart)** | Medium (4x2) | **Đảo lịch sang Ngày mai:** Tiêu đề đổi thành `LỊCH HỌC NGÀY MAI`, nạp toàn bộ ca học của ngày kế tiếp. | **Trở về Hôm nay:** Tiêu đề đổi thành `LỊCH HỌC HÔM NAY` của ngày mới, đánh dấu ca sáng tiếp theo. |
| **3 Ngày (Rolling)** | Medium (4x2) / Large (4x3) | **Làm mờ ca học hôm nay:** Chuyển màu chữ ngày hôm nay sang mờ nhẹ (Opacity 50%, **tuyệt đối KHÔNG gắn nhãn `[ĐÃ XONG]`**), nổi bật ngày mai. | **Cuộn cửa sổ (Rolling Window):** Ngày cũ biến mất, Ngày mai trở thành Hôm nay, nạp thêm 1 ngày mới ở cuối. |
| **7 Ngày (Weekly)** | Large (4x4) | *Ngày thường:* Giữ nguyên.<br>*Tối Chủ nhật lúc 20:00:* **Lật sang Tuần mới**, nạp thời khóa biểu tuần kế tiếp. | **Dịch chuyển vạch Today:** Vạch Accent Color và chữ Bold nhảy sang Thứ mới. Các thứ đã qua chuyển sang màu xám mờ. |

---

## 3. ĐẶC TẢ HỢP ĐỒNG DỮ LIỆU (SHARED JSON CONTRACTS)

### 3.1. Cấu hình giao diện Widget (`widget_theme_config.json`)
```json
{
  "layout_mode": "single_day",
  "bg_style": "system_glass",
  "bg_color_hex": "#1C1C1E",
  "bg_opacity": 0.72,
  "text_primary_hex": "#FFFFFF",
  "text_secondary_hex": "#98989D",
  "accent_color_hex": "#1D64F2",
  "show_room": true,
  "show_time": true,
  "show_teacher": false,
  "show_class_code": true,
  "enable_lockscreen_notification": false
}
```
*Ghi chú `enable_lockscreen_notification`:*
- Mặc định là `false` (không tự ý đẩy thông báo lên thanh trạng thái máy). Chỉ kích hoạt khi sinh viên chủ động bật trong màn hình cài đặt widget.
*Ghi chú `bg_style`:*
- `system_glass`: Chế độ kính mờ độc quyền của hệ thống (iOS Native Material `.ultraThinMaterial` / Android Blur Shape).
- `frosted_glass`: Nền mờ tùy chỉnh theo mã màu `bg_color_hex` và `bg_opacity`.
- `transparent`: Nền trong suốt 100% (`#00000000`).
- `solid`: Nền màu đặc $100\%$ không xuyên thấu.

### 3.2. Dữ liệu lịch học trích xuất (`widget_schedule_data.json`)
```json
{
  "updated_at": "2026-10-19T20:00:00.000",
  "widget_title": "LỊCH HỌC NGÀY MAI",
  "widget_subtitle": "THỨ BA, 20/10/2026",
  "layout_mode": "single_day",
  "days": [
    {
      "day_label": "NGÀY MAI",
      "date_str": "20/10",
      "weekday_str": "T3",
      "is_today": false,
      "is_dimmed": false,
      "classes": [
        {
          "course_name": "Đồ án Kiến trúc 1",
          "class_code": "TH4327_23CN 2",
          "time_slot": "13:00 - 15:25 (T7-9)",
          "room": "P.A401",
          "teacher": "Trần Văn C",
          "is_current_or_next": true,
          "is_finished": false
        }
      ]
    }
  ]
}
```

---

## 4. ĐẶC TẢ GIAO DIỆN & CÔNG NGHỆ THỰC THI (IMPLEMENTATION SPECS)

### 4.1. Màn hình Xưởng Widget trong App (`WidgetStudioScreen`)
- **Vị trí:** Mở từ màn hình Tài khoản (Profile) hoặc Cài đặt.
- **Thành phần giao diện:**
  1. *Thiết kế Nền Sáng (Light Theme):* Toàn bộ màn hình sử dụng màu nền trắng sáng thanh lịch `AppTheme.surface` (`#F8F9FA`), AppBar trắng sáng với chữ đen than `#1A1A1A`. Các khối tùy chọn nằm trên thẻ trắng `SurfaceCard` bo góc 12dp, viền mỏng xám nhạt đồng bộ tuyệt đối với toàn bộ ứng dụng Trạm Kiến.
  2. *Khung Live Preview & Cơ chế Dữ liệu Mẫu (Sample Preview Disambiguation):*
     - Nửa trên màn hình, mô phỏng đúng tỉ lệ 4x2 và 4x4 trên nền giả lập ảnh điện thoại có thể đổi hình nền để kiểm tra độ trong suốt.
     - **Minh bạch hóa Dữ liệu Mẫu (Bắt buộc):** Khi tài khoản chưa có lịch học hoặc ngày được chọn không có môn, Live Preview nạp các môn học mẫu để người dùng có thể thử màu sắc/bố cục. Tuy nhiên, hệ thống **bắt buộc phải hiển thị rõ ràng**:
       * Thẻ Tag nổi bật: `[ DỮ LIỆU MẪU - XEM TRƯỚC ]` (màu hổ phách Amber viền sáng) trên góc khung Preview.
       * Tên môn học mẫu được gắn tiền tố rõ ràng: `(Môn mẫu) Kiến trúc máy tính`, `(Môn mẫu) Lập trình Flutter`.
       * Dòng thông báo chú thích nhỏ dưới khung Preview: `* Lưu ý: Đây là dữ liệu mẫu để bạn xem trước bố cục. Khi ra Màn hình chính, Widget sẽ hiển thị đúng thời khóa biểu thực tế của bạn.`
     - Khi tài khoản có lịch thật: hiển thị 100% lịch thật và tự động ẩn nhãn `[ DỮ LIỆU MẪU ]`.
  3. *Bộ chọn Chế độ hiển thị:* 3 Segmented Buttons: `[ 1 Ngày ]`, `[ 3 Ngày ]`, `[ 7 Ngày ]`.
  4. *Bộ chọn Kiểu nền:* 4 Lựa chọn:
     - `[ Kính mờ Hệ thống (iOS Glassmorphism) ]` (Khuyên dùng)
     - `[ Kính mờ Tự chọn ]`
     - `[ Trong suốt 100% ]`
     - `[ Màu đặc ]`
  5. *Thanh trượt Độ trong suốt (Opacity Slider):* Từ $0\%$ đến $100\%$.
  6. *Bộ màu (Color Pickers):* Màu nền, màu chữ chính, màu điểm nhấn (Accent Line).
  7. *Công tắc hiển thị (Field Switches):*
     - `[x] Hiện Phòng học`
     - `[x] Hiện Khung giờ & Tiết học`
     - `[ ] Hiện Tên Giảng viên`
     - `[x] Hiện Mã lớp học phần (nguyên vẹn TH4327_23CN 2)`
     - `[ ] Hiển thị thẻ lịch học ngoài Màn hình khóa & AOD` (Mặc định: TẮT - Opt-in cho Android).
  8. *4 Presets mẫu 1 chạm:* Tối giản Thụy Sĩ, Kính mờ tự nhiên, Trong suốt (Ghost Mode), Cyberpunk/Neon.
  9. *Luồng bấm Áp dụng:*
     - Lưu `SharedPreferences`.
     - Kích hoạt cập nhật native widget tức thì.
     - Kích hoạt yêu cầu ghim widget của hệ điều hành `requestPinWidget()`.
     - Tuyệt đối KHÔNG tự ý đẩy thông báo lên thanh thông báo tổng trừ khi công tắc `enable_lockscreen_notification` được người dùng chủ động bật.
     - Hiển thị hộp thoại xác nhận lưu thành công kèm hướng dẫn thao tác đưa widget ra màn hình thủ công.

### 4.2. Màn hình Lịch học (`lib/screens/schedule_screen.dart`)
- Bổ sung **Thẻ gợi ý Widget (In-App Hint Banner)** ở đầu danh sách lịch học:
  - Text: `💡 Mẹo: Bạn có thể đưa Lịch học ra Màn hình chính hoặc Màn hình khóa để liếc nhanh ca học mỗi ngày.`
  - Nút bấm `[ Thử ngay ]`: Mở thẳng `WidgetStudioScreen`.
  - Nút đóng `[ X ]`: Ghi nhớ cờ `widget_banner_dismissed = true` trong `SharedPreferences` và ẩn banner vĩnh viễn.

### 4.3. Tầng Native Android & iOS
- **Điểm chạm thông minh (Smart Touch-Zones):**
  - Chạm vào thân ca học: Mở app vào Tab Lịch học (`target_tab = 1`).
  - Chạm vào nút chỉnh sửa ở góc trên widget: Mở thẳng Xưởng Widget (`route = /widget_studio`) để đổi màu trong 3 giây.
- **Tầng Native Android (`android/app/...`):**
  - Kích cỡ 4x2 (`widget_schedule_single_day.xml`) cho 1 ngày và 3 ngày, có nút góc mở Widget Studio.
  - Kích cỡ 4x4 (`widget_schedule_weekly.xml`) cho 7 ngày có `ListView` cuộn danh sách mượt mà.
  - Hỗ trợ đổi màu nền, độ mờ ARGB và ghim widget tự động.
- **Tầng Native iOS (`ios/...`):**
  - SwiftUI WidgetKit kích cỡ `systemMedium` (4x2) và `systemLarge` (4x4), hỗ trợ kính mờ hệ thống `.ultraThinMaterial`.
  - Màn hình khóa: Chuẩn Apple Vibrancy đơn sắc 2 dòng.

---

## 5. TIÊU CHUẨN NGHIỆM THU (ACCEPTANCE CRITERIA - AC CHECKLIST)

- [ ] **AC-01 (Widget Studio Light Theme):** Màn hình Xưởng Widget hiển thị với màu nền trắng sáng đồng bộ (`AppTheme.surface`), các thẻ điều khiển màu trắng nổi bật, chữ màu tối tương phản rõ ràng.
- [ ] **AC-02 (Sample Preview Disambiguation):** Khi Live Preview nạp môn mẫu (do database trống hoặc ngày không có lịch), hiển thị rõ ràng nhãn `[ DỮ LIỆU MẪU - XEM TRƯỚC ]`, tiền tố `(Môn mẫu) ` và dòng chú thích giải thích. Khi có lịch thật, tự động hiển thị lịch thật và ẩn nhãn mẫu.
- [ ] **AC-03 (Apply Flow & Notification Separation):** Khi bấm "Áp dụng", hệ thống lưu cấu hình và kích hoạt pin widget, TUYỆT ĐỐI KHÔNG tự ý đẩy thông báo lên thanh thông báo tổng. Chỉ khi người dùng bật công tắc `enable_lockscreen_notification` thì mới kích hoạt thẻ ghim màn hình khóa.
- [ ] **AC-04 (Full Class Code Retention):** Chuỗi `tenLopTinChi` (ví dụ `TH4327_23CN 2`) được lưu trữ và hiển thị nguyên vẹn cả cụm khi bật công tắc Hiện Mã lớp HP.
- [ ] **AC-05 (In-App Hint Banner):** Màn hình Lịch học hiển thị banner gợi ý tiện ích với nút [Thử ngay] mở Widget Studio và nút [X] đóng banner vĩnh viễn.
- [ ] **AC-06 (Smart Touch-Zones & Deep Link):** Nhấn vào góc chỉnh sửa của widget mở thẳng màn hình Xưởng Widget; nhấn vào thân môn học mở màn hình Lịch học.
- [ ] **AC-07 (Time-Window Engine):** 1 ngày tự động đổi sang Ngày mai lúc 20:00 tối; 3 ngày làm mờ ngày hôm nay sau 20:00 (không có nhãn `[ĐÃ XONG]`); 7 ngày nhảy vạch lúc 00:00 và lật tuần mới lúc 20:00 tối Chủ nhật.
- [ ] **AC-08 (No Emojis):** Toàn bộ giao diện widget tuân thủ phong cách tối giản Thụy Sĩ, không có bất kỳ emoji hay icon màu mè nào.
- [ ] **AC-09 (Automated Tests):** Chạy `flutter test` đảm bảo 100% test cases đều PASS (bao gồm các test case mới cho AC-01 đến AC-08).
