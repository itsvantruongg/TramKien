# Technical Specification: Đại Phẫu Nền Vector XML Native, Triệt Tiêu Méo Góc Khi Resize & Tinh Chỉnh Bố Cục Chuẩn Swiss

- **Mã tài liệu:** SPEC-NATIVE-VECTOR-WIDGET-01
- **Phân hệ:** Native Android AppWidget, XML Vector Drawables, Layout Geometry, Concentric Padding, Swiss Design System
- **Tác giả:** Master Orchestrator & Senior Business Analyst
- **Đối chiếu chuẩn:** Google Android Guidelines (`res/drawable/` vector shapes, `res/values-v31`), Apple HIG, và 3 repository quy chuẩn (`homescreen_codelab`, `home_widget`, `flutter-home-widget-vignette`)
- **Trạng thái:** Approved by User / Ready for Implementation

---

## 1. MỤC TIÊU KỸ THUẬT & PHẠM VI XỬ LÝ (SCOPE & GOALS)

### 1.1. Nguyên nhân gốc rễ (Root Cause Analysis)
1. **Méo góc elip do kéo dãn Bitmap tĩnh (`scaleType="fitXY"`):**
   - Hiện tại, `ScheduleWidgetProvider.kt` tạo ra một tấm ảnh Bitmap cố định trong bộ nhớ RAM và ném vào `ImageView` (`id: widget_bg_image`) với thuộc tính `android:scaleType="fitXY"`.
   - Khi người dùng kéo resize widget trên Launcher (như trên máy ảo Pixel 5 chạy Android 10 API 29), hệ điều hành cưỡng bức kéo dãn ảnh theo 2 trục X và Y không đồng đều. Bán kính cong tròn $16\text{dp}$ bị bẹp dí thành hình elip (oval), đường viền stroke bị dày mỏng lệch lạc.
   - **Quy chuẩn của Google (`homescreen_codelab/step_06`):** Google **KHÔNG BAO GIỜ** dùng Bitmap cho nền card. Họ dùng trực tiếp **XML Shape Drawable** (`@drawable/widget_card_rounded_bg`) gán vào `android:background` của View container. XML Shape là đồ họa vector được GPU render theo thời gian thực: dù kéo bất kỳ kích cỡ hay tỉ lệ nào, 4 góc bo luôn là cung tròn $90^\circ$ hoàn hảo với bán kính đúng $16\text{dp}$, viền stroke luôn đều đặn $0.5\text{dp}$ - $1\text{dp}$.

2. **Viền xanh bất thường (Loud Blue Outline):**
   - Viền xanh dương đậm bao quanh widget là do thuộc tính `border_color_hex` hoặc logic vẽ viền stroke nổi bật quá mức. Theo chuẩn Swiss Minimalist & Apple HIG: Widget phải hòa vào hình nền với viền hairline mờ siêu mảnh $0.5\text{dp}$ (`#26FFFFFF` trên nền tối, `#CBD5E1` trên nền sáng), không dùng viền xanh sặc sỡ đóng hộp thô cứng.

3. **Lỗi cấn góc ở Widget 4x4 (Weekly Grid 8 Ô):**
   - Hàng ô thứ 4 (Thứ 7 & Tổng kết tuần) bị đẩy sát mép đáy viền ngoài, vi phạm quy tắc đồng tâm $R_{ngoài} = R_{trong} + Padding$.

4. **Lỗi cắt cụt tiêu đề ở Widget 2x2 (`Lịch hôm... 24/10`):**
   - Khi widget 2x2 bị kéo thành cột hẹp (ví dụ 2 cột x 3 hàng), `widget_title` và `widget_subtitle` đứng chung 1 hàng ngang bị chật chội, dẫn đến chữ bị cắt cụt.

---

## 2. GIẢI PHÁP THỰC THI (DETAILED IMPLEMENTATION)

### 2.1. Chuyển Đổi Hoàn Toàn Sang Nền XML Vector Shape
1. **Tối ưu các file XML Shape trong `android/app/src/main/res/drawable/`:**
   - `widget_card_rounded_bg.xml`: Nền tối mờ chuẩn (`#C81C1C1E` hoặc `#D91C1C1E`), bo góc $16\text{dp}$, viền hairline $0.5\text{dp}$ (`#26FFFFFF`).
   - `widget_card_rounded_solid.xml`: Nền đen đặc (`#FF1C1C1E`), bo góc $16\text{dp}$, viền hairline $0.5\text{dp}$ (`#26FFFFFF`).
   - `widget_card_rounded_light.xml`: Nền sáng (`#F8F9FA`), bo góc $16\text{dp}$, viền hairline $0.5\text{dp}$ (`#CBD5E1`).
   - `widget_card_rounded_transparent.xml`: Nền trong suốt (`#00000000`), bo góc $16\text{dp}$, viền hairline $0.5\text{dp}$ (`#33FFFFFF`).
