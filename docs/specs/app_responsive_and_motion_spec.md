# Technical Specification: Chuẩn Hóa Responsive Đa Màn Hình (Tablet/Landscape), Chuyển Động Motion System & Tinh Chỉnh UI Theo Chuẩn Google Codelabs

- **Mã tài liệu:** SPEC-RESPONSIVE-MOTION-01
- **Phân hệ:** Adaptive Layout (Breakpoints, NavigationRail, Container MaxWidth), Motion System (FadeThrough, Page Transitions), Screen Audit (All Screens)
- **Tác giả:** Master Orchestrator & Senior Business Analyst
- **Đối chiếu chuẩn:** Google Codelabs (`animated-responsive-layout`, `animations/step_05_d`, `homescreen_codelab`), Material Design 3 Motion System, Swiss Typography & Apple HIG
- **Trạng thái:** Drafted by Senior BA / Ready for User Approval & Dev Delegation

---

## 1. TỔNG QUAN PHÂN TÍCH HIỆN TRẠNG (GAP ANALYSIS)

Đối chiếu toàn bộ mã nguồn `lib/screens/` với kho lưu trữ `D:\Documents\Flutter\Learn FLutter App\codelabs`:

| Màn hình / Phân hệ | Hiện trạng trong dự án Trạm Kiến | Chuẩn mực Google Codelabs (`codelabs/`) | Đánh giá & Rủi ro |
| :--- | :--- | :--- | :--- |
| **Bố cục khung vỏ (`MainShell`)** | Bị gán cứng 100% cho điện thoại dọc (`width < 600`). Thanh BottomBar kính mờ giãn tự do theo `constraints.maxWidth` $\rightarrow$ Trên tablet rộng 1000px, thanh đáy bị kéo dài 1000px, 5 nút bấm cách nhau 200px trống hoác. | Codelab `animated-responsive-layout`: Phân chia breakpoints chuẩn: Compact ($< 600\text{dp}$), Medium ($600 - 840\text{dp}$), Expanded ($> 840\text{dp}$). Tự động chuyển sang `NavigationRail` bên trái hoặc giới hạn `maxWidth: 560dp` căn giữa cho BottomBar. | **Mức độ: Nghiêm trọng (P0)**. Giao diện bị vỡ bố cục hoàn toàn trên iPad, Android Tablet và khi xoay ngang điện thoại. |
| **Chuyển động chuyển tab (`MainShell`)** | Dùng `SlideTransition` + `FadeTransition` thủ công trượt cả khối `IndexedStack` (130ms). Khi trượt, cả 5 trang đều bị trượt theo phương ngang gây cảm giác giật cục và nhấp nháy. | Codelab `animations` & Material 3: Sử dụng **`FadeThroughTransition`** (Material Motion). Khi chuyển tab: tab cũ mờ dần và thu nhỏ nhẹ ($92\% \rightarrow 100\%$), tab mới phóng to nhẹ và rõ dần. Đây là tiêu chuẩn vàng của Google cho Top-level Destinations. | **Mức độ: Cao (P1)**. Tự chế animation trượt ngang thô sơ thay vì dùng chuẩn Material Motion. |
| **Màn hình Lịch học (`ScheduleScreen`)** | Dòng 356 tính kích thước ô lịch: `cellSize = (MediaQuery.of(context).size.width - 80) / 7`. Trên tablet 1000px $\rightarrow$ ô lịch to $131\text{px}$, lưới tháng cao tới gần $800\text{px}$, chiếm trọn màn hình và đẩy danh sách ca học biến mất khỏi tầm nhìn! | Codelab `animated-responsive-layout`: Bọc lưới lịch trong container có giới hạn `maxWidth` (tối đa $460\text{dp}$), hoặc trên màn hình rộng chia 2 cột: Cột trái là Lịch tháng, Cột phải là Danh sách ca học. | **Mức độ: Nghiêm trọng (P0)**. Vỡ màn hình lịch trên tablet/xoay ngang. |
| **Màn hình Đăng nhập (`LoginScreen`)** | Dòng 140: Thẻ đăng nhập và các trường nhập MSSV/Mật khẩu giãn 100% chiều ngang màn hình không có giới hạn `maxWidth`. Trên tablet/máy tính bảng, form đăng nhập kéo dài 1100px bè bè. | Codelab Responsive: Form đăng nhập luôn có `maxWidth: 420dp` đặt căn giữa màn hình (`Center`), giữ tỷ lệ thị giác cân đối chuẩn mực. | **Mức độ: Cao (P1)**. Form đăng nhập dị dạng trên màn hình rộng. |
| **Các màn hình nội dung (`Dashboard`, `Grades`, `Finance`, `Profile`)** | Tất cả thẻ nội dung (`SurfaceCard`, `GradientCard`, `Bento row`) giãn `match_parent` theo chiều ngang. Trên màn hình lớn, các dòng chữ và số liệu bị kéo dài quá tầm quét mắt của người dùng. | Codelab `animated-responsive-layout` & Swiss Grid: Content feed có `maxWidth: 680dp` - $720\text{dp}$ căn giữa màn hình trên thiết bị rộng, hoặc chia cột Bento thông minh. | **Mức độ: Trung bình (P2)**. Giảm trải nghiệm đọc và công thái học (ergonomics). |
| **Hiệu ứng nhấn Card (`PressScale`)** | Tự viết `StatefulWidget` + `GestureDetector` + `AnimatedScale` (dòng 784 `shared_widgets.dart`), không tích hợp Ink splash hay haptic feedback. | Codelab `animations`: Kết hợp `InkWell` với Material ripple effect hoặc `Transform.scale` chuẩn hóa. | **Mức độ: Thấp (P3)**. Cần tinh chỉnh nhẹ để mượt mà hơn. |
| **Hiệu ứng tải dữ liệu (`SkeletonBox`)** | Dòng 474 `shared_widgets.dart`: Mỗi `SkeletonBox` tự khởi tạo riêng 1 `AnimationController(1200ms)..repeat(reverse: true)` chạy độc lập. Khi một trang có 15-30 ô skeleton, 30 controllers chạy lệch pha nhau, chớp nháy hỗn loạn như đèn nhấp nháy, ngốn CPU/pin, thiếu hiệu ứng quét dải sáng (LinearGradient Shimmer sweep). | Google Flutter Cookbook & Material Guidelines: Sử dụng **Synchronized Shimmer Shader / Gradient Sweep ($135^\circ$)**. Một `AnimationController` duy nhất đồng bộ cho toàn bộ màn hình, các ô placeholder bên dưới ăn theo cùng 1 sóng ánh sáng lướt qua mượt mà, triệt tiêu 100% lãng phí tài nguyên. | **Mức độ: Cao (P1)**. Chớp nháy bất đồng bộ gây khó chịu thị giác và hao pin thiết bị. |

