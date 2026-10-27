# ĐẶC TẢ KỸ THUẬT (TECHNICAL SPECIFICATION)
## Phân Hệ: Đồng Bộ Tuyệt Đối Lề 16dp Toàn Bộ Ứng Dụng (Header 16dp, Body Tất Cả Các Trang 16dp, Nav 16dp) & Khôi Phục Viên Thuốc Tròn Đồng Dạng (Capsule Indicator 24dp)

- **Mã tài liệu:** `SPEC-UNIFIED-16DP-GRID-AND-CAPSULE-RESTORE-01`
- **Phiên bản:** `1.0.0`
- **Tác giả:** Senior BA / Hermes Master Orchestrator
- **Dự án:** Trạm Kiến - Ứng dụng Quản lý Học tập & Lịch học HAU (Flutter / Android Kotlin / iOS Swift)
- **Tình trạng:** Chờ User duyệt (Pending Approval)

---

## 1. BỐI CẢNH & NGUYÊN TẮC GIÓNG HÀNG 16DP DUY NHẤT

### 1.1. Mục tiêu thống nhất: Chuẩn 16dp Grid trên Toàn Bộ Ứng Dụng
Toàn bộ ứng dụng từ đỉnh xuống đáy được gióng thẳng tắp trên **một đường lề 16dp duy nhất**:
1. **Header (`AcademicAppBar`):** Lề trái giữ nguyên chuẩn **`16dp`** (`padding: fromLTRB(16, 6, 8, 6)`), mép Logo tròn cách viền đúng 16dp.
2. **Nội dung tất cả các trang chính (Dashboard, Schedule, Grades, Finance, Profile):**
   - Chuyển lề hai bên từ `20dp` xuống chuẩn **`16dp`**.
   - Mép tất cả các Card nội dung dóng thẳng hàng tuyệt đối với Logo Header.
3. **Thanh điều hướng đáy (Nav Pill):**
   - Đặt lề hai bên chuẩn **`16dp`** (`margin: fromLTRB(16, 0, 16, 16)`).
   - Mép thanh điều hướng dóng thẳng hàng tuyệt đối với mép Card nội dung và Header.
4. **Khôi phục viên thuốc xanh con bên trong:**
   - Bo tròn đồng dạng mềm mại **`24dp`** ($48 / 2$), chấm dứt hoàn toàn tình trạng vuông vắn lệch tông.

### 1.2. Cam kết phạm vi nghiêm ngặt (Strict Boundary Rule)
- **CHỈ SỬA LỀ HAI BÊN (Left & Right) TỪ 20DP XUỐNG 16DP.**
- **TUYỆT ĐỐI KHÔNG THAY ĐỔI LỀ TRÊN (Top) VÀ LỀ DƯỚI (Bottom/Scroll padding)** của bất kỳ trang nào, đảm bảo bảo toàn 100% bố cục và khoảng cách gốc của ứng dụng.

---

## 2. CHI TIẾT THAY ĐỔI THEO TỪNG TỆP TIN

### 2.1. Thanh Điều Hướng Đáy (`lib/screens/main_shell.dart`)
- Lề hai bên thanh nav: `margin: const EdgeInsets.fromLTRB(16, 0, 16, 16)` (lề đáy giữ nguyên 16dp).
- Chiều cao vỏ ngoài: `62dp`, bo tròn `31dp` (`62 / 2`), viền hairline `0.8dp`, bóng đổ sâu `8dp`.
- Khối Active Indicator con:
  - Chiều cao `48dp`, lề trên `7dp`, lề ngang hai bên tab `margin: horizontal 5dp`.
  - Bo tròn viên thuốc mềm mại: **`BorderRadius.circular(24)`** (thay cho `14dp` vuông vức).

### 2.2. Trang Tổng quan (`lib/screens/dashboard_screen.dart`)
- SliverPadding danh sách: `padding: const EdgeInsets.fromLTRB(16, 0, 16, 100)` (sửa 20 thành 16 ở lề trái và lề phải; lề top 0 và bottom 100 giữ nguyên).

