# ĐẶC TẢ KỸ THUẬT (TECHNICAL SPECIFICATION)
## Phân Hệ: Tối Ưu Hóa Giao Diện Đồ Họa & Hiệu Năng: Khóa Cứng 1 Dòng Widget 4x4, Tái Cấu Trúc Thanh Điều Hướng Viên Thuốc Nền Đặc (Solid Pill 56dp) & Tinh Giản Cơ Chế Chuyển Tab (Tap-Only)

- **Mã tài liệu:** `SPEC-NAV-SOLID-PILL-AND-WIDGET-4X4-SINGLE-LINE-01`
- **Phiên bản:** `1.0.0`
- **Tác giả:** Senior BA / Hermes Master Orchestrator
- **Dự án:** Trạm Kiến - Ứng dụng Quản lý Học tập & Lịch học HAU (Flutter / Android Kotlin / iOS Swift)
- **Tình trạng:** Chờ User duyệt (Pending Approval)

---

## 1. BỐI CẢNH & PHÂN TÍCH HIỆN TRẠNG

### 1.1. Vấn đề 1: Tên môn học trên Widget 4x4 (Lịch tuần) bị bẻ thành 2 dòng
- **Hiện trạng:**
  - Trong `android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt:1054`, code đang gán `weeklyNameMaxLines = 2` khi widget có kích thước lớn ($>260\text{dp}$).
  - Khi tên môn dài (ví dụ: *"Phát triển phần mềm hướng dịch vụ"*), chữ bị bẻ đôi thành 2 dòng (`Phát triển phần mềm hướng` / `dịch vụ`), làm mất cân đối hình học và lệch chuẩn so với các ô ngày còn lại.
  - Trong khi đó, trên iOS (`ScheduleWidgetKit.swift`), toàn bộ text tên môn đều đã được khóa cứng `lineLimit(1)`.
- **Giải pháp:**
  - Khóa cứng `weeklyNameMaxLines = 1` trên toàn bộ 7 ô ngày của Widget 4x4 Android Native.
  - Tên môn dài tự động rút gọn bằng dấu ba chấm `...`, đồng bộ chuẩn mực 100% với iOS và Swiss Typography.

### 1.2. Vấn đề 2: Thanh điều hướng dùng kính mờ (BackdropFilter blur) gây tốn GPU, drop FPS và lem nhem thị giác
- **Hiện trạng:**
  - Trong `lib/screens/main_shell.dart:404`, thanh điều hướng bọc bằng `BackdropFilter(filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12))`.
  - Mỗi khi người dùng cuộn danh sách Dashboard hoặc Lịch học, GPU phải liên tục chụp lại frame buffer và tính toán Gaussian Blur 2 chiều ở tần số 60–120Hz, gây giật khựng (drop frame), hao pin và nóng máy.
  - Nội dung cuộn phía sau bị lấp ló nửa mờ dưới thanh nav, gây cảm giác lem nhem, khó đọc.
- **Giải pháp:**
  - Chuyển sang **NỀN ĐẶC 100% (Solid Surface `#FFFFFF`)** theo chuẩn cập nhật mới nhất của Telegram và Meta/Facebook.
  - Loại bỏ hoàn toàn `BackdropFilter` và `ImageFilter.blur`.
  - Chiều cao chuẩn: **`56dp`**, bo tròn viên thuốc hoàn hảo: **`28dp`** (`height / 2`).
  - Viền hairline siêu mảnh: **`0.5dp`** màu `#E2E8F0`, kết hợp bóng đổ mềm đa tầng tự nhiên.
  - Nội dung cuộn biến mất dứt khoát dưới thanh nav, sạch sẽ và thoáng đãng.

### 1.3. Vấn đề 3: Cơ chế bắt nhịp kéo (Drag Gesture) phức tạp, gây lag và dễ xung đột cử chỉ hệ thống
- **Hiện trạng:**
  - Trong `lib/screens/main_shell.dart`, thanh nav đang dùng `GestureDetector` với `onPanDown`, `onPanUpdate`, `onPanEnd` liên tục gọi `setState()` khi ngón tay di chuyển để kéo viên thuốc con.
  - Thực tế người dùng 100% chỉ chạm (Tap) để đổi tab. Việc bắt nhịp kéo làm tốn CPU, dễ xung đột với thanh vuốt đổi app của Android/iOS ở mép đáy màn hình.
- **Giải pháp:**
  - Lược bỏ hoàn toàn cơ chế kéo phức tạp (`onPanUpdate`, `_navDragging`, `_startDragDx`, `_navDragValue`).
  - Sử dụng cơ chế **Chạm Tap phản hồi tức thì**: Chạm tab nào, viên thuốc con tự động lướt êm ái sang tab đó bằng animation `AnimatedContainer` (`duration: 220ms`, `curve: Curves.easeOutCubic`).

---

## 2. PHẠM VI & GIẢI PHÁP KỸ THUẬT CHI TIẾT

### 2.1. Phân hệ 1: Khóa cứng 1 dòng tên môn Widget 4x4 Android
- **Tệp áp dụng:** `android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt`
- **Chi tiết:**
  - Thay đổi dòng 1054:
    ```kotlin
    val weeklyNameMaxLines = 1 // Khóa cứng 1 dòng duy nhất, text dài cắt bằng dấu ba chấm "..."
    ```
  - Đảm bảo toàn bộ 7 ô ngày (`nameIds` và `class2NameIds`) đều có `setMaxLines = 1`.

