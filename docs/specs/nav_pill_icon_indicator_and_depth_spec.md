# ĐẶC TẢ KỸ THUẬT (TECHNICAL SPECIFICATION)
## Phân Hệ: Tối Ưu Hóa Thanh Điều Hướng Viên Thuốc Đáy: Tinh Chỉnh Khối Active Bao Quanh Icon (Pill-Icon Indicator), Nâng Chiều Cao 60dp & Tăng Cường Độ Nổi Khối Chuẩn Apple / Swiss Design

- **Mã tài liệu:** `SPEC-NAV-PILL-ICON-INDICATOR-AND-DEPTH-01`
- **Phiên bản:** `1.0.0`
- **Tác giả:** Senior BA / Hermes Master Orchestrator
- **Dự án:** Trạm Kiến - Ứng dụng Quản lý Học tập & Lịch học HAU (Flutter / Android Kotlin / iOS Swift)
- **Tình trạng:** Chờ User duyệt (Pending Approval)

---

## 1. BỐI CẢNH & PHÂN TÍCH HIỆN TRẠNG (DESIGN FLAWS)

### 1.1. Vấn đề 1: Viên thuốc con (Active Indicator) bọc cả Icon và Text gây chật chội, cục mịch
- **Hiện trạng:**
  - Trong `lib/screens/main_shell.dart:345`, khối active indicator là một hình chữ nhật bo tròn cao `48dp` ôm trọn cả Icon (`24dp`) lẫn Text (`10dp`) với lề trên/dưới chỉ vỏn vẹn `4dp`.
  - Bố cục này tạo cảm giác chật chội, nặng nề (heavy visual weight), làm giảm độ thanh thoát và thanh lịch của giao diện.
- **Giải pháp (Phương án 1):**
  - **Tách biệt Icon và Text:** Khối active indicator thu nhỏ kích thước chỉ bọc vừa vặn xung quanh Icon:
    + Chiều cao viên thuốc con: **`32dp`**, chiều rộng: **`56dp`** (hoặc co giãn theo tab width), bo tròn hoàn hảo **`16dp`** (`height / 2`).
    + Màu nền: `AppTheme.primary.withOpacity(0.12)` (xanh lam nhạt trong trẻo).
  - **Nhãn chữ (Label Text) nằm độc lập bên dưới:**
    + Khi Active: Nhãn chữ in đậm `FontWeight.w700`, mang màu thương hiệu `AppTheme.primary` (`#005DAC`), không bị khối màu bao bọc, tạo "không gian thở" (Breathing room) cực kỳ thoáng đãng.
    + Khi Inactive: Nhãn chữ màu xám thanh lịch `AppTheme.onSurfaceVariant` (`#475569`), `FontWeight.w500`.

### 1.2. Vấn đề 2: Thanh điều hướng bị chìm trên nền sáng & Chiều cao 56dp hơi kích dọc
- **Hiện trạng:**
  - Nền ứng dụng là màu xám trắng rất nhạt (`#F8F9FA`), thanh nav dùng màu trắng tinh (`#FFFFFF`).
  - Bóng đổ hiện tại (`BoxShadow` mờ nhạt `offset: (0, 4)`) khiến ranh giới thanh nav bị hòa lẫn vào nền, thiếu cảm giác nổi lơ lửng (Floating) thực sự.
  - Chiều cao `56dp` khi bố trí cả Icon và Text 2 tầng dễ bị sát mép.
- **Giải pháp:**
  - Nâng chiều cao thanh nav từ `56dp` lên **`60dp`** (tỷ lệ vàng cho thanh bottom nav 5 tabs theo chuẩn Apple HIG & Telegram).
  - Bo tròn vỏ ngoài: **`30dp`** (`height / 2`).
  - **Tăng cường bóng đổ mềm đa tầng (Multi-layer Ambient Shadow):**
    + Lớp 1 (Ambient Deep Shadow): `BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 24, spreadRadius: -4, offset: Offset(0, 8))`
    + Lớp 2 (Soft Accent Tint): `BoxShadow(color: AppTheme.primary.withOpacity(0.04), blurRadius: 10, offset: Offset(0, 2))`
    + Viền hairline sắc sảo: `Border.all(color: Color(0xFFE2E8F0), width: 0.8)`
  - Thanh nav tách bạch rõ rệt trên nền sáng, sang trọng và nổi khối tự nhiên.

### 1.3. Vấn đề 3: Vùng chạm hai bên mép (Tap Target) bị lẹm vào góc bo cong
- **Hiện trạng:**
  - Hai tab ngoài cùng (*Tổng quan* và *Tài khoản*) bị nằm sát vào góc bo cong `28dp` của vỏ ngoài, ngón tay cái khi bấm dễ bị hụt hoặc chạm sát mép.
