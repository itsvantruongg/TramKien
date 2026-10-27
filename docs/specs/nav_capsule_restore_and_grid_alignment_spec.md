# ĐẶC TẢ KỸ THUẬT (TECHNICAL SPECIFICATION)
## Phân Hệ: Tối Ưu Hóa Gióng Hàng Toàn Diện Hệ Thống (AcademicAppBar Lề Trái 20dp, Nav Margin 16dp) & Khôi Phục Kiểu Dáng Viên Thuốc Tròn Đồng Dạng (Capsule Indicator 24dp)

- **Mã tài liệu:** `SPEC-NAV-CAPSULE-RESTORE-AND-GRID-ALIGNMENT-01`
- **Phiên bản:** `1.1.0`
- **Tác giả:** Senior BA / Hermes Master Orchestrator
- **Dự án:** Trạm Kiến - Ứng dụng Quản lý Học tập & Lịch học HAU (Flutter / Android Kotlin / iOS Swift)
- **Tình trạng:** Chờ User duyệt (Pending Approval)

---

## 1. BỐI CẢNH & PHÂN TÍCH QUY TẮC GIÓNG HÀNG TRÊN TOÀN BỘ ỨNG DỤNG

### 1.1. Khảo sát hiện trạng quy chuẩn lề trên TOÀN BỘ CÁC TRANG trong ứng dụng
Khảo sát trực tiếp toàn bộ 5 tab chính và các màn hình phụ:
1. **Màn hình Tổng quan (`DashboardScreen`):** Lề 2 bên `20dp` (`padding: EdgeInsets.fromLTRB(20, 0, 20, 100)`).
2. **Màn hình Lịch học (`ScheduleScreen`):** Lề 2 bên `20dp` (`margin: horizontal 20` và `padding: fromLTRB(20, 8, 20, 80)`).
3. **Màn hình Điểm số (`GradesScreen`):** Lề 2 bên `20dp` (`padding: fromLTRB(20, 12, 20, 100)`).
4. **Màn hình Học phí (`FinanceScreen`):** Lề 2 bên `20dp` (`padding: fromLTRB(20, 20, 20, 100)`).
5. **Màn hình Tài khoản (`ProfileScreen`):** Lề 2 bên `20dp` (`padding: fromLTRB(20, 8, 20, 100)`).
6. **Các màn hình phụ (Thông báo, Quản lý lịch, Điều khoản...):** Đều đang áp dụng thống nhất lề 2 bên là `20dp`.

👉 **Kết luận:** Lề 2 bên `20dp` của nội dung là **quy chuẩn nền tảng xuyên suốt toàn bộ ứng dụng**.

### 1.2. Vấn đề lệch trục lề trái tại Header (`AcademicAppBar`)
- Cả 5 màn hình chính (`Dashboard`, `Schedule`, `Grades`, `Finance`, `Profile`) đều sử dụng chung một thành phần Header là **`AcademicAppBar`** (`lib/widgets/shared_widgets.dart:38`).
- Header này đang bị đặt lề trái:
  ```dart
  padding: const EdgeInsets.fromLTRB(16, 6, 8, 6), // 💥 Lề trái 16dp
  ```
- **Hậu quả:** Trong khi nội dung của cả 5 trang đều lùi vào `20dp`, mép Logo hình tròn bên trái của Header lại chỉ lùi `16dp`, khiến mép Logo **bị trồi ra ngoài `4dp` trên TẤT CẢ 5 TRANG**. Mắt người nhìn vào thấy ngay sự thụt thò, lệch trục hình học.
- **Giải pháp:**
  - Sửa lề trái của `AcademicAppBar` thành **`20dp`** (`padding: const EdgeInsets.fromLTRB(20, 6, 8, 6)`).
  - Ngay lập tức, mép Logo hình tròn trên **toàn bộ các trang** (Dashboard, Lịch học, Điểm số, Học phí, Tài khoản) đều được dóng thẳng hàng tuyệt đối 100% với mép các Card nội dung bên dưới.
  - Lề phải giữ nguyên `8dp` để bảo toàn vùng cảm ứng công thái học `48x48dp` của các nút bấm IconButton.

