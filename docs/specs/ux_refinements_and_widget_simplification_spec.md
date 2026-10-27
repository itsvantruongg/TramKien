# Technical Specification: Tối Ưu Hóa Shimmer Motion, Bảo Mật Phiên Widget, Khắc Phục Splash Tối & Đơn Giản Hóa Nền Widget Chuẩn Quốc Tế

- **Mã tài liệu:** SPEC-UX-REFINEMENTS-WIDGET-02
- **Phân hệ:** Motion System (Shimmer Sweep), Launcher Integration (Samsung/Android Pinning, AppWidget Configuration), Session Security & Privacy, Native Splash Screen, Widget Background Minimalism
- **Tác giả:** Master Orchestrator & Senior Business Analyst
- **Đối chiếu chuẩn:** Google Flutter Cookbook (Shimmer Loading), Google Android 12+ Guidelines, Apple HIG (WidgetKit Intents), World-class Calendar Widgets (Google Calendar, Apple Calendar, Notion Calendar, TickTick)
- **Trạng thái:** Drafted by Senior BA / Ready for User Review (Chưa giao DEV)

---

## 1. TỔNG QUAN PHÂN TÍCH & NGUYÊN NHÂN GỐC RỄ (ROOT CAUSE ANALYSIS)

### 1.1. Lỗi Giật Khực Của Skeleton Shimmer (Loop Reset Snap Glitch)
- **Vấn đề:** Trong `lib/widgets/shared_widgets.dart`, `offset` tính theo `(t * 2.0) - 1.0` với $t \in [0.0, 1.0]$.
  - Tại $t = 0.0$: Dải highlight (stop 0.5) nằm ở tọa độ $(-1.0, -1.0)$, mép trên-trái của thẻ skeleton đã có sẵn một vệt sáng.
  - Tại $t = 1.0$: Dải highlight nằm ở $(+1.0, +1.0)$, mép dưới-phải vẫn còn dính vệt sáng chưa thoát hết.
  - Khi animation lặp lại (`.repeat()`), $t$ nhảy tức thì từ $1.0 \rightarrow 0.0$ trong 1 frame duy nhất ($16\text{ms}$), khiến vệt sáng ở góc dưới-phải đột ngột biến mất và nhảy dựng ngược về góc trên-trái, gây hiện tượng khựng/giật gián đoạn thị giác.
- **Quy chuẩn Google Codelab / Shimmer:** Dải quét phải bắt đầu hoàn toàn ngoài biên âm ($<-1.5$) và kết thúc hoàn toàn ngoài biên dương ($>+1.5$), kết hợp nhịp nghỉ tĩnh tĩnh lặng giữa các chu kỳ.

### 1.2. Hiện Tượng Văng Vào App Drawer Trên Samsung Khi Bấm "Áp Dụng"
- **Vấn đề:** Trong `WidgetPinSuccessReceiver.kt`, sau khi pin widget thành công code đang cưỡng bức gọi `Intent.ACTION_MAIN + Intent.CATEGORY_HOME + FLAG_ACTIVITY_NEW_TASK`.
  - Trên các thiết bị Samsung One UI (hoặc Xiaomi, Pixel) sử dụng chế độ "Màn hình chờ và màn hình ứng dụng" (Home & Apps screens): nếu người dùng mở app từ App Drawer, lệnh `CATEGORY_HOME` sẽ khôi phục Launcher ở trạng thái gần nhất $\rightarrow$ văng vào màn hình chứa toàn bộ ứng dụng (App Drawer) thay vì Màn hình chính chứa Widget.
  - Hơn nữa, Android OS không cho phép ứng dụng bên thứ ba can thiệp vào trang lật cụ thể của Launcher.
- **Quy chuẩn:** Bỏ việc tự ý bắn `CATEGORY_HOME` bằng code. Sau khi người dùng xác nhận pin widget, hiển thị thông báo SnackBar hoàn tất trang nhã và để người dùng thoát tự nhiên; Launcher sẽ tự động định vị tới trang widget mới đặt.