### 2.2. Phân hệ 2: Tái cấu trúc Thanh Điều Hướng Nền Đặc (Solid Floating Pill 56dp)
- **Tệp áp dụng:** `lib/screens/main_shell.dart`
- **Chi tiết:**
  - Gỡ bỏ `BackdropFilter` và `ImageFilter.blur(sigmaX: 12, sigmaY: 12)`.
  - Cấu hình Container viên thuốc:
    ```dart
    height: 56, // Chiều cao chuẩn 56dp
    margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
    decoration: BoxDecoration(
      color: Colors.white, // Nền đặc 100% Solid White
      borderRadius: BorderRadius.circular(28), // Bo tròn viên thuốc hoàn hảo (56 / 2)
      border: Border.all(
        color: const Color(0xFFE2E8F0), // Viền hairline 0.5dp
        width: 0.5,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 16,
          spreadRadius: -2,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 6,
          offset: const Offset(0, 1),
        ),
      ],
    ),
    ```
  - Viên thuốc con di chuyển (Active Indicator):
    ```dart
    height: 48,
    decoration: BoxDecoration(
      color: AppTheme.primaryFixed.withOpacity(0.9),
      borderRadius: BorderRadius.circular(24),
    ),
    ```

### 2.3. Phân hệ 3: Tinh giản cơ chế chuyển Tab Tap-Only (Loại bỏ Drag)
- **Tệp áp dụng:** `lib/screens/main_shell.dart`
- **Chi tiết:**
  - Xóa bỏ các biến: `_navDragging`, `_startDragDx`, `_navDragValue`, `_initialTapIdx`.
  - Xóa bỏ các hàm: `_startNavDrag`, `_updateNavDrag`, `_endNavDrag`, `_cancelNavDrag`.
  - Chuyển `GestureDetector` sang bọc sự kiện `onTap` trực tiếp trên từng tab item:
    ```dart
    _navItem(
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
      label: 'Tổng quan',
      idx: 0,
      active: _idx == 0,
      onTap: () => _navigate(0),
    )
    ```
  - Vị trí viên thuốc con xác định trực tiếp bằng `left: _idx * itemWidth`, chuyển động trượt êm ái qua `AnimatedPositioned` hoặc `AnimatedContainer` (`220ms, easeOutCubic`).

---

## 3. TIÊU CHÍ NGHIỆM THU (ACCEPTANCE CRITERIA - AC)

| Mã AC | Tiêu chí nghiệm thu | Tiêu chuẩn đánh giá |
| :--- | :--- | :--- |
| **AC-01** | **Khóa cứng 1 dòng tên môn trên Widget 4x4 (Lịch tuần)** | - `ScheduleWidgetProvider.kt` gán `weeklyNameMaxLines = 1`.<br>- Toàn bộ tên môn trên Widget 4x4 Android hiển thị trên đúng 1 dòng duy nhất, text dài cắt bằng dấu ba chấm `...`, không bị ngắt 2 dòng, đồng bộ 100% với iOS. |
| **AC-02** | **Thanh điều hướng Nền Đặc (Solid Pill 56dp) loại bỏ hoàn toàn Blur** | - `main_shell.dart` loại bỏ hoàn toàn `BackdropFilter` và `ImageFilter.blur`.<br>- Container có nền đặc `Colors.white` (100% Solid), chiều cao `56dp`, bo tròn `28dp`, viền hairline `0.5dp`, đổ bóng mềm tự nhiên.<br>- Nội dung cuộn trôi qua phía sau biến mất dứt khoát dưới thanh nav, không còn hiện tượng lấp ló mờ mờ. |
| **AC-03** | **Tinh giản cơ chế chuyển Tab mượt mà (Tap-Only, Không còn Drag)** | - Gỡ bỏ toàn bộ code `onPanUpdate` và `_navDragging`.<br>- Khi chạm (Tap) vào tab, viên thuốc con tự động trượt êm ái sang tab đích với thời gian `220ms` (`Curves.easeOutCubic`).<br>- Không còn hiện tượng gọi `setState()` liên tục khi vuốt, loại bỏ xung đột cử chỉ với hệ điều hành. |
| **AC-04** | **Hiệu năng cuộn mượt mà 60–120 FPS & Nhẹ máy** | - Loại bỏ 100% gánh nặng tính toán Gaussian Blur trên GPU.<br>- Cuộn trang Dashboard và Lịch học mượt mà, không drop frame, không nóng máy. |
| **AC-05** | **Bảo toàn Test Suite & Không gây Regression Bug** | - Toàn bộ unit/widget test suites liên quan đến Navigation, MainShell và Widget 4x4 đều PASS 100%. |

---

## 4. QUY TRÌNH ĐIỀU PHỐI TỰ ĐỘNG (AUTONOMOUS CLOSED-LOOP EXECUTION)

1. **Bước 1 (BA Spec):** User duyệt Spec.
2. **Bước 2 (Dev2 Code):** Tự động kích hoạt Sub-agent `dev2` lập trình cả 2 phân hệ (Flutter Shell + Android Kotlin).
3. **Bước 3 (Tester Verify):** Tự động kích hoạt Sub-agent `tester` kiểm thử độc lập 2 tầng và lập Test Report.
4. **Bước 4 (BA Sign-off):** BA đối soát toàn diện và nghiệm thu bàn giao lại cho User.
