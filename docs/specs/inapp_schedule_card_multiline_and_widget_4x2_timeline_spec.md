# ĐẶC TẢ KỸ THUẬT (TECHNICAL SPECIFICATION)
## Phân Hệ: Thẻ Lịch Học Đa Dòng Trong App & Nâng Cấp Widget "Lịch Hôm Nay" 4x2 Timeline Trực Quan (Đồng Bộ Android & iOS)

- **Mã tài liệu:** `SPEC-SCHEDULE-CARD-MULTILINE-WIDGET-4X2-TIMELINE-01`
- **Phiên bản:** `1.1.0`
- **Tác giả:** Senior BA / Hermes Master Orchestrator
- **Dự án:** Trạm Kiến - Ứng dụng Quản lý Học tập & Lịch học HAU (Flutter / Android / iOS)
- **Tình trạng:** Chờ User duyệt (Pending Approval)

---

## 1. BỐI CẢNH & PHÂN TÍCH HIỆN TRẠNG (ANDROID vs iOS)

### 1.1. Thẻ Lịch học Trong App (In-App Schedule Cards): DÙNG CHUNG CẢ ANDROID & iOS
- **Hiện trạng:**
  - Ứng dụng xây dựng trên Flutter, toàn bộ thẻ lịch học trên Dashboard (`lib/widgets/shared_widgets.dart:794`) và màn hình Lịch (`lib/screens/schedule_screen.dart:1599`) dùng chung mã nguồn Dart.
  - Hàng thông tin phụ trợ (Phòng, Tiết, Giảng viên, Mã lớp) hiện đang bị bọc trong:
    ```dart
    SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Row(...),
    )
    ```
- **Hậu quả:** 
  - **Cả iOS và Android đều bị lỗi giống hệt nhau:** Chip bị khóa cứng trên 1 hàng ngang. Khi dữ liệu dài, chip cuối cùng (Mã lớp `# TI...`) bị tràn ra khỏi mép khung thẻ và bị cắt cụt mất đuôi một cách âm thầm (silent clipping) mà không xuống dòng.

### 1.2. Widget Màn hình chính (Home Screen Widget):
- **Phía Android:**
  - `AndroidManifest.xml` đặt tên 2 provider `SingleDayScheduleWidgetProvider` (4x2) và `SingleDay2x2ScheduleWidgetProvider` (2x2) trùng nhãn `"Lịch hôm nay"`. Người dùng kéo nhầm bản 2x2 ra rồi kéo dãn (resize) sang 4x2, dẫn đến việc layout 2x2 bị trống toác hơn 70% diện tích bên dưới.
  - Layout 4x2 (`widget_schedule_single_day.xml`) chưa có trục timeline trực quan (vạch kẻ dọc, dot indicator màu Accent, giờ bắt đầu - kết thúc rõ ràng).
- **Phía iOS (`ios/Runner/ScheduleWidgetKit.swift`):**
  - Khác với Android, iOS WidgetKit không cho kéo dãn tự do mà phân chia sẵn theo family (`.systemSmall` ~ 2x2, `.systemMedium` ~ 4x2, `.systemLarge` ~ 4x4).
  - Tuy nhiên, bản `.systemMedium` (4x2) trên iOS hiện tại cũng mới chỉ chia 2 cột thô sơ, chưa có trục timeline/dot indicator, và khi chỉ có 1 ca học thì phần dưới cũng bị chừa khoảng trống thừa.

---

## 2. PHẠM VI & GIẢI PHÁP KỸ THUẬT CHI TIẾT

### 2.1. Phân hệ 1: Thẻ Lịch học Trong App (Áp dụng đồng bộ iOS & Android)
- **Tệp áp dụng:** 
  - `lib/widgets/shared_widgets.dart` (`ScheduleCard`)
  - `lib/screens/schedule_screen.dart` (`_ScheduleCardFull`)
- **Giải pháp:**
  - Thay thế `SingleChildScrollView` + `Row` bằng `Wrap`:
    ```dart
    Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (lichHoc.phong.isNotEmpty) _InfoChip(Icons.location_on_outlined, lichHoc.phong),
        _InfoChip(Icons.class_outlined, 'Tiết ${lichHoc.tiet}'),
        if (lichHoc.giaoVien.isNotEmpty) _InfoChip(Icons.person_outline, lichHoc.giaoVien),
        if (lichHoc.tenLopTinChi.isNotEmpty) _InfoChip(Icons.tag, lichHoc.tenLopTinChi),
      ],
    )
    ```
  - **Cơ chế:** Khi hàng 1 hết chỗ, chip tiếp theo tự động rớt xuống hàng thứ 2 với khoảng đệm dòng `runSpacing: 6`. Cả iOS và Android đều hiển thị trọn vẹn 100% dữ liệu.

### 2.2. Phân hệ 2: Nâng cấp Widget Android "Lịch hôm nay" 4x2 Timeline & Nhãn Launcher
- **Tệp áp dụng:**
  - `android/app/src/main/AndroidManifest.xml`
  - `android/app/src/main/res/layout/widget_schedule_single_day.xml`
  - `android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt`
  - `lib/screens/widget_studio_screen.dart`