### 1.3. Lỗ Hổng Bảo Mật & Rò Rỉ Dữ Liệu Khi Không Tích "Duy Trì Đăng Nhập"
- **Vấn đề:** Người dùng không tích "Ghi nhớ đăng nhập" (`remember = false`). Khi kill app và khởi động lại, app bắt buộc nhập lại tài khoản/mật khẩu, nhưng dữ liệu `widget_schedule_data` trong `SharedPreferences` không bị xóa. Widget ngoài màn hình chính vẫn hiển thị toàn bộ lịch học, phòng học, mã lớp của sinh viên.
- **Quy chuẩn Bảo mật (Session Privacy):** Khi phiên làm việc không ghi nhớ kết thúc (hoặc khi `quickAuthCheck()` phát hiện `remember == false`), hệ thống phải xóa sạch dữ liệu widget và đưa widget về trạng thái an toàn: `"Trạm Kiến • Vui lòng đăng nhập"`.

### 1.4. Màn Hình Splash Tối Lem Nhem Khi Bật Dark Mode
- **Vấn đề:** Logo `assets/logo.png` là ảnh PNG trong suốt có chữ đen than và nét vẽ xanh đậm. Khi máy ở chế độ Dark Mode, hệ thống tự động gán nền Splash màu đen `#000000`, khiến các chi tiết tối của logo bị chìm vào nền đen, lem nhem và răng cưa.
- **Quy chuẩn:**
  - Khóa cứng nền Native Splash luôn là màu Trắng `#FFFFFF` (hoặc bọc logo trong huy hiệu tròn trắng `icon_background_color: "#FFFFFF"` trên Android 12+) để nhận diện thương hiệu luôn thanh lịch, sau đó mới chuyển sang Dark Mode khi vào app.

### 1.5. Cấu Hình Thông Số Widget Trực Tiếp Từ Màn Hình Chính
- **Vấn đề:** Hiện tại người dùng chỉ có thể tùy chỉnh widget từ bên trong app (Widget Studio).
- **Quy chuẩn Thế giới:** Hỗ trợ `AppWidget Configuration Activity` và `widgetFeatures="reconfigurable|configuration_optional"` (Android 12+) cùng `WidgetKit App Intent` (iOS 16+) để khi người dùng nhấn giữ widget ngoài màn hình chính, hệ thống hiển thị nút chỉnh sửa (hình bút chì) cho phép cấu hình trực tiếp từ Launcher.

### 1.6. Hiện Tượng 2 Viền Lồng Nhau Khi Chọn Nền Trong Suốt
- **Vấn đề:** Trong `ScheduleWidgetProvider.kt`, khi `bgStyle == "transparent"`, code gán `setBackgroundResource(R.drawable.widget_card_rounded_transparent)` cho CẢ `R.id.widget_root` VÀ `android.R.id.background`. Do `widget_root` có `padding="10dp"`, nó tạo ra 1 đường viền ngoài sát mép launcher, rồi bên trong 10dp lại có thêm 1 đường viền nữa, tạo cảm giác 2 viền lồng nhau rất xấu.
- **Quy chuẩn:** `widget_root` luôn là `@android:color/transparent` tuyệt đối (không viền). Chỉ có duy nhất `android.R.id.background` mang viền hairline 0.5dp.

### 1.7. Lỗi Co Ép Font Size Ở Ô Chủ Nhật Do `FittedBox` Trong Studio
- **Vấn đề:** Trong `lib/screens/widget_studio_screen.dart`, nội dung ô ngày bị bọc trong `FittedBox(fit: BoxFit.scaleDown)`. Khi ô Chủ Nhật có thêm nhãn `[HÔM NAY]` và môn học có chuỗi giờ dài (`P.M-M5.03`), `FittedBox` tự động co nhỏ font size của cả ô CN lại, khiến ô CN trông bé tí và co cụm so với T2..T7. Ngoài launcher native không có `FittedBox` nên vẫn giữ cỡ chữ chuẩn và cắt dấu `...`.
- **Quy chuẩn:** Bỏ hoàn toàn `FittedBox` trong Studio preview, dùng text overflow ellipsis chuẩn để đạt đồng bộ 1:1 tuyệt đối với Native RemoteViews.

