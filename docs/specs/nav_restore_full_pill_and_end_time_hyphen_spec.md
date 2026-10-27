# ĐẶC TẢ KỸ THUẬT (TECHNICAL SPECIFICATION)
## Phân Hệ: Khôi Phục Kiểu Dáng Viên Thuốc Bao Cả Tab (Full-Tab Pill) Kèm Khoảng Đệm Thoáng Đãng (Breathing Padding) & Bổ Sung Dấu Gạch Nối Giờ Kết Thúc ("- 17h05") Trên Widget 4x2

- **Mã tài liệu:** `SPEC-NAV-RESTORE-FULL-PILL-AND-END-TIME-HYPHEN-01`
- **Phiên bản:** `1.1.0`
- **Tác giả:** Senior BA / Hermes Master Orchestrator
- **Dự án:** Trạm Kiến - Ứng dụng Quản lý Học tập & Lịch học HAU (Flutter / Android Kotlin / iOS Swift)
- **Tình trạng:** Chờ User duyệt (Pending Approval)

---

## 1. BỐI CẢNH & PHÂN TÍCH YÊU CẦU CỦA USER

### 1.1. Yêu cầu 1: Khôi phục kiểu dáng viên thuốc bao cả Tab (Icon + Text) & Tăng khoảng đệm thoáng đãng
- **Quyết định:** Người dùng không ưng ý với kiểu viên thuốc nhỏ chỉ bọc quanh icon; yêu cầu **khôi phục lại kiểu dáng ban đầu: Viên thuốc xanh bao trọn cả Icon lẫn Nhãn chữ**, đồng thời **tăng thêm khoảng cách (Breathing Padding)** giữa viên thuốc xanh bên trong và vỏ ngoài.
- **Giải pháp hình học:**
  1. Chiều cao thanh nav vỏ ngoài: **`62dp`**.
  2. Chiều cao viên thuốc xanh bên trong: **`48dp`** (ôm trọn cả Icon `22dp` + Text `10dp` + đệm giữa `2dp`).
  3. Khoảng đệm trên/dưới tăng lên: **`7dp`** (`(62 - 48) / 2 = 7dp`) thay vì 4dp chật chội trước đây.
  4. Khoảng đệm ngang hai bên tab tăng lên: **`6dp`** (`margin: horizontal 6dp`).
  5. Bo tròn đồng tâm hoàn hảo: Vỏ ngoài `BorderRadius.circular(31)`, viên thuốc trong `BorderRadius.circular(24)` (công thức: $31 = 24 + 7$).
  6. Nền đặc 100% Solid White `#FFFFFF`, bóng đổ đa tầng sâu `8dp`, viền hairline `0.8dp`, chuyển tab Tap-Only mượt mà 120Hz.

### 1.2. Yêu cầu 2: Bổ sung dấu gạch "-" ở đầu giờ kết thúc trên Widget 4x2 (Ví dụ: "- 17h05")
- **Hiện trạng từ hình ảnh thực tế (`image_8592d0.png`):**
  - Cột thời gian bên trái widget 4x2 hiện đang hiển thị:
    + Dòng trên (bắt đầu): `12h45`
    + Dòng dưới (kết thúc): `17h05`
  - Việc dòng dưới chỉ có số giờ đơn độc `17h05` chưa thể hiện rõ đây là **mốc giờ kết thúc (đến mấy giờ)**.
- **Giải pháp:**
  - Thêm tiền tố dấu gạch ngang `"- "` vào trước giờ kết thúc:
    + Dòng trên: **`12h45`** (hoặc `12:55`, màu Accent, bold).
    + Dòng dưới: **`- 17h05`** (hoặc `- 17:05`, màu `textSecColor`).
  - Dấu gạch nối giúp người dùng nhìn vào là hiểu ngay ý nghĩa dải thời gian: *Từ `12h45` đến `17h05`*.
  - Đồng bộ trên cả Android Native (`ScheduleWidgetProvider.kt`), iOS WidgetKit (`ScheduleWidgetKit.swift`) và Flutter Widget Studio (`widget_studio_screen.dart`, `shared_widgets.dart`).

---

## 2. CHI TIẾT KỸ THUẬT TRIỂN KHAI