### 2.3. Trang Lịch học (`lib/screens/schedule_screen.dart`)
- Thanh chọn tuần / điều hướng: `margin: const EdgeInsets.fromLTRB(16, 8, 16, 8)`.
- Các khối nội dung & danh sách: sửa padding lề 2 bên thành `16dp` (giữ nguyên top/bottom).

### 2.4. Trang Điểm số (`lib/screens/grades_screen.dart`)
- Các khối Card tổng quan GPA và danh sách môn: sửa lề 2 bên thành `16dp` (giữ nguyên top/bottom).

### 2.5. Trang Tài chính / Học phí (`lib/screens/finance_screen.dart`)
- Các khối Card học phí và danh sách: sửa lề 2 bên thành `16dp` (giữ nguyên top/bottom).

### 2.6. Trang Tài khoản (`lib/screens/profile_screen.dart`)
- Card thông tin sinh viên và danh sách cài đặt: sửa lề 2 bên thành `16dp` (giữ nguyên top/bottom).

### 2.7. Header dùng chung (`lib/widgets/shared_widgets.dart`)
- `AcademicAppBar`: `padding: const EdgeInsets.fromLTRB(16, 6, 8, 6)` $\rightarrow$ Logo lề trái `16dp` tự động gióng thẳng tắp với mép Card `16dp` của tất cả các trang!

---

## 3. TIÊU CHÍ NGHIỆM THU (ACCEPTANCE CRITERIA - AC)

| Mã AC | Tiêu chí nghiệm thu | Tiêu chuẩn đánh giá chi tiết |
| :--- | :--- | :--- |
| **AC-01** | **Đồng bộ lề 2 bên 16dp cho toàn bộ các trang nội dung** | - `DashboardScreen`, `ScheduleScreen`, `GradesScreen`, `FinanceScreen`, `ProfileScreen` đều áp dụng lề 2 bên `16dp`.<br>- Lề top và bottom của tất cả các trang được giữ nguyên vẹn 100%. |
| **AC-02** | **Thanh điều hướng đáy áp dụng lề 2 bên 16dp** | - `MainShell` thanh nav có `margin: fromLTRB(16, 0, 16, 16)`.<br>- Mép thanh nav dóng thẳng tắp với mép Card nội dung 16dp bên trên. |
| **AC-03** | **Header dóng thẳng tắp 16dp với toàn bộ nội dung** | - Logo tròn của `AcademicAppBar` (lề trái 16dp) dóng thẳng hàng tuyệt đối với mép Card nội dung 16dp của cả 5 trang. |
| **AC-04** | **Khôi phục kiểu dáng viên thuốc tròn đồng dạng (Capsule 24dp)** | - Khối indicator bên trong dùng `BorderRadius.circular(24)` ($48 / 2$), bo tròn viên thuốc mềm mại đồng dạng với vỏ ngoài `31dp`.<br>- Chấm dứt hoàn toàn tình trạng vuông vắn. |
| **AC-05** | **Bảo toàn Test Suite & Không gây Regression Bug** | - 100% unit/widget test suites liên quan đều PASS. |

---

## 4. QUY TRÌNH ĐIỀU PHỐI TỰ ĐỘNG (AUTONOMOUS CLOSED-LOOP EXECUTION)

1. **Bước 1 (BA Spec):** User duyệt Spec.
2. **Bước 2 (Dev2 Code):** Tự động kích hoạt Sub-agent `dev2` lập trình toàn bộ các file.
3. **Bước 3 (Tester Verify):** Tự động kích hoạt Sub-agent `tester` kiểm thử độc lập 2 tầng và lập Test Report.
4. **Bước 4 (BA Sign-off):** BA đối soát toàn diện và nghiệm thu bàn giao lại cho User.