### 1.8. Bảng Chọn Màu Rườm Rà, Lỗi Tàng Hình Chữ "HÔM NAY" & Thừa "Màu Viền"
- **Vấn đề:**
  - Hàng chọn màu hiển thị lộn xộn (5 ô, 7 ô). Cần quy chuẩn đồng nhất thành đúng 8 ô (7 màu chuẩn + 1 ô Custom).
  - Mục "Màu Viền" là thừa thãi và gây xấu (người dùng chọn viền xanh, đỏ lòe loẹt như khung debug). Viền widget phải luôn là hairline mờ 0.5dp cố định.
  - Chữ "HÔM NAY" đang bị gán cứng màu trắng `#FFFFFF`. Khi người dùng chọn màu điểm nhấn (accent) là màu sáng (vàng, cam, cyan, trắng), chữ trắng trên nền sáng biến mất hoàn toàn.
- **Quy chuẩn:** Loại bỏ mục Chọn Màu Viền. Tự động tính toán độ tương phản (Luminance) của màu điểm nhấn: nếu là màu sáng $\rightarrow$ chữ "HÔM NAY" chuyển sang đen than `#0F172A`, nếu là màu tối $\rightarrow$ chữ "HÔM NAY" là trắng `#FFFFFF`.

---

## 2. KẾ HOẠCH & DANH MỤC CÔNG VIỆC CHI TIẾT (WORK ITEMS)

### Work Item 1: Triệt Tiêu Lỗi Giật Khực Của Skeleton Shimmer (AC-01)
- **Tệp can thiệp:** `lib/widgets/shared_widgets.dart`
- **Nội dung:**
  1. Trong `AppShimmerScopeState`, sử dụng đường cong có nhịp nghỉ:
     ```dart
     _animation = CurvedAnimation(
       parent: _controller,
       curve: const Interval(0.0, 0.75, curve: Curves.easeInOutCubic),
     );
     ```
  2. Trong `SkeletonBox`, mở rộng biên quét từ $[-2.0, +2.0]$:
     ```dart
     final t = shimmer.animation.value;
     final offset = (t * 4.0) - 2.0;
     // begin: Alignment(-1.5 + offset, -1.5 + offset)
     // end: Alignment(1.5 + offset, 1.5 + offset)
     ```
  3. Kết quả: Ở $t = 0.0$ và trong khoảng nghỉ $t \in [0.75, 1.0]$, toàn bộ thẻ skeleton là $100\%$ màu nền tĩnh (`baseColor`), triệt tiêu hoàn toàn hiện tượng khựng giật khi lặp lại chu kỳ.

---

### Work Item 2: Loại Bỏ Lệnh Ép CATEGORY_HOME & Tối Ưu UX Ghim Widget (AC-02)
- **Tệp can thiệp:**
  - `android/app/src/main/kotlin/com/tramkien/hau/WidgetPinSuccessReceiver.kt`
  - `android/app/src/main/kotlin/com/tramkien/hau/MainActivity.kt`
  - `lib/screens/widget_studio_screen.dart`
- **Nội dung:**
  1. Trong `WidgetPinSuccessReceiver.kt`:
     - Xóa bỏ hoàn toàn lệnh ép `context.startActivity(homeIntent)` gọi `Intent.CATEGORY_HOME`.
     - Receiver chỉ làm đúng nhiệm vụ gửi broadcast cập nhật widget provider.
  2. Bổ sung cơ chế thu nhỏ an toàn `moveTaskToBack(true)` trong `MainActivity.kt`:
     - Khi người dùng chủ động muốn ra màn hình chính, app gọi `activity.moveTaskToBack(true)` để đưa app xuống nền (tương tự thao tác vuốt thanh điều hướng Home).
     - Launcher Samsung/Xiaomi sẽ trượt tự nhiên ra đúng trang Màn hình chính vừa đặt widget mới, **triệt tiêu 100% lỗi văng vào App Drawer**.
  3. Trong `WidgetStudioScreen`:
     - Khi bấm "Áp dụng", hệ thống lưu cấu hình và kích hoạt pin widget.
     - Sau khi người dùng xác nhận, hiển thị `SnackBar` nổi trang nhã:
       `"✓ Đã ghim Lịch học ra Màn hình chính thành công!"` kèm nút hành động `[ Xem ngay ]` (gọi `moveTaskToBack(true)` nếu người dùng bấm, hoặc tự động ẩn sau 3 giây để người dùng ở lại tùy biến tiếp).