### 1.3. Về Thanh điều hướng đáy: Nới lề hai bên từ `20dp` $\rightarrow$ `16dp`
- Thanh điều hướng đáy (`MainShell`) thuộc **tầng điều khiển nổi (Floating System Layer)** nằm đè lên trên nội dung.
- Nới lề hai bên từ `20dp` xuống **`16dp`** (`margin: const EdgeInsets.fromLTRB(16, 0, 16, 16)`):
  - Mở rộng thêm `8dp` bề ngang cho thanh nav, giúp 5 tab có thêm diện tích thở rộng rãi.
  - Vẫn giữ nguyên khoảng cách lề đáy `16dp` hiện tại.

### 1.4. RÀNG BUỘC PHẠM VI NGHIÊM NGẶT (BOUNDARY CONSTRAINTS)
- **TUYỆT ĐỐI CHỈ SỬA LỀ HAI BÊN (Horizontal Margin / Padding):**
  - **KHÔNG ĐƯỢC CHẠM VÀO LỀ TRÊN (Top) VÀ LỀ DƯỚI (Bottom):** Giữ nguyên vẹn 100% lề trên, lề dưới, padding cuộn đáy (Bottom Scroll Padding `80dp`/`100dp`) và SafeArea của tất cả các trang, tránh làm thay đổi chiều cao, tràn viền hoặc vỡ giao diện ban đầu của người dùng.
  - Nội dung các Card bên dưới của các trang tiếp tục duy trì lề 2 bên `20dp` nguyên bản.

### 1.5. Khôi phục kiểu dáng viên thuốc xanh đồng dạng (Capsule 24dp)
- Đổi khối Active Indicator từ bo vuông `14dp` quay về **dạng viên thuốc bo tròn mềm mại `BorderRadius.circular(24)`** ($48 / 2$).
- Cùng chung ngôn ngữ hình học Capsule với vỏ ngoài (`31dp`), chấm dứt triệt để tình trạng "ngoài tròn trong vuông".
- Chiều cao viên thuốc `48dp`, lề trên/dưới `7dp`, lề ngang `5dp` lọt lòng rộng rãi.

---

## 2. CHI TIẾT THÔNG SỐ HÌNH HỌC TRONG MÃ NGUỒN

### 2.1. Cấu hình Thanh Điều Hướng Đáy (`lib/screens/main_shell.dart`)
```dart
Container(
  height: 62, // Chiều cao chuẩn 62dp
  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16), // 🎯 Nới lề 2 bên từ 20dp xuống 16dp
  padding: const EdgeInsets.symmetric(horizontal: 4),
  decoration: BoxDecoration(
    color: Colors.white, // Nền đặc 100% Solid White
    borderRadius: BorderRadius.circular(31), // Bo tròn vỏ ngoài 31dp (62 / 2)
    border: Border.all(
      color: const Color(0xFFE2E8F0), // Viền hairline 0.8dp
      width: 0.8,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.08),
        blurRadius: 24,
        spreadRadius: -4,
        offset: const Offset(0, 8),
      ),
      BoxShadow(
        color: AppTheme.primary.withOpacity(0.04),
        blurRadius: 10,
        offset: const Offset(0, 2),
      ),
    ],
  ),
  child: LayoutBuilder(
    builder: (context, constraints) {
      final itemWidth = constraints.maxWidth / 5;
      return Stack(
        children: [
          // Viên thuốc xanh con bọc cả Icon + Text (cao 48dp, bo tròn đồng dạng 24dp)
          AnimatedPositioned(
            left: _idx * itemWidth,
            top: 7, // 🎯 Lề trên 7dp đều đặn (62 - 48) / 2
            width: itemWidth,
            height: 48,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: AppTheme.primaryFixed.withOpacity(0.85),
                borderRadius: BorderRadius.circular(24), // 🎯 Bo tròn viên thuốc mềm mại 24dp đồng dạng
              ),
            ),
          ),
          // Hàng chứa 5 tabs
          SizedBox(
            height: 62,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _navItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Tổng quan', idx: 0, active: _idx == 0, onTap: () => _navigate(0)),
                _navItem(icon: Icons.calendar_today_outlined, activeIcon: Icons.calendar_today, label: 'Lịch học', idx: 1, active: _idx == 1, onTap: () => _navigate(1)),
                _navItem(icon: Icons.grade_outlined, activeIcon: Icons.grade, label: 'Điểm số', idx: 2, active: _idx == 2, onTap: () => _navigate(2)),
                _navItem(icon: Icons.payments_outlined, activeIcon: Icons.payments, label: 'Học phí', idx: 3, active: _idx == 3, onTap: () => _navigate(3)),
                _navItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Tài khoản', idx: 4, active: _idx == 4, onTap: () => _navigate(4)),
              ],
            ),
          ),
        ],
      );
    },
  ),
)
```

