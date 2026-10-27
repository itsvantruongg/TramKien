# ĐẶC TẢ KỸ THUẬT (TECHNICAL SPECIFICATION)
## Phân Hệ: Tối Ưu Hóa Trải Nghiệm Widget Android & iOS: Lược Bỏ Bản 2x2, Đồng Bộ Căn Đỉnh Layout, Giữ Nguyên Màu Môn Học & Nạp Dữ Liệu Thực Tế Khi Áp Dụng

- **Mã tài liệu:** `SPEC-WIDGET-CLEANUP-2X2-ALIGNMENT-AND-REAL-DATA-01`
- **Phiên bản:** `1.1.0`
- **Tác giả:** Senior BA / Hermes Master Orchestrator
- **Dự án:** Trạm Kiến - Ứng dụng Quản lý Học tập & Lịch học HAU (Flutter / Android Kotlin / iOS Swift)
- **Tình trạng:** Chờ User duyệt (Pending Approval)

---

## 1. BỐI CẢNH & PHÂN TÍCH YÊU CẦU CỦA USER (ĐỒNG BỘ ANDROID & iOS)

### 1.1. Yêu cầu 1: Lược bỏ hoàn toàn Widget 2x2 (Thẻ vuông) trên cả Android & iOS
- **Lý do người dùng đưa ra:** Kích thước 2x2 quá bé trên màn hình điện thoại, trong khi thông tin môn học (tên môn, phòng, giảng viên, mã lớp) quá dày đặc, cố nhét vào sẽ gây chèn ép, rối mắt và trải nghiệm kém.
- **Giải pháp:**
  - **Trên Android:** Gỡ bỏ hoàn toàn receiver `SingleDay2x2ScheduleWidgetProvider` trong `AndroidManifest.xml` (người dùng không thể chọn hoặc thêm widget 2x2 từ launcher nữa).
  - **Trên iOS (WidgetKit):** Xóa bỏ `.systemSmall` khỏi danh sách `supportedFamilies` trong `ScheduleWidgetKit.swift` (`.supportedFamilies([.systemMedium, .systemLarge, .accessoryRectangular])`). Người dùng iOS khi thêm widget sẽ chỉ thấy các bản chuẩn: 4x2 (`.systemMedium`), 4x4 Weekly Grid (`.systemLarge`) và Lock Screen (`.accessoryRectangular`).
  - **Trên Widget Studio:** Lược bỏ toggle chọn `2x2`, mặc định chế độ Lịch hôm nay là `4x2 Timeline`.

### 1.2. Yêu cầu 2: Bỏ nhãn `[ĐÃ HOÀN THÀNH]` / `[ĐÃ XONG]`, KHÔNG làm mờ xám ca học và đưa layout về Căn Đỉnh (Top-aligned)
- **Lý do người dùng đưa ra:** 
  - Người dùng không muốn hiển thị chữ `[ĐÃ HOÀN THÀNH]` hay `[ĐÃ XONG]`, và không muốn chuyển tên môn học sang màu xám. Môn học trong ngày dù đã học xong vẫn phải giữ nguyên màu sắc chữ và màu Accent nguyên bản để nhìn rõ ràng, đẹp mắt.
  - Vấn đề căn giữa (Center-aligned): Khi chỉ có 1 môn học, layout hiện tại bị đặt căn giữa khiến thẻ môn bị rơi xuống lơ lửng ở giữa, nhìn lệch chuẩn hình học và mất thẩm mỹ.
- **Giải pháp:**
  - **Trên Android:** Sửa `single_day_content` trong `widget_schedule_single_day.xml` thành `android:gravity="top"`. Giữ nguyên màu `textColor` và màu `accentColor` cho ca học (kể cả khi `is_finished == true`), không hiển thị badge `[ĐÃ HOÀN THÀNH]`.
  - **Trên iOS:** Trong nhánh `.systemMedium` của `ScheduleWidgetKit.swift`, loại bỏ `Spacer()` ở phía trên khi có 1 ca học (chỉ giữ `Spacer(minLength: 0)` ở đáy thẻ) để căn dóng từ trên đỉnh xuống; giữ nguyên màu chữ trắng/đỏ thi và màu Accent của Capsule indicator, không hiển thị badge `[ĐÃ HOÀN THÀNH]`.
  - **Trên Widget Studio:** Đồng bộ căn dóng đỉnh và giữ nguyên màu sắc rực rỡ, không xám mờ.