---

### Work Item 3: Khắc Phục Lỗ Hổng Rò Rỉ Dữ Liệu Phiên Tạm (AC-03)
- **Tệp can thiệp:**
  - `lib/providers/app_provider.dart`
  - `lib/screens/login_screen.dart`
  - `android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt`
- **Nội dung:**
  1. Khi người dùng không tích "Ghi nhớ đăng nhập" (`remember == false`):
     - Tại `quickAuthCheck()` (khởi động app): Nếu phát hiện phiên trước `remember == false` và người dùng không đăng nhập $\rightarrow$ Lập tức gọi `WidgetDataSyncService.clearAllWidgetData()`.
     - Lắng nghe `AppLifecycleListener` khi app bị kill / detach $\rightarrow$ Gọi xóa dữ liệu widget trong SharedPreferences.
  2. Trong `ScheduleWidgetProvider.kt`: Khi dữ liệu `widget_schedule_data` bị xóa, hiển thị thẻ thông báo khóa an toàn:  
     `"Trạm Kiến • Vui lòng đăng nhập"`.

---

### Work Item 4: Khóa Nền Trắng Cho Splash Native / Huy Hiệu Tròn (AC-04)
- **Tệp can thiệp:**
  - `android/app/src/main/res/values-night-v31/styles.xml`
  - `android/app/src/main/res/values-night/styles.xml`
  - `pubspec.yaml`
- **Nội dung:**
  1. Trong `values-night-v31/styles.xml`:
     - Khóa cứng `android:windowSplashScreenBackground = #FFFFFF` và `android:windowSplashScreenIconBackgroundColor = #FFFFFF`.
  2. Trong `values-night/styles.xml`:
     - Thiết lập nền launch background luôn đồng bộ màu trắng sáng `#FFFFFF`.
  3. Logo trường HAU luôn hiển thị nổi bật, trang nhã, đúng màu nhận diện thương hiệu, không bao giờ bị đen xì lem nhem khi máy bật Dark Mode.

---

### Work Item 5: Kiến Trúc Tùy Chỉnh Trực Tiếp Từ Màn Hình Chính (AC-05)
- **Phân tích khả năng tương thích nền tảng:**
  * **Trên iPhone (iOS 14+ đến iOS 17/18+):**
    - Hỗ trợ **100% nguyên bản** thông qua cơ chế WidgetKit Intent.
    - Người dùng chỉ cần chạm và giữ widget ngoài màn hình chính $\rightarrow$ chọn **"Sửa tiện ích" (Edit Widget)**.
    - Thẻ widget sẽ **tự động lật mặt sau (3D Flip Animation)** hiển thị các mục chọn native của Apple (chọn Lịch hôm nay/Lịch tuần, chọn Nền tối/Nền sáng/Trong suốt).
    - Hỗ trợ từ iOS 14 qua SiriKit Intent (`.intentdefinition`) và iOS 16+ qua Swift App Intents (`WidgetConfigurationIntent`). Mỗi widget trên màn hình iPhone có thể mang cấu hình hoàn toàn độc lập!
  * **Trên Android đời cũ (Android 5.0 đến Android 11, API 21 - 30):**
    - Hỗ trợ tùy chỉnh **khi kéo thả widget ra màn hình**: Khai báo `android:configure` trong `res/xml/widget_info.xml`.
    - Khi người dùng kéo widget từ menu ra màn hình, Launcher Android đời cũ tự động bật `WidgetConfigurationActivity` để sinh viên chọn màu và chế độ hiển thị trước khi widget xuất hiện.
  * **Trên Android đời cao (Android 12+, API 31+):**
    - Google bổ sung thuộc tính **`widgetFeatures="reconfigurable|configuration_optional"`**.
    - Ngoài việc cấu hình khi kéo thả lúc đầu, người dùng chạm giữ widget trên màn hình chính của Android 12+ sẽ xuất hiện **biểu tượng hình cây bút chì / bánh răng (Chỉnh sửa tiện ích)** ngay trên Launcher. Bấm vào đó sẽ mở lại màn hình cấu hình nhanh để đổi màu mà không cần vào app!