### 2.1. Phân hệ 1: Thanh Điều Hướng Đáy Trong `lib/screens/main_shell.dart`
```dart
// Vỏ ngoài thanh nav (cao 62dp, bo 31dp)
Container(
  height: 62,
  margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
  padding: const EdgeInsets.symmetric(horizontal: 4),
  decoration: BoxDecoration(
    color: Colors.white, // Nền đặc 100% Solid White
    borderRadius: BorderRadius.circular(31),
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
  child: LayoutBuilder(
    builder: (context, constraints) {
      final itemWidth = constraints.maxWidth / 5;
      return Stack(
        children: [
          // Viên thuốc xanh con bọc cả Icon + Text (cao 48dp, lề trên 7dp, lề ngang 6dp)
          AnimatedPositioned(
            left: _idx * itemWidth,
            top: 7,
            width: itemWidth,
            height: 48,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryFixed.withOpacity(0.85),
                borderRadius: BorderRadius.circular(24),
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

### 2.2. Phân hệ 2: Thêm Dấu Gạch "-" Ở Đầu Giờ Kết Thúc Widget 4x2
1. **Android Kotlin (`ScheduleWidgetProvider.kt`):**
   - Trong `extractEndTime(timeSlot)`:
     Khi bóc tách được giờ kết thúc (ví dụ `17h05`), tự động gắn thêm tiền tố `"- "`:
     `return if (raw.isNotEmpty) "- $formatted" else ""`
   - Hiển thị trên `R.id.single_class_1_time_end` và `R.id.single_class_2_time_end` dưới dạng: **`- 17h05`**.
2. **iOS Swift (`ScheduleWidgetKit.swift`):**
   - Trong `extractEndTime(_ timeSlot: String) -> String`:
     `return raw.isEmpty ? "" : "- \(formatted)"`
   - Hiển thị trong nhánh `.systemMedium` dưới dạng: **`- 17h05`**.
3. **Flutter Widget Studio & Shared Widgets (`widget_studio_screen.dart` & `shared_widgets.dart`):**
   - Trong `ScheduleCard.formatEndHour(String timeSlot)`:
     Chuẩn hóa trả về dạng `"- $formatted"` (ví dụ: `"- 17h05"`).
   - Live Preview 4x2 hiển thị đồng bộ 1:1.

---

## 3. TIÊU CHÍ NGHIỆM THU (ACCEPTANCE CRITERIA - AC)

| Mã AC | Tiêu chí nghiệm thu | Tiêu chuẩn đánh giá chi tiết |
| :--- | :--- | :--- |
| **AC-01** | **Khôi phục kiểu dáng viên thuốc xanh bao cả Icon và Text** | - Khối indicator bên trong có chiều cao `48dp`, bao trọn cả Icon và Label.<br>- Màu nền xanh nhạt pastel `AppTheme.primaryFixed.withOpacity(0.85)`, bo tròn `24dp`. |
| **AC-02** | **Tăng khoảng đệm thoáng đãng giữa viên thuốc xanh và vỏ ngoài** | - Khoảng cách lề trên/dưới đạt **`7dp`** (`height: 62`, `top: 7`, `indicatorHeight: 48`).<br>- Khoảng cách lề ngang hai bên đạt **`6dp`** (`margin: horizontal 6`).<br>- Viên thuốc xanh nằm lọt lòng cân đối, không chạm sát mép, tạo cảm giác thoáng đãng, sang trọng. |
| **AC-03** | **Thêm dấu gạch "-" ở đầu giờ kết thúc trên Widget 4x2 (Android & iOS)** | - Giờ kết thúc hiển thị rõ ràng tiền tố dấu gạch ngang (ví dụ: **`- 17h05`** hoặc **`- 11h55`**) trên cả Android Kotlin, iOS Swift và Live Preview Studio. |
| **AC-04** | **Bảo toàn nền đặc Solid White, bóng nổi khối & Tap-Only 120Hz** | - Nền đặc 100% Solid White `#FFFFFF`, bóng đổ đa tầng sâu `8dp`, viền hairline `0.8dp`.<br>- Chuyển tab bằng Tap phản hồi tức thì `220ms` (`Curves.easeOutCubic`). |
| **AC-05** | **Bảo toàn Test Suite & Không gây Regression Bug** | - 100% unit/widget test suites liên quan đến Navigation, MainShell và Widget Timeline đều PASS. |

---

## 4. QUY TRÌNH ĐIỀU PHỐI TỰ ĐỘNG (AUTONOMOUS CLOSED-LOOP EXECUTION)

1. **Bước 1 (BA Spec):** User duyệt Spec.
2. **Bước 2 (Dev2 Code):** Tự động kích hoạt Sub-agent `dev2` lập trình `lib/screens/main_shell.dart`, `ScheduleWidgetProvider.kt`, `ScheduleWidgetKit.swift`, `shared_widgets.dart`, `widget_studio_screen.dart`.
3. **Bước 3 (Tester Verify):** Tự động kích hoạt Sub-agent `tester` kiểm thử độc lập 2 tầng và lập Test Report.
4. **Bước 4 (BA Sign-off):** BA đối soát toàn diện và nghiệm thu bàn giao lại cho User.
