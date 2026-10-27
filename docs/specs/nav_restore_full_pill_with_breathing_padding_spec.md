# ĐẶC TẢ KỸ THUẬT (TECHNICAL SPECIFICATION)
## Phân Hệ: Khôi Phục Kiểu Dáng Viên Thuốc Bao Cả Tab (Full-Tab Pill) Cho Thanh Điều Hướng Đáy & Tăng Khoảng Đệm Thoáng Đãng (Breathing Padding)

- **Mã tài liệu:** `SPEC-NAV-RESTORE-FULL-PILL-WITH-BREATHING-PADDING-01`
- **Phiên bản:** `1.0.0`
- **Tác giả:** Senior BA / Hermes Master Orchestrator
- **Dự án:** Trạm Kiến - Ứng dụng Quản lý Học tập & Lịch học HAU (Flutter / Android Kotlin / iOS Swift)
- **Tình trạng:** Chờ User duyệt (Pending Approval)

---

## 1. BỐI CẢNH & PHÂN TÍCH YÊU CẦU CỦA USER

### 1.1. Quyết định sản phẩm (Product Decision)
- Người dùng không ưng ý với kiểu viên thuốc nhỏ chỉ bọc quanh Icon (Pill-Icon).
- Người dùng yêu cầu: **Khôi phục lại kiểu dáng ban đầu: Viên thuốc xanh bao trọn cả Icon lẫn Nhãn chữ của Tab**, nhưng khắc phục nhược điểm chật chội trước đó bằng cách **tăng thêm khoảng cách (Breathing Padding) giữa viên thuốc xanh bên trong và vỏ viên thuốc lớn bên ngoài**.

### 1.2. Phân tích nguyên nhân chật chội ở bản cũ & Giải pháp cải tiến hình học:
- **Ở bản cũ trước đó:**
  - Thanh nav ngoài cao `56dp`, viên thuốc xanh bên trong cao tới `48dp`, lề trên và dưới chỉ có `4dp` (`(56 - 48) / 2 = 4dp`), lề hai bên chỉ `4dp`. Khoảng hở `4dp` là quá hẹp, khiến viên thuốc xanh gần như chạm sát mép vỏ ngoài, gây cảm giác tức mắt, chật chội.
- **Giải pháp tối ưu hình học mới (Breathing Padding):**
  1. **Tăng khoảng hở lề trên/dưới và hai bên từ `4dp` lên `6dp` - `7dp`:**
     - Giữ chiều cao thanh nav chuẩn mực: **`62dp`**.
     - Chiều cao viên thuốc xanh bên trong: **`48dp`** (bao trọn vẹn cả Icon `22dp` + Text `10dp` + đệm giữa `2dp`).
     - Lề trên và dưới: **`7dp`** (`(62 - 48) / 2 = 7dp`). Viên thuốc xanh nằm lọt lòng giữa thanh nav với khoảng hở đều đặn, thoáng đãng, sang trọng.
     - Lề ngang (Horizontal Margin) của viên thuốc xanh: `6dp` mỗi bên tab, tạo sự tách bạch rõ rệt giữa các tab.
  2. **Bo tròn đồng tâm hài hòa (Concentric Border Radius):**
     - Vỏ ngoài: `BorderRadius.circular(31)` (`height / 2 = 62 / 2 = 31`).
     - Viên thuốc xanh bên trong: `BorderRadius.circular(24)` (`height / 2 = 48 / 2 = 24`).
     - Công thức đồng tâm hoàn hảo: Bán kính ngoài `31` = Bán kính trong `24` + Khoảng đệm `7`.
  3. **Màu sắc & Nổi khối:**
     - Nền vỏ ngoài: Nền đặc 100% Solid White (`Colors.white`), viền hairline `0.8dp` (`#E2E8F0`), bóng đổ mềm đa tầng sâu `8dp` giữ nguyên sự nổi khối cao cấp.
     - Viên thuốc xanh con: `AppTheme.primaryFixed.withOpacity(0.85)` (xanh nhạt pastel êm dịu), bo tròn 24dp.
     - Tab Active: Icon và Text mang màu xanh đậm `AppTheme.primary` (`#005DAC`), in đậm `FontWeight.w700`.
     - Tab Inactive: Icon và Text mang màu xám thanh lịch `AppTheme.onSurfaceVariant` (`#475569`).

---

## 2. CHI TIẾT THÔNG SỐ HÌNH HỌC & MÃ NGUỒN TRIỂN KHAI