- **Tệp can thiệp:**
  - `android/app/src/main/AndroidManifest.xml`
  - `android/app/src/main/res/xml/widget_schedule_*_info.xml`
  - `ios/Runner/ScheduleWidgetKit.swift`
- **Nội dung triển khai:**
  1. Khai báo thuộc tính `android:configure` và `widgetFeatures="reconfigurable|configuration_optional"` trên các provider XML của Android.
  2. Thiết kế entrypoint cấu hình nhanh gọn nhẹ: Cho phép chọn nhanh [ 1 Ngày | 3 Ngày | Tuần ] và [ Nền Tối | Nền Sáng | Trong Suốt ].
  3. Khai báo cấu hình `AppIntentConfiguration` trên iOS WidgetKit hỗ trợ tính năng "Sửa tiện ích" (Edit Widget) nguyên bản của Apple.

---

### Work Item 6: Đơn Giản Hóa Nền Widget & Triệt Tiêu 2 Viền Lồng Nhau (AC-06)
- **Tệp can thiệp:**
  - `lib/models/widget_models.dart`
  - `lib/screens/widget_studio_screen.dart`
  - `android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt`
- **Nội dung:**
  1. Loại bỏ hoàn toàn 2 chế độ mờ loang lổ: `system_glass` và `frosted_glass`.
  2. Quy chuẩn bộ chọn Kiểu Nền chỉ còn đúng 2 lựa chọn:
     - **[ NỀN MÀU ĐẶC ] (Solid Card - Mặc định & Khuyên dùng):** Tùy chọn Nền Tối (`#1C1C1E`) hoặc Nền Sáng (`#FFFFFF`), chữ tương phản cao tuyệt đối ($\ge 4.5:1$), viền hairline $0.5\text{dp}$.
     - **[ TRONG SUỐT 100% ] (Ghost Mode):** Nền hoàn toàn trong suốt (`#00000000`), chữ và vạch accent nổi trực tiếp trên hình nền máy.
  3. Ẩn hoàn toàn thanh trượt Opacity thủ công.
  4. Trong `ScheduleWidgetProvider.kt`:
     - Khi `bgStyle == "transparent"`: `R.id.widget_root` CHỈ mang `@android:color/transparent` (không viền, không drawable). Chỉ có `android.R.id.background` mang drawable viền mờ $0.5\text{dp}$. **Triệt tiêu 100% hiện tượng 2 viền lồng nhau!**

---

### Work Item 7: Quy Chuẩn 8 Ô Màu, Xóa Bỏ Màu Viền & Tự Động Độ Tương Phản Badge Hôm Nay (AC-07)
- **Tệp can thiệp:**
  - `lib/screens/widget_studio_screen.dart`
  - `android/app/src/main/kotlin/com/tramkien/hau/ScheduleWidgetProvider.kt`
  - `android/app/src/main/res/layout/widget_schedule_weekly.xml`
- **Nội dung:**
  1. **Xóa bỏ hoàn toàn mục "Màu Viền" khỏi WidgetStudioScreen.** Viền widget luôn dùng chuẩn hairline mờ $0.5\text{dp}$ thanh lịch.
  2. **Quy chuẩn các hàng chọn màu (Chữ chính, Chữ phụ, Điểm nhấn) thành đúng 8 ô tròn:**
     - 7 ô preset màu chuẩn:
       1. Đen (`#1C1C1E`)
       2. Trắng (`#FFFFFF`)
       3. Xám ghi (`#64748B`)
       4. Xanh dương (`#1D64F2`)
       5. Xanh lá (`#10B981`)
       6. Cam vàng (`#F59E0B`)
       7. Đỏ (`#EF4444`)
     - Ô thứ 8 cuối cùng: Nút Custom (icon cây bút chì) để chọn màu tự do hoặc nhập mã Hex.
  3. **Tính toán tương phản tự động cho badge "HÔM NAY":**
     - Trong Flutter Studio: Tính luminance của `accentColor`. Nếu `accentColor.computeLuminance() > 0.5` $\rightarrow$ chữ "HÔM NAY" đổi sang màu đen than `#0F172A`; nếu tối $\rightarrow$ màu trắng `#FFFFFF`.
     - Trong `ScheduleWidgetProvider.kt`: Tính luminance của `accentColor`. Nếu sáng $\rightarrow$ `views.setTextColor(badgeIds[i], Color.parseColor("#0F172A"))`; nếu tối $\rightarrow$ màu trắng `#FFFFFF`.
     - Không bao giờ bị tàng hình chữ khi chọn màu điểm nhấn sáng!

