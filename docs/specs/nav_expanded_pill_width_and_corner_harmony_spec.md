# ĐẶC TẢ KỸ THUẬT (TECHNICAL SPECIFICATION)
## Phân Hệ: Tối Ưu Hóa Chiều Ngang Viên Thuốc Xanh Con (Expanded Width, Margin 2dp) & Cân Chỉnh Bo Góc Đồng Dạng Thanh Điều Hướng Đáy (Trong 18dp, Ngoài 28dp)

- **Mã tài liệu:** `SPEC-NAV-EXPANDED-PILL-WIDTH-AND-CORNER-HARMONY-01`
- **Phiên bản:** `1.0.0`
- **Tác giả:** Senior BA / Hermes Master Orchestrator
- **Dự án:** Trạm Kiến - Ứng dụng Quản lý Học tập & Lịch học HAU (Flutter / Android Kotlin / iOS Swift)
- **Tình trạng:** Chờ User duyệt (Pending Approval)

---

## 1. BỐI CẢNH & PHÂN TÍCH HÌNH HỌC

### 1.1. Vấn đề thực tế từ hình ảnh người dùng (`image_729cb5.png`)
- Viên thuốc xanh con (Active Indicator) bên trong đang bọc cả Icon và Text chữ "Tổng quan".
- Nhưng do đang để `margin: horizontal 5dp`, chiều ngang của viên thuốc xanh bị co hẹp lại chỉ còn khoảng `58dp`.
- Kết hợp với việc bo tròn cực đại `BorderRadius.circular(24)` (nửa hình tròn), hai góc cong của viên thuốc lẹm sâu vào vùng chân chữ, khiến hai ký tự đầu/cuối (`T` và `n` của chữ "Tổng quan") chạm sát sạt vào mép cong bo tròn, tạo cảm giác chật chội, tức mắt và thiếu khoảng thở.

### 1.2. Giải pháp hình học tối ưu:
1. **Nới rộng chiều ngang viên thuốc xanh bằng cách giảm margin ngang từ `5dp` xuống `2dp`:**
   - Trong `AnimatedPositioned`: `margin: const EdgeInsets.symmetric(horizontal: 2)`.
   - Chiều ngang viên thuốc xanh tăng thêm **`6dp`**, đạt khoảng **`64dp`**, tạo không gian rộng rãi cho các dòng chữ dài như "Tổng quan", "Tài khoản".
   - Khoảng cách giữa các tab liền kề vẫn duy trì khoảng hở `4dp` độc lập, không bị dính vào nhau.
2. **Cân chỉnh lại bán kính bo góc trong và ngoài (Corner Radii Harmony):**
   - **Vỏ ngoài thanh nav:** Chiều cao **`62dp`**, bán kính bo góc **`28dp`** (mềm mại, thanh thoát, không bị tròn xoe như quả bóng).
   - **Viên thuốc xanh bên trong:** Chiều cao **`48dp`**, bán kính bo góc **`18dp`** (thay vì 24dp cũ).
   - Góc bo `18dp` vừa đủ cong để tạo cảm giác viên thuốc mềm mại tự nhiên, vừa giữ được độ phẳng của cạnh đáy, giúp hai đầu chữ "Tổng quan" cách mép cong tới `6dp - 7dp`, cực kỳ thoáng mắt.
3. **Bảo toàn nền đặc Solid White 100%, bóng đổ sâu 8dp và tương tác Tap-Only 120Hz.**

---

## 2. CHI TIẾT THÔNG SỐ TRONG MÃ NGUỒN (`lib/screens/main_shell.dart`)

### 2.1. Vỏ ngoài thanh nav (`_buildNav`)
```dart
Container(
  height: 62,
  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
  padding: const EdgeInsets.symmetric(horizontal: 2), // Đệm nhẹ 2dp
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(28), // 🎯 Bo góc vỏ ngoài 28dp mềm mại thanh thoát
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

### 2.2. Khối viên thuốc xanh con (`AnimatedPositioned`)
```dart
final itemWidth = constraints.maxWidth / 5;

AnimatedPositioned(
  left: _idx * itemWidth,
  top: 7, // Giữ khoảng đệm trên 7dp cân đối
  width: itemWidth,
  height: 48,
  duration: const Duration(milliseconds: 220),
  curve: Curves.easeOutCubic,
  child: Container(
    margin: const EdgeInsets.symmetric(horizontal: 2), // 🎯 Giảm từ 5dp xuống 2dp để nới rộng width thêm 6dp
    decoration: BoxDecoration(
      color: AppTheme.primaryFixed.withOpacity(0.85),
      borderRadius: BorderRadius.circular(18), // 🎯 Cân chỉnh bo góc 18dp: mềm mại nhưng không chẹt chữ
    ),
  ),
)
```

---

## 3. TIÊU CHÍ NGHIỆM THU (ACCEPTANCE CRITERIA - AC)

| Mã AC | Tiêu chí nghiệm thu | Tiêu chuẩn đánh giá chi tiết |
| :--- | :--- | :--- |
| **AC-01** | **Nới rộng chiều ngang viên thuốc xanh con (margin ngang 2dp)** | - `Container` của indicator con có `margin: EdgeInsets.symmetric(horizontal: 2)`.<br>- Tăng thêm 6dp chiều ngang, giải phóng không gian thở cho nhãn chữ. |
| **AC-02** | **Cân chỉnh góc bo viên thuốc trong thành 18dp** | - Khối indicator bên trong áp dụng `BorderRadius.circular(18)`.<br>- Cạnh đáy phẳng rộng hơn, hai đầu ký tự `T` và `n` không còn bị góc cong chèn ép. |
| **AC-03** | **Cân chỉnh góc bo vỏ ngoài thanh nav thành 28dp** | - Vỏ ngoài thanh nav áp dụng `BorderRadius.circular(28)`.<br>- Tỷ lệ hình học giữa vỏ ngoài (28dp) và viên trong (18dp) đạt sự hài hòa, tự nhiên. |
| **AC-04** | **Bảo toàn nền Solid White, lề 16dp và tương tác Tap-Only 120Hz** | - Nền 100% Solid White `#FFFFFF`, viền hairline 0.8dp, bóng đổ đa tầng sâu 8dp.<br>- Chuyển tab Tap-Only mượt mà 220ms (`Curves.easeOutCubic`). |
| **AC-05** | **Bảo toàn Test Suite & Không gây Regression Bug** | - 100% unit/widget test suites liên quan đều PASS. |

---

## 4. QUY TRÌNH ĐIỀU PHỐI TỰ ĐỘNG (AUTONOMOUS CLOSED-LOOP EXECUTION)

1. **Bước 1 (BA Spec):** User duyệt Spec.
2. **Bước 2 (Dev2 Code):** Tự động kích hoạt Sub-agent `dev2` lập trình `lib/screens/main_shell.dart`.
3. **Bước 3 (Tester Verify):** Tự động kích hoạt Sub-agent `tester` kiểm thử độc lập 2 tầng và lập Test Report.
4. **Bước 4 (BA Sign-off):** BA đối soát toàn diện và nghiệm thu bàn giao lại cho User.