### 2.1. Vỏ Ngoài Thanh Nav (`_buildNav` trong `lib/screens/main_shell.dart`)
```dart
Container(
  height: 62, // Chiều cao 62dp tạo khoảng thở thoáng đãng
  margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
  padding: const EdgeInsets.symmetric(horizontal: 4), // Đệm nhẹ chống lẹm mép
  decoration: BoxDecoration(
    color: Colors.white, // Nền đặc 100% Solid White
    borderRadius: BorderRadius.circular(31), // Bo tròn 31dp (62 / 2)
    border: Border.all(
      color: const Color(0xFFE2E8F0),
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
  child: LayoutBuilder(...),
)
```

### 2.2. Khối Viên Thuốc Xanh Con Bao Cả Tab (Active Indicator)
```dart
final itemWidth = constraints.maxWidth / 5;

AnimatedPositioned(
  left: _idx * itemWidth,
  top: 7, // 🎯 Khoảng cách lề trên 7dp đều đặn (62 - 48) / 2
  width: itemWidth,
  height: 48, // Cao 48dp ôm trọn cả Icon + Text
  duration: const Duration(milliseconds: 220),
  curve: Curves.easeOutCubic,
  child: Container(
    margin: const EdgeInsets.symmetric(horizontal: 6), // 🎯 Khoảng hở 6dp hai bên tạo khoảng thở rõ nét
    decoration: BoxDecoration(
      color: AppTheme.primaryFixed.withOpacity(0.85), // Xanh pastel êm mắt
      borderRadius: BorderRadius.circular(24), // Bo tròn đồng tâm hoàn hảo 24dp (48 / 2)
    ),
  ),
)
```

### 2.3. Bố Cục Từng Tab Item (`_navItem`)
```dart
Widget _navItem({
  required IconData icon,
  required IconData activeIcon,
  required String label,
  required int idx,
  required bool active,
  required VoidCallback onTap,
}) {
  return Expanded(
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            scale: active ? 1.04 : 1.0,
            child: Icon(
              active ? activeIcon : icon,
              color: active ? AppTheme.primary : AppTheme.onSurfaceVariant,
              size: 22,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? AppTheme.primary : AppTheme.onSurfaceVariant,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    ),
  );
}
```

---

## 3. TIÊU CHÍ NGHIỆM THU (ACCEPTANCE CRITERIA - AC)

| Mã AC | Tiêu chí nghiệm thu | Tiêu chuẩn đánh giá chi tiết |
| :--- | :--- | :--- |
| **AC-01** | **Khôi phục kiểu dáng viên thuốc xanh bọc cả Icon và Text** | - Khối indicator bên trong có chiều cao `48dp`, bao trọn cả Icon và Label.<br>- Màu nền xanh nhạt pastel `AppTheme.primaryFixed.withOpacity(0.85)`, bo tròn `24dp`. |
| **AC-02** | **Tăng khoảng cách đệm thoáng đãng giữa viên thuốc xanh và vỏ ngoài** | - Khoảng cách lề trên/dưới tăng lên **`7dp`** (`height: 62`, `top: 7`, `indicatorHeight: 48`).<br>- Khoảng cách lề hai bên tăng lên **`6dp`** (`margin: horizontal 6`).<br>- Viên thuốc xanh nằm lọt lòng cân đối, không chạm sát mép, tạo cảm giác thoáng đãng, sang trọng. |
| **AC-03** | **Tỷ lệ bo tròn đồng tâm chuẩn mực (Concentric Radius)** | - Vỏ ngoài: `borderRadius: BorderRadius.circular(31)`.<br>- Viên thuốc trong: `borderRadius: BorderRadius.circular(24)`.<br>- Bán kính bo ngoài `31` = Bán kính trong `24` + Khoảng đệm `7`. |
| **AC-04** | **Giữ trọn vẹn độ nổi khối, Nền đặc & Chuyển Tab Tap-Only 120Hz** | - Nền đặc 100% Solid White `#FFFFFF`, không tốn GPU blur.<br>- Bóng đổ đa tầng hắt sâu `8dp` kết hợp viền hairline `0.8dp`.<br>- Chạm tab nào trượt êm sang tab đó `220ms` (`Curves.easeOutCubic`). |
| **AC-05** | **Bảo toàn Test Suite & Không gây Regression Bug** | - 100% test suites liên quan đến MainShell và Navigation đều PASS. |

---

## 4. QUY TRÌNH ĐIỀU PHỐI TỰ ĐỘNG (AUTONOMOUS CLOSED-LOOP EXECUTION)

1. **Bước 1 (BA Spec):** User duyệt Spec.
2. **Bước 2 (Dev2 Code):** Tự động kích hoạt Sub-agent `dev2` lập trình `lib/screens/main_shell.dart`.
3. **Bước 3 (Tester Verify):** Tự động kích hoạt Sub-agent `tester` kiểm thử độc lập 2 tầng và lập Test Report.
4. **Bước 4 (BA Sign-off):** BA đối soát toàn diện và nghiệm thu bàn giao lại cho User.