### 1.3. Yêu cầu 3: Sửa lỗi Widget hiển thị mock "Môn học 1/2/3" sau khi bấm Áp Dụng trong App
- **Nguyên nhân gốc rễ:**
  - Trong `lib/screens/widget_studio_screen.dart`:
    + Hàm `_initData()` đang khóa cứng `_isUsingSampleData = true; _scheduleData = _buildFallbackPreviewData(_config.layoutMode);` (chứa "Môn học 1", "Môn học 2", "Môn học 3").
    + Khi người dùng bấm nút **ÁP DỤNG**, nếu SQLite chưa có dữ liệu hoặc hàm `WidgetDataSyncService.loadAndSyncFromDb()` bị ngoại lệ/rỗng thì nó lấy `_scheduleData ?? _buildFallbackPreviewData()` ghi đè vào SharedPreferences `widget_schedule_data` và cập nhật ra Widget ngoài Launcher.
- **Giải pháp:**
  - Trong `WidgetDataSyncService.loadAndSyncFromDb`: Luôn ưu tiên đọc dữ liệu thật từ `ScheduleDb.getLichHoc()` và `ScheduleDb.getLichThi()`. Nếu người dùng đã đăng nhập và có dữ liệu trong máy, **BẮT BUỘC** trích xuất lịch thật của user vào SharedPreferences (Android) và UserDefaults AppGroup (iOS).
  - Khi bấm `_handleApply()` trong `widget_studio_screen.dart`: Gọi `loadAndSyncFromDb` với dữ liệu thực tế từ Database, ghi vào Native widget, sau đó kích hoạt cập nhật đồng thời cho cả Android (`triggerNativeWidgetUpdate`) và iOS (`WidgetCenter.shared.reloadAllTimelines()`). Widget ngoài màn hình chính trên cả 2 hệ điều hành sẽ hiển thị 100% thời khóa biểu thật của sinh viên thay vì "Môn học 1/2/3".

---

## 2. PHẠM VI & GIẢI PHÁP KỸ THUẬT CHI TIẾT

### 2.1. Phân hệ 1: Loại bỏ Widget 2x2
- **Tệp áp dụng:**
  - `android/app/src/main/AndroidManifest.xml`: Xóa bỏ receiver `SingleDay2x2ScheduleWidgetProvider`.
  - `lib/screens/widget_studio_screen.dart`: Xóa bỏ tùy chọn chọn biến thể `2x2`, chế độ "Lịch hôm nay" khóa cứng sử dụng layout chuẩn `4x2 Timeline`.

### 2.2. Phân hệ 2: Căn đỉnh (Top-alignment), Giữ nguyên màu sắc & Bỏ badge `[ĐÃ HOÀN THÀNH]`
- **Tệp áp dụng:**
  - `android/app/src/main/res/layout/widget_schedule_single_day.xml`:
    + Đổi `android:gravity="center_vertical"` của `single_day_content` thành `android:gravity="top"`.
    + Đặt `layout_marginTop` hợp lý cho các ca học để tạo khoảng cách thanh lịch.
  - `android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt`:
    + Giữ nguyên màu `textColor` cho tên môn và `accentColor` cho giờ học / indicator (không ép sang `textSecColor` xám).
    + Bỏ logic gán text `[ĐÃ HOÀN THÀNH]` / `[ĐÃ XONG]`.
  - `ios/Runner/ScheduleWidgetKit.swift`:
    + Bỏ badge `[ĐÃ HOÀN THÀNH]`. Giữ nguyên màu Accent và chữ trắng nổi bật. Bỏ căn giữa dọc, chuyển về căn lề từ trên xuống (`Spacer(minLength: 0)` ở đáy).
  - `lib/screens/widget_studio_screen.dart`:
    + Đồng bộ bỏ badge `[ĐÃ HOÀN THÀNH]`, giữ màu sắc rực rỡ và căn dóng từ trên xuống.