2. **Trong `ScheduleWidgetProvider.kt`:**
   - Khi không có ảnh chụp từ thư viện (`custom_bg_image_path` rỗng):
     - **ẨN hoàn toàn `widget_bg_image`** (`views.setViewVisibility(R.id.widget_bg_image, View.GONE)`).
     - Gán trực tiếp XML Shape Drawable vào container nền:
       ```kotlin
       val bgRes = when {
           bgStyle == "transparent" -> R.drawable.widget_card_rounded_transparent
           bgStyle == "solid" && isLightBg -> R.drawable.widget_card_rounded_light
           bgStyle == "solid" -> R.drawable.widget_card_rounded_solid
           isLightBg -> R.drawable.widget_card_rounded_light
           else -> R.drawable.widget_card_rounded_bg
       }
       views.setInt(R.id.widget_root, "setBackgroundColor", Color.TRANSPARENT)
       views.setInt(android.R.id.background, "setBackgroundResource", bgRes)
       ```
     - Với trường hợp người dùng chọn ảnh cá nhân từ thư viện (`customBgPath` hợp lệ): dùng `widget_bg_image` với Center-Crop bo góc.
3. **Triệt tiêu viền xanh bao quanh:**
   - Chuẩn hóa màu viền mặc định thành viền hairline siêu mảnh đồng bộ theme (`#26FFFFFF` / `#CBD5E1`), không để viền xanh dương xuất hiện quanh mép ngoài widget.

### 2.2. Khắc Phục Lỗi Cấn Góc Trên Widget 4x4 (`widget_schedule_weekly.xml`)
- Trong `widget_schedule_weekly.xml`:
  - Điều chỉnh `android:padding="12dp"` trên LinearLayout content bên trong `@android:id/background`.
  - Đảm bảo hàng ô thứ 4 (Ô 7 và Ô 8) có khoảng đệm cách mép đáy viền cong ít nhất $12\text{dp}$, đảm bảo bán kính bo góc trong $8\text{dp}$ và bán kính ngoài $16\text{dp}$ song song đồng tâm tuyệt đối.

### 2.3. Tối Ưu Tiêu Đề Widget 2x2 Chống Cắt Cụt Chữ
- Trong `ScheduleWidgetProvider.kt` và `widget_schedule_single_day_2x2.xml`:
  - Khi chiều ngang hẹp hoặc trong bố cục 2x2: Cho phép tiêu đề co giãn linh hoạt hoặc hiển thị ngắn gọn `Lịch hôm nay` / ngày tháng phân tách hợp lý, không để xảy ra hiện tượng cắt cụt chữ `Lịch hôm...`.
  - Căn giữa nội dung theo chiều dọc mượt mà khi người dùng kéo dài widget 2x2.

---

## 3. TIÊU CHUẨN NGHIỆM THU (ACCEPTANCE CRITERIA - AC)

- [ ] **AC-01 (Native Vector XML Background on Android):**
  - Mọi widget ở các chế độ chuẩn (không dùng ảnh từ máy) sử dụng trực tiếp XML Shape Drawable (`widget_card_rounded_bg.xml`, `widget_card_rounded_light.xml`, etc.) gán vào `android.R.id.background`.
  - `widget_bg_image` được ẩn đi (`View.GONE`), không còn hiện tượng dùng Bitmap `fitXY` làm nền mặc định.
- [ ] **AC-02 (Zero Corner Distortion Across All Aspect Ratios):**
  - Khi resize widget trên bất kỳ tỉ lệ nào (ngang, dọc, vuông, trên cả Android 10 API 29 lẫn Android 12+), 4 góc bo của widget luôn là cung tròn chuẩn $16\text{dp}$, đường viền stroke luôn đều đặn $0.5\text{dp}$, triệt tiêu 100% hiện tượng elip méo.
- [ ] **AC-03 (Hairline Minimalist Border Parity):**
  - Loại bỏ hoàn toàn đường viền xanh dương sặc sỡ bao quanh mép ngoài widget. Viền ngoài tuân thủ chuẩn Swiss Minimalist với nét hairline $0.5\text{dp}$ mờ thanh lịch.
- [ ] **AC-04 (Concentric Bottom Padding on 4x4 Grid):**
  - Ô thứ 7 và Ô thứ 8 trên layout 4x4 (`widget_schedule_weekly.xml`) có khoảng đệm an toàn với mép đáy viền cong ngoài, không cấn lẹm góc bo.
- [ ] **AC-05 (2x2 Title Text Truncation Elimination):**
  - Tiêu đề trên widget 2x2 không bị cắt cụt thành `Lịch hôm...` khi ở kích thước hẹp.
- [ ] **AC-06 (Automated Tests & Zero Regression):**
  - Toàn bộ test suite `flutter test` đạt **100% PASS**, zero regressions trên toàn bộ 23 test suites hiện hành.