- **Chi tiết triển khai:**
  1. **Tách bạch nhãn trên Android Launcher:**
     - `SingleDayScheduleWidgetProvider`: `android:label="Lịch hôm nay (4x2 Timeline)"`.
     - `SingleDay2x2ScheduleWidgetProvider`: `android:label="Lịch hôm nay (2x2 Thu gọn)"`.
  2. **Tái thiết kế layout Timeline trực quan 4x2 (`widget_schedule_single_day.xml`):**
     - Cột trái: Giờ bắt đầu – kết thúc, vạch kẻ trục dọc và chấm mốc tròn (dot indicator) mang màu chủ đề Accent.
     - Cột phải: Tên môn in đậm nổi bật (`13sp`), phân bổ thông tin phòng học, giảng viên, mã lớp thoáng đãng.
     - Cân bằng dọc thông minh: Khi chỉ có 1 môn học, nội dung tự động căn dóng cân đối, xóa bỏ hoàn toàn khoảng trống 70% dưới đáy.
  3. **Đồng bộ Live Preview trong `WidgetStudioScreen.dart`:**
     - Bổ sung tùy chọn xem trước và cấu hình bản 4x2 Timeline bên cạnh bản 2x2 Thu gọn.

### 2.3. Phân hệ 3: Nâng cấp Đồng bộ Widget iOS (`ScheduleWidgetKit.swift`)
- **Tệp áp dụng:** `ios/Runner/ScheduleWidgetKit.swift`
- **Chi tiết triển khai:**
  - Cập nhật nhánh `.systemMedium` (4x2):
    + Bổ sung trục timeline trực quan với Capsule / Circle indicator màu Accent.
    + Khi chỉ có 1 ca học: Tự động cân bằng khoảng cách dọc (vertical alignment) giúp thẻ không bị dồn cục lên trên.
    + Đảm bảo đồng bộ visual parity 1:1 giữa Android và iOS theo chuẩn Swiss/Apple Design.

---

## 3. TIÊU CHÍ NGHIỆM THU (ACCEPTANCE CRITERIA - AC)

| Mã AC | Tiêu chí nghiệm thu | Tiêu chuẩn đánh giá |
| :--- | :--- | :--- |
| **AC-01** | **Tự động xuống dòng đa dòng (Wrap) trên thẻ In-App (iOS & Android)** | - `ScheduleCard` và `_ScheduleCardFull` dùng `Wrap(spacing: 8, runSpacing: 6)`.<br>- Tự động rớt dòng thứ 2 khi thiếu chỗ, triệt tiêu 100% tình trạng mất chữ mép phải trên cả iOS và Android. |
| **AC-02** | **Phân biệt nhãn widget rõ ràng trên Android Launcher** | - `AndroidManifest.xml` khai báo tách bạch `Lịch hôm nay (4x2 Timeline)` và `Lịch hôm nay (2x2 Thu gọn)`. |
| **AC-03** | **Bố cục Timeline trực quan & Triệt tiêu khoảng trống trên Android Widget 4x2** | - `widget_schedule_single_day.xml` và `ScheduleWidgetProvider.kt` hiển thị cấu trúc Timeline trực quan.<br>- Khi có 1 môn học: Căn dóng dọc cân đối, không bị bỏ trống 70% đáy thẻ. |
| **AC-04** | **Nâng cấp đồng bộ iOS WidgetKit (`.systemMedium`)** | - `ScheduleWidgetKit.swift` hỗ trợ trục timeline và cân đối dọc khi có 1 ca học.<br>- Đạt Visual Parity đồng bộ với Android 4x2. |
| **AC-05** | **Đồng bộ Live Preview 4x2 trong Widget Studio** | - `WidgetStudioScreen.dart` hỗ trợ chuyển đổi và xem trước bản 4x2 Timeline 1:1 với Native. |
| **AC-06** | **Bảo toàn Test Suite & Không gây Regression Bug** | - 100% bài test liên quan pass, build an toàn trên cả Android và iOS CI (`dart.yml`). |

---

## 4. QUY TRÌNH ĐIỀU PHỐI TỰ ĐỘNG (AUTONOMOUS CLOSED-LOOP EXECUTION)

1. **Bước 1 (BA Spec):** User duyệt Spec.
2. **Bước 2 (Dev2 Code):** Tự động kích hoạt Sub-agent `dev2` lập trình toàn bộ các file (Flutter Dart + Android Kotlin/XML + iOS Swift).
3. **Bước 3 (Tester Verify):** Tự động kích hoạt Sub-agent `tester` kiểm thử độc lập 2 tầng (đọc diff kiểm tra logic + chạy `flutter test`).
4. **Bước 4 (BA Sign-off):** BA đối soát toàn bộ kết quả, lập báo cáo nghiệm thu UAT gửi User.