### 2.3. Phân hệ 3: Đảm bảo Widget nạp 100% dữ liệu thật của User khi bấm ÁP DỤNG
- **Tệp áp dụng:**
  - `lib/screens/widget_studio_screen.dart`:
    + Trong `_handleApply()`: Đảm bảo luồng lấy dữ liệu thực tế từ SQLite (`ScheduleDb.getLichHoc()`). Tuyệt đối không lấy `_scheduleData` mock mẫu để lưu đè vào SharedPreferences Native nếu đã có lịch học trong máy.
    + Cập nhật `_initData()`: Nếu trong máy đã có dữ liệu SQLite, nạp dữ liệu thật của sinh viên vào Studio Preview; chỉ fallback về mock mẫu khi sinh viên chưa từng đăng nhập hoặc DB trống.
  - `lib/services/widget_data_sync_service.dart`:
    + Đảm bảo sau khi tính toán dữ liệu thật từ DB, kích hoạt `triggerNativeWidgetUpdate()` gửi tín hiệu sang Android và iOS reload timeline ngay lập tức.

---

## 3. TIÊU CHÍ NGHIỆM THU (ACCEPTANCE CRITERIA - AC)

| Mã AC | Tiêu chí nghiệm thu | Tiêu chuẩn đánh giá |
| :--- | :--- | :--- |
| **AC-01** | **Lược bỏ hoàn toàn Widget 2x2 khỏi Launcher & Studio** | - `AndroidManifest.xml` không còn receiver `SingleDay2x2ScheduleWidgetProvider`.<br>- Widget Studio không còn nút chọn `2x2`, chế độ Lịch hôm nay mặc định dùng `4x2 Timeline`. |
| **AC-02** | **Căn đỉnh layout (Top-aligned) cho Widget 4x2** | - `widget_schedule_single_day.xml` sử dụng `gravity="top"`.<br>- Môn học được xếp ngay ngắn từ trên xuống, không bị rơi xuống lơ lửng ở giữa thẻ. |
| **AC-03** | **Bỏ nhãn `[ĐÃ HOÀN THÀNH]` / `[ĐÃ XONG]` & Giữ nguyên màu sắc ca học** | - Ca học (kể cả đã học xong) giữ nguyên màu chữ `textColor` và màu Accent của indicator/giờ học (không chuyển sang màu xám mờ).<br>- Không hiển thị các badge text `[ĐÃ HOÀN THÀNH]` hoặc `[ĐÃ XONG]`. |
| **AC-04** | **Bấm "Áp Dụng" nạp đúng dữ liệu thật của User ra Widget** | - Khi bấm nút Áp Dụng trong Widget Studio, hệ thống đọc dữ liệu thật từ SQLite `ScheduleDb` và nạp ra Widget ngoài màn hình chính.<br>- Widget ngoài màn hình chính hiển thị tên môn học thật của user thay vì mock "Môn học 1/2/3". |
| **AC-05** | **Đồng bộ hóa iOS WidgetKit (Swift)** | - `ScheduleWidgetKit.swift` căn lề top, bỏ badge `[ĐÃ HOÀN THÀNH]`, giữ màu sắc hiển thị đồng bộ 1:1 với Android. |
| **AC-06** | **Bảo toàn Test Suite & Không gây Regression Bug** | - 100% test suites trong dự án được cập nhật tương thích và PASS 100%. |

---

## 4. QUY TRÌNH ĐIỀU PHỐI TỰ ĐỘNG (AUTONOMOUS CLOSED-LOOP EXECUTION)

1. **Bước 1 (BA Spec):** User duyệt Spec.
2. **Bước 2 (Dev2 Code):** Tự động kích hoạt Sub-agent `dev2` lập trình toàn diện (Flutter, Android Kotlin/XML, iOS Swift).
3. **Bước 3 (Tester Verify):** Tự động kích hoạt Sub-agent `tester` kiểm thử độc lập 2 tầng và lập Test Report.
4. **Bước 4 (BA Sign-off):** BA đối soát toàn diện và nghiệm thu bàn giao lại cho User.