---

### Work Item 8: Triệt Tiêu `FittedBox` Trong Studio Preview & Đạt Visual Parity 1:1 (AC-08)
- **Tệp can thiệp:**
  - `lib/screens/widget_studio_screen.dart`
- **Nội dung:**
  1. Trong `_buildGridDayCell`: Gỡ bỏ hoàn toàn `FittedBox(fit: BoxFit.scaleDown, child: Column(...))` bọc quanh ô ngày.
  2. Bố cục ô ngày sử dụng `Column` tự nhiên với `Text(..., maxLines: 1, overflow: TextOverflow.ellipsis)` giống hệt cơ chế của Android Native XML.
  3. Đảm bảo tất cả 8 ô trong lưới tuần (từ T2 đến CN và Tổng kết tuần) có font size $10.5\text{sp}$ / $9\text{sp}$ đồng đều $100\%$, không bao giờ có tình trạng ô CN bị bóp nhỏ kích thước hay co rúm font chữ.

---

## 3. CHECKLIST TIÊU CHUẨN NGHIỆM THU (ACCEPTANCE CRITERIA)

- [ ] **AC-01 (Smooth Shimmer Sweep & Zero Snap Glitch):**
  - Hiệu ứng quét sáng `SkeletonBox` không còn bị giật khực ở điểm đầu/cuối. Dải quét trôi hoàn toàn ra ngoài biên kết hợp nhịp nghỉ tĩnh $375\text{ms}$.
- [ ] **AC-02 (Separated Save vs Pin Flow & No App Drawer Drop):**
  - Nút "ÁP DỤNG" chỉ lưu và cập nhật widget hiện có, hiện SnackBar cập nhật nhẹ nhàng.
  - Nút riêng "Thêm vào Màn hình chính" gọi `requestPinWidget()`, khi ghim thành công có nút action `[ Xem ngay ]` gọi `minimizeApp()` thu nhỏ êm ái, không văng vào App Drawer Samsung.
- [ ] **AC-03 (Transient Session Privacy Protection):**
  - Khi không tích "Ghi nhớ đăng nhập", tắt app và mở lại $\rightarrow$ Widget ngoài màn hình chính tự động chuyển về trạng thái an toàn: `"Trạm Kiến • Vui lòng đăng nhập"`, không rò rỉ lịch học.
- [ ] **AC-04 (Crisp Brand Splash on Dark Mode):**
  - Màn hình Splash khi khởi động máy ở Dark Mode luôn giữ nền trắng sáng với logo HAU sắc nét, không bị chìm/lem nhem.
- [ ] **AC-05 (Widget Configuration Architecture):**
  - Khai báo cấu hình `android:widgetFeatures="reconfigurable|configuration_optional"` trên toàn bộ provider XML.
- [ ] **AC-06 (Single Border on Transparent & Binary Background):**
  - Nền trong suốt chỉ có 1 viền duy nhất tại `android.R.id.background`, `widget_root` hoàn toàn không viền. Widget Studio chỉ còn 2 chế độ: [ Nền Màu Đặc ] và [ Trong Suốt 100% ].
- [ ] **AC-07 (8-Slot Color Palette, No Border Color & Dynamic Badge Contrast):**
  - Hàng chọn màu gồm đúng 8 ô (7 màu chuẩn + 1 Custom). Xóa bỏ mục Chọn Màu Viền. Chữ "HÔM NAY" tự đổi màu đen khi màu điểm nhấn sáng, không bao giờ bị tàng hình.
- [ ] **AC-08 (Zero FittedBox Shrinking in Studio Grid):**
  - Gỡ bỏ `FittedBox` trong ô ngày của Studio. 8 ô lưới tuần đồng đều $100\%$ về font size và kích thước, ô Chủ Nhật không bị ép bé lại.
- [ ] **AC-09 (Automated Tests & Zero Regression):**
  - Toàn bộ test suite `flutter test` đạt **100% PASS**, zero regressions trên toàn bộ hệ thống test.