- **Giải pháp:**
  - Thêm khoảng đệm bên trong: `padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4)` giúp đẩy 2 tab ngoài cùng vào vùng tiếp xúc tối ưu, đảm bảo vùng bấm cảm ứng chuẩn $\ge 48\text{dp}$.

---

## 2. CHI TIẾT THÔNG SỐ HÌNH HỌC & KIẾN TRÚC MÃ NGUỒN

### 2.1. Cấu hình Vỏ Ngoài (Main Capsule Container)
```dart
Container(
  height: 60, // Chiều cao chuẩn mực 60dp
  margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
  padding: const EdgeInsets.symmetric(horizontal: 6),
  decoration: BoxDecoration(
    color: Colors.white, // 100% Solid White
    borderRadius: BorderRadius.circular(30), // Bo tròn 30dp (60 / 2)
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
  child: LayoutBuilder(...),
)
```

### 2.2. Khối Active Indicator (Viên thuốc nhỏ chỉ bọc Icon)
```dart
final itemWidth = constraints.maxWidth / 5;
final indicatorWidth = (itemWidth - 12).clamp(44.0, 56.0); // Rộng vừa vặn quanh icon

AnimatedPositioned(
  left: _idx * itemWidth + (itemWidth - indicatorWidth) / 2,
  top: 6, // Căn ngay ngắn bao quanh Icon
  width: indicatorWidth,
  height: 32, // Cao 32dp chuẩn pill-icon
  duration: const Duration(milliseconds: 220),
  curve: Curves.easeOutCubic,
  child: Container(
    decoration: BoxDecoration(
      color: AppTheme.primary.withOpacity(0.12), // Nền xanh nhạt trong trẻo
      borderRadius: BorderRadius.circular(16), // Bo tròn 16dp
    ),
  ),
)
```

### 2.3. Bố cục từng Tab Item (`_navItem`)
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
        children: [
          SizedBox(
            height: 32, // Khung đồng bộ với chiều cao indicator
            child: Center(
              child: AnimatedScale(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                scale: active ? 1.05 : 1.0,
                child: Icon(
                  active ? activeIcon : icon,
                  color: active ? AppTheme.primary : AppTheme.onSurfaceVariant,
                  size: 22,
                ),
              ),
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
              letterSpacing: -0.2,
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

| Mã AC | Tiêu chí nghiệm thu | Tiêu chuẩn đánh giá |
| :--- | :--- | :--- |
| **AC-01** | **Viên thuốc Active chỉ bọc quanh Icon (Pill-Icon)** | - Indicator có chiều cao `32dp`, bo tròn `16dp`, màu `AppTheme.primary.withOpacity(0.12)`.<br>- Nhãn chữ nằm thoáng bên dưới, không bị viên thuốc bọc quanh. |
| **AC-02** | **Nâng chiều cao thanh nav lên 60dp & Bo tròn 30dp** | - Vỏ ngoài thanh nav có chiều cao `height: 60`, bo tròn `BorderRadius.circular(30)`.<br>- Bố cục dọc thoáng đãng, các tab không bị kích sát mép trên/dưới. |
| **AC-03** | **Độ nổi khối đa tầng (Multi-layer Elevation Shadow)** | - Thêm 2 lớp bóng đổ (`blurRadius: 24` và `blurRadius: 10` ám xanh nhẹ) kết hợp viền hairline `0.8dp`.<br>- Thanh nav nổi bật rõ rệt trên nền sáng, không bị chìm hay hòa lẫn. |
| **AC-04** | **Phản hồi chuyển tab Tap-Only mượt mà (220ms)** | - Active Indicator trượt êm ái sang tab được bấm bằng `AnimatedPositioned` (`duration: 220ms, curve: Curves.easeOutCubic`).<br>- Chữ và icon đổi trạng thái tức thì không có độ trễ. |
| **AC-05** | **Bảo toàn Test Suite & Không gây Regression Bug** | - 100% unit/widget test suites liên quan đến MainShell và Navigation đều PASS. |

---

## 4. QUY TRÌNH ĐIỀU PHỐI TỰ ĐỘNG (AUTONOMOUS CLOSED-LOOP EXECUTION)

1. **Bước 1 (BA Spec):** User duyệt Spec.
2. **Bước 2 (Dev2 Code):** Tự động kích hoạt Sub-agent `dev2` lập trình `lib/screens/main_shell.dart`.
3. **Bước 3 (Tester Verify):** Tự động kích hoạt Sub-agent `tester` kiểm thử độc lập 2 tầng và lập Test Report.
4. **Bước 4 (BA Sign-off):** BA đối soát toàn diện và nghiệm thu bàn giao lại cho User.
