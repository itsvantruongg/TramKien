# ĐẶC TẢ KỸ THUẬT (TECHNICAL SPECIFICATION)
## Phân Hệ: Tinh Chỉnh Khối Active Tab Thanh Điều Hướng Đáy: Chuyển Sang Dạng Thẻ Bo Mềm Tự Nhiên (Soft Squircle Card 14dp) Chuẩn Swiss & Apple Design

- **Mã tài liệu:** `SPEC-NAV-SOFT-SQUIRCLE-ACTIVE-INDICATOR-01`
- **Phiên bản:** `1.0.0`
- **Tác giả:** Senior BA / Hermes Master Orchestrator
- **Dự án:** Trạm Kiến - Ứng dụng Quản lý Học tập & Lịch học HAU (Flutter / Android Kotlin / iOS Swift)
- **Tình trạng:** Chờ User duyệt (Pending Approval)

---

## 1. BỐI CẢNH & PHÂN TÍCH YÊU CẦU

### 1.1. Hiện trạng & Phản hồi thực tế từ người dùng (`image_c30845.png`)
- Người dùng nhận xét: *"viên thuốc nhỏ bên trong bạn bo tròn làm gì, để nó tự nhiên chứ"*.
- Khối active tab hiện tại đang bị ép bo tròn cực đại `BorderRadius.circular(24)` thành một hình viên thuốc tròn xoe lồng bên trong vỏ ngoài cũng là viên thuốc (Nested Capsule Problem).
- Hình dạng tròn xoe này tạo cảm giác gượng gạo, quá đà (over-rounded/toy-like). Đồng thời, độ vát cong quá sâu của hình tròn ở hai góc đáy làm chèn ép nhãn chữ *"Tổng quan"*, khiến chữ trông như bị dính sát mép cong bên dưới.

### 1.2. Giải pháp kỹ thuật (Soft Squircle Card 14dp)
- **Chuyển khối Active bên trong từ bo tròn xoe (24dp) sang Bo Mềm Tự Nhiên (14dp):**
  - Sử dụng `BorderRadius.circular(14)` (dạng Soft Card / Squircle).
  - Cạnh đáy và hai bên của khối indicator giữ được độ phẳng tự nhiên, tạo khoảng thở (Breathing Room) đều đặn cho cả Icon lẫn Text, không còn hiện tượng đường cong chẹt vào chân chữ.
  - Phá vỡ thế xung đột "viên thuốc lồng trong viên thuốc", tạo ra sự phân cấp hình học cao cấp và tự nhiên chuẩn Swiss / Apple Design.
- **Màu nền êm dịu:**
  - Khối active dùng màu xanh lam pastel dịu nhẹ: `AppTheme.primary.withOpacity(0.09)`.
  - Icon (`size: 22`) và Text (`10sp`, `FontWeight.w700`) giữ màu xanh nhận diện `AppTheme.primary` (`#005DAC`).

---

## 2. CHI TIẾT THÔNG SỐ HÌNH HỌC TRONG MÃ NGUỒN

### 2.1. Cấu hình Khối Active Indicator trong `lib/screens/main_shell.dart`
```dart
final itemWidth = constraints.maxWidth / 5;

AnimatedPositioned(
  left: _idx * itemWidth,
  top: 7,
  width: itemWidth,
  height: 48,
  duration: const Duration(milliseconds: 220),
  curve: Curves.easeOutCubic,
  child: Container(
    margin: const EdgeInsets.symmetric(horizontal: 5), // Khoảng đệm ngang 5dp cân đối
    decoration: BoxDecoration(
      color: AppTheme.primary.withOpacity(0.09), // Xanh pastel êm dịu tự nhiên
      borderRadius: BorderRadius.circular(14), // 🎯 Bo mềm tự nhiên 14dp, không bo tròn xoe 24dp
    ),
  ),
)
```

---

## 3. TIÊU CHÍ NGHIỆM THU (ACCEPTANCE CRITERIA - AC)

| Mã AC | Tiêu chí nghiệm thu | Tiêu chuẩn đánh giá chi tiết |
| :--- | :--- | :--- |
| **AC-01** | **Khối Active Tab chuyển sang dạng Thẻ bo mềm tự nhiên 14dp** | - Khối indicator bên trong đổi từ `BorderRadius.circular(24)` sang `BorderRadius.circular(14)`.<br>- Cạnh đáy và các góc hiển thị tự nhiên, không còn tròn xoe như viên thuốc. |
| **AC-02** | **Khoảng thở của chữ và Icon đều đặn, không bị chèn ép góc cong** | - Nhãn chữ (*Tổng quan, Lịch học, Điểm số, Học phí, Tài khoản*) nằm lọt lòng ngay ngắn, khoảng đệm trên/dưới/trái/phải cân đối. |
| **AC-03** | **Bảo toàn nền Solid White, chuyển động Tap-Only 220ms & Độ nổi khối** | - Nền thanh nav giữ 100% Solid White, viền hairline `0.8dp`, bóng đổ đa tầng sâu 8dp.<br>- Chuyển tab Tap-Only mượt mà 120Hz qua `AnimatedPositioned(duration: 220ms, curve: Curves.easeOutCubic)`. |
| **AC-04** | **Bảo toàn Test Suite & Không gây Regression Bug** | - 100% unit/widget test suites liên quan đến MainShell và Navigation đều PASS. |

---

## 4. QUY TRÌNH ĐIỀU PHỐI TỰ ĐỘNG (AUTONOMOUS CLOSED-LOOP EXECUTION)

1. **Bước 1 (BA Spec):** User duyệt Spec.
2. **Bước 2 (Dev2 Code):** Tự động kích hoạt Sub-agent `dev2` lập trình `lib/screens/main_shell.dart`.
3. **Bước 3 (Tester Verify):** Tự động kích hoạt Sub-agent `tester` kiểm thử độc lập 2 tầng và lập Test Report.
4. **Bước 4 (BA Sign-off):** BA đối soát toàn diện và nghiệm thu bàn giao lại cho User.