### 2.2. Cấu hình Header Gióng Lề Chuẩn (`lib/widgets/shared_widgets.dart`)
```dart
// AcademicAppBar trong shared_widgets.dart
Padding(
  padding: const EdgeInsets.fromLTRB(20, 6, 8, 6), // 🎯 Lề trái đổi thành 20dp gióng thẳng mép Card nội dung
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.primaryFixed,
          border: Border.all(
            color: AppTheme.primary.withOpacity(0.2),
            width: 2,
          ),
        ),
        child: const Icon(Icons.school, color: AppTheme.primary, size: 16),
      ),
      const SizedBox(width: 10),
      Expanded(...),
      ...?actions,
    ],
  ),
)
```

---

## 3. TIÊU CHÍ NGHIỆM THU (ACCEPTANCE CRITERIA - AC)

| Mã AC | Tiêu chí nghiệm thu | Tiêu chuẩn đánh giá chi tiết |
| :--- | :--- | :--- |
| **AC-01** | **Khôi phục kiểu dáng viên thuốc xanh đồng dạng (Capsule 24dp)** | - Khối indicator bên trong dùng `BorderRadius.circular(24)` ($48 / 2$), bo tròn viên thuốc mềm mại đồng dạng với vỏ ngoài `31dp`.<br>- Xóa bỏ triệt để tình trạng "ngoài tròn trong vuông". |
| **AC-02** | **Nới lề hai bên thanh nav từ 20dp xuống 16dp** | - `margin: EdgeInsets.fromLTRB(16, 0, 16, 16)`.<br>- Thanh nav mở rộng thêm `8dp` bề ngang, các tab có không gian thở rộng rãi. |
| **AC-03** | **Header dóng thẳng tắp với mép Card nội dung** | - `AcademicAppBar` sử dụng lề trái `20dp` (`padding: fromLTRB(20, 6, 8, 6)`).<br>- Logo tròn dóng thẳng hàng tuyệt đối với mép các Card nội dung bên dưới. |
| **AC-04** | **Bảo toàn nền đặc Solid White, bóng nổi khối & Tap-Only 120Hz** | - Nền đặc 100% Solid White `#FFFFFF`, viền hairline `0.8dp`, bóng đổ đa tầng sâu `8dp`.<br>- Chuyển tab Tap-Only tức thì `220ms` (`Curves.easeOutCubic`). |
| **AC-05** | **Bảo toàn Test Suite & Không gây Regression Bug** | - 100% unit/widget test suites liên quan đến Navigation, MainShell, AcademicAppBar đều PASS. |

---

## 4. QUY TRÌNH ĐIỀU PHỐI TỰ ĐỘNG (AUTONOMOUS CLOSED-LOOP EXECUTION)

1. **Bước 1 (BA Spec):** User duyệt Spec.
2. **Bước 2 (Dev2 Code):** Tự động kích hoạt Sub-agent `dev2` lập trình `lib/screens/main_shell.dart` và `lib/widgets/shared_widgets.dart`.
3. **Bước 3 (Tester Verify):** Tự động kích hoạt Sub-agent `tester` kiểm thử độc lập 2 tầng và lập Test Report.
4. **Bước 4 (BA Sign-off):** BA đối soát toàn diện và nghiệm thu bàn giao lại cho User.