---

## 2. GIẢI PHÁP THIẾT KẾ & KIẾN TRÚC CHI TIẾT

### 2.1. Phân hệ Responsive Breakpoints & Adaptive Shell (`lib/screens/main_shell.dart`)
1. **Thiết lập Breakpoints chuẩn Google Codelab:**
   - **Compact ($W < 600\text{dp}$):** Điện thoại thông thường.
     - Giữ nguyên Floating Glass Bottom Bar 5 tab, nhưng giới hạn `maxWidth: 500dp` căn giữa (`Align(alignment: Alignment.bottomCenter, child: ConstrainedBox(constraints: BoxConstraints(maxWidth: 500), ...))`).
   - **Medium & Expanded ($W \ge 600\text{dp}$):** Tablet, màn hình xoay ngang, desktop.
     - Tự động chuyển đổi mượt mà sang **NavigationRail** đặt ở cạnh trái (`Left Rail`), có nền kính mờ/surface đồng bộ với theme Trạm Kiến.
     - Nội dung màn hình chính chiếm toàn bộ phần diện tích còn lại bên phải.
2. **Chuẩn hóa Chuyển Động Chuyển Tab (Motion System):**
   - Triệt tiêu `SlideTransition` thô cứng trên `IndexedStack`.
   - Áp dụng mẫu chuyển động **`FadeThroughTransition`** (chuẩn Google Material Motion):
     - Màn hình cũ: Mờ dần (opacity $1.0 \rightarrow 0.0$) kết hợp scale nhẹ từ $1.0 \rightarrow 0.96$.
     - Màn hình mới: Hiện rõ (opacity $0.0 \rightarrow 1.0$) kết hợp scale từ $0.96 \rightarrow 1.0$.
     - Thời lượng chuyển động: $220\text{ms}$ với đường cong gia tốc `Curves.easeInOutCubicEmphasized`.
     - Giữ trạng thái cuộn và dữ liệu của các màn hình bằng `AutomaticKeepAliveClientMixin` hoặc `PageStorage`.

### 2.2. Chuẩn hóa Bố cục Responsive Từng Màn Hình

#### A. Màn hình Lịch học (`ScheduleScreen`)
- Bọc toàn bộ khu vực lịch tháng trong `ConstrainedBox(constraints: BoxConstraints(maxWidth: 480))`.
- Khi $W \ge 600\text{dp}$ (Tablet):
  - Chuyển sang bố cục **2 cột (Split View)**:
    * Cột trái ($40\%$): Lịch tháng mini (`_MonthGrid`) với tiêu đề và bộ chọn tháng.
    * Cột phải ($60\%$): Danh sách ca học trong ngày (`_buildSelectedDayEvents`) cuộn độc lập.
  - Triệt tiêu hoàn toàn lỗi ô lịch phình to $800\text{px}$ làm mất danh sách sự kiện.

#### B. Màn hình Đăng nhập (`LoginScreen`)
- Bọc khối `Column` đăng nhập trong `Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: 420), ...))`.
- Trên máy tính bảng, form đăng nhập nằm trang nhã ở chính giữa màn hình với nền bóng mờ sang trọng, không bị kéo dãn toàn màn hình.

#### C. Màn hình Dashboard, Điểm số, Tài chính, Profile
- Bọc phần nội dung `CustomScrollView` hoặc `ListView` trong `Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: 720), ...))`.
- Đảm bảo trên mọi thiết bị (từ điện thoại 320px đến tablet 12.9 inch), các card bento, bảng điểm, phiếu học phí luôn nằm trong "vùng vàng thị giác" (Optimal Reading Width $600 - 720\text{dp}$), gióng lề hình học chuẩn mực.

### 2.3. Tối Ưu Hóa Skeleton Loading (Synchronized Shimmer Motion)
1. **Thiết kế Shimmer Đồng Bộ Toàn App (`lib/widgets/shared_widgets.dart`):**
   - Khởi tạo widget `SynchronizedShimmer` (hoặc `AppShimmerScope`) cung cấp dải sáng `LinearGradient` chuyển động liên tục góc $135^\circ$ từ xám bạc `#E2E8F0` sang ánh sáng `#F1F5F9` rồi trở lại `#E2E8F0` (trên nền sáng) hoặc từ `#2D3238` sang `#3B424B` (trên nền tối).
   - Tối ưu hóa `SkeletonBox`:
     - Chuyển `SkeletonBox` thành `StatelessWidget` (hoặc widget nhẹ không tự khởi tạo `AnimationController` riêng lẻ).
     - Ăn theo nhịp quét dải sáng duy nhất của `AppShimmerScope` hoặc dùng shader mask duy nhất.
     - Triệt tiêu hoàn toàn 30 tickers chạy lệch pha, tiết kiệm 100% tài nguyên CPU/pin và tạo hiệu ứng sóng sáng lướt qua sang trọng, đồng bộ tuyệt đối như ứng dụng Apple/Google chuẩn mực.

---

## 3. TIÊU CHUẨN NGHIỆM THU (ACCEPTANCE CRITERIA - AC)

- [ ] **AC-01 (Adaptive Shell Navigation & Breakpoints):**
  - Khi chiều rộng màn hình $W < 600\text{dp}$: Hiển thị Floating BottomBar được căn giữa với `maxWidth: 500dp`.
  - Khi chiều rộng màn hình $W \ge 600\text{dp}$ (Tablet/Landscape): Tự động chuyển sang `NavigationRail` bên trái, không để thanh BottomBar bị kéo dãn bẹt ngang toàn màn hình.
- [ ] **AC-02 (Material FadeThrough Tab Transitions):**
  - Chuyển tab trên `MainShell` sử dụng cơ chế `FadeThroughTransition` (220ms, `Curves.easeInOutCubicEmphasized`), triệt tiêu việc giật trượt cả khối `IndexedStack`.
- [ ] **AC-03 (Schedule Tablet Responsive Split View):**
  - Màn hình Lịch học giới hạn kích thước ô tháng không vượt quá $55\text{dp}$.
  - Trên màn hình rộng ($W \ge 600\text{dp}$): Hiển thị bố cục 2 cột (Lịch tháng bên trái, Danh sách môn học bên phải), không bị che khuất sự kiện.
- [ ] **AC-04 (Login Screen Centered MaxWidth):**
  - Form đăng nhập trên `LoginScreen` được giới hạn `maxWidth: 420dp` và luôn căn giữa màn hình trên mọi kích cỡ thiết bị.
- [ ] **AC-05 (Optimal Content Width Across Screens):**
  - Các màn hình `DashboardScreen`, `GradesScreen`, `FinanceScreen`, `ProfileScreen` được bọc giới hạn độ rộng nội dung tối đa ($720\text{dp}$), căn giữa trên tablet, loại bỏ hiện tượng card kéo dài vô tận.
- [ ] **AC-06 (Synchronized Shimmer Motion System):**
  - Triệt tiêu việc mỗi `SkeletonBox` tự sinh 1 `AnimationController` riêng lẻ chạy lệch pha.
  - Toàn bộ các placeholder trên màn hình dao động trên cùng một nhịp sóng ánh sáng (Synchronized Shimmer Gradient Sweep $135^\circ$), tiết kiệm CPU và đồng bộ thị giác 100%.
- [ ] **AC-07 (Automated Verification & Zero Regression):**
  - Toàn bộ test suite `flutter test` đạt **100% PASS** (bao gồm các test case kiểm tra responsive breakpoints, adaptive navigation và shimmer mới), zero regressions.
