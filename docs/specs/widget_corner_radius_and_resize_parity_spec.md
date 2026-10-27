# Technical Specification: Khắc Phục Triệt Để Lỗi Bo Góc Khi Resize & Đồng Bộ Chuẩn Background Parity (Android & iOS)

- **Mã tài liệu:** SPEC-WIDGET-CORNER-RESIZE-01
- **Phân hệ:** Native Android AppWidget, iOS WidgetKit, Background Rendering Engine, Dynamic Resize Handling
- **Tác giả:** Master Orchestrator & Senior Business Analyst
- **Đối chiếu chuẩn:** Google Android 12+ Guidelines (`res/values-v31`), Apple iOS 17+ `containerBackground`, và 3 repository quy chuẩn (`homescreen_codelab`, `home_widget`, `flutter-home-widget-vignette`)
- **Trạng thái:** Approved by User / Ready for Implementation

---

## 1. MỤC TIÊU KỸ THUẬT & PHẠM VI XỬ LÝ

### 1.1. Vấn đề hiện tại (Root Cause Analysis)
1. **Méo góc elip do kéo dãn Bitmap tĩnh (`scaleType="fitXY"`):**
   - `ScheduleWidgetProvider.kt` đang khởi tạo bitmap nền với kích thước cố định (`widthPx = 450, heightPx = 450` cho 2x2, `800x400` cho 4x2, `800x800` cho 4x4) và vẽ bo góc 16dp trực tiếp lên canvas của bitmap đó.
   - Bitmap được gán vào `ImageView` với `scaleType="fitXY"`. Khi người dùng kéo resize widget trên Launcher (ví dụ từ 2x2 thành hình chữ nhật ngang tỉ lệ 1.66), `fitXY` kéo dãn trục X nhiều hơn trục Y, biến góc bo tròn chuẩn 16dp thành hình elip bẹp méo, đồng thời làm mất đồng đều độ dày nét viền (stroke width).
2. **Khuyết thiếu sự kiện `onAppWidgetOptionsChanged`:**
   - Khi người dùng điều chỉnh kích thước widget trên màn hình chính, hệ điều hành gửi `onAppWidgetOptionsChanged` chứa `minWidth` và `minHeight` thực tế. Hiện tại `ScheduleWidgetProvider` không lắng nghe sự kiện này, khiến widget không bao giờ được vẽ lại theo tỉ lệ khung hình mới.
3. **Chưa chuẩn hóa tài nguyên v31 (Android 12+ System Radius):**
   - Chưa tích hợp `@android:dimen/system_app_widget_background_radius` và `@android:dimen/system_app_widget_inner_radius` thông qua theme v31 như quy chuẩn của Google Codelab.
4. **Chuẩn hóa iOS 17+ Widget Background:**
   - Đồng bộ hóa `containerBackground(for: .widget)` và `contentMarginsDisabled()` trên `ScheduleWidgetKit.swift` theo quy chuẩn iOS 17+, loại bỏ việc bo góc thủ công cưỡng bức ngoài cùng để iOS tự xử lý squircle viền máy.

---

## 2. GIẢI PHÁP THỰC THI (DETAILED IMPLEMENTATION)

### 2.1. Phân hệ Android (`android/app/...`)

#### A. Khai báo Theme & Dimensions chuẩn Android 12+ (`res/values` & `res/values-v31`)
- Tạo / Bổ sung `android/app/src/main/res/values/themes.xml`:
  - Khai báo style `Theme.TramKien.AppWidgetContainerParent` kế thừa `@android:style/Theme.DeviceDefault`.
  - Khai báo `appWidgetRadius = 16dp` và `appWidgetInnerRadius = 8dp`.
- Tạo / Bổ sung `android/app/src/main/res/values-v31/themes.xml`:
  - Kế thừa `@android:style/Theme.DeviceDefault.DayNight`.
  - Trỏ `appWidgetRadius = @android:dimen/system_app_widget_background_radius`.
  - Trỏ `appWidgetInnerRadius = @android:dimen/system_app_widget_inner_radius`.
- Tạo / Bổ sung `android/app/src/main/res/values/attrs.xml` chứa định nghĩa 2 thuộc tính `appWidgetRadius` và `appWidgetInnerRadius`.

#### B. Cơ chế Dựng Nền Chống Méo Góc (Anti-Distortion Background Engine)
- Trong `ScheduleWidgetProvider.kt`:
  1. **Lắng nghe `onAppWidgetOptionsChanged`:**
     - Override phương thức `onAppWidgetOptionsChanged(...)`.
     - Lấy kích thước thực tế từ `newOptions`:
       ```kotlin
       val minWidthDp = newOptions.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
       val minHeightDp = newOptions.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)
       ```
     - Kích hoạt cập nhật lại `RemoteViews` với kích thước pixel chính xác tương ứng.
  2. **Tạo Bitmap theo đúng kích thước thực tế (Real-Time Aspect-Ratio Bitmap):**
     - Thay vì dùng kích thước cố định `450x450` hay `800x400`, `buildRemoteViews` phải chấp nhận hoặc tự truy vấn kích thước widget hiện tại từ `appWidgetManager.getAppWidgetOptions(appWidgetId)`:
       $$\text{widthPx} = (\text{minWidthDp} \times \text{density}).\text{toInt()}$$
       $$\text{heightPx} = (\text{minHeightDp} \times \text{density}).\text{toInt()}$$
     - Khi vẽ bo góc trên canvas thật với đúng tỉ lệ khung hình (Aspect Ratio) thực tế của widget trên màn hình, bán kính `radiusDp * density` luôn là hình tròn $90^\circ$ hoàn hảo, triệt tiêu 100% hiện tượng elip méo.
  3. **Đảm bảo fallback kích thước an toàn:** Nếu options chưa có hoặc bằng 0, fallback về kích cỡ chuẩn theo layout.

### 2.2. Phân hệ iOS (`ios/Runner/ScheduleWidgetKit.swift`)
- Cập nhật modifier nền chuẩn cho iOS 17+:
  ```swift
  extension View {
      func widgetBackgroundAdaptive(isGlass: Bool, bgColorHex: String, bgOpacity: Double) -> some View {
          if #available(iOSApplicationExtension 17.0, iOS 17.0, *) {
              return containerBackground(for: .widget) {
                  if isGlass {
                      Rectangle().fill(.ultraThinMaterial)
                  } else {
                      Color(hex: bgColorHex)?.opacity(bgOpacity) ?? Color.black.opacity(bgOpacity)
                  }
              }
          } else {
              return background(
                  Group {
                      if isGlass {
                          Rectangle().fill(.ultraThinMaterial)
                      } else {
                          Color(hex: bgColorHex)?.opacity(bgOpacity) ?? Color.black.opacity(bgOpacity)
                      }
                  }
              )
          }
      }
  }
  ```
- Thêm `.contentMarginsDisabled()` cho cấu hình widget trên iOS 15+ / 17+ để kiểm soát padding chủ động mà không bị hệ điều hành đè thêm viền lồng nhau.

---

## 3. TIÊU CHUẨN NGHIỆM THU (ACCEPTANCE CRITERIA - AC)

- [ ] **AC-01 (Android v31 System Radius Resources):**
  - Tồn tại file `res/values/attrs.xml` định nghĩa `appWidgetRadius` và `appWidgetInnerRadius`.
  - Tồn tại file `res/values/themes.xml` (radius fallback 16dp) và `res/values-v31/themes.xml` liên kết `@android:dimen/system_app_widget_background_radius`.
- [ ] **AC-02 (Android Dynamic Size Query & Density Conversion):**
  - `ScheduleWidgetProvider.kt` có hàm/cơ chế tính toán `targetWidthPx` và `targetHeightPx` dựa trên `minWidth` và `minHeight` từ `AppWidgetOptions` và `density` của màn hình, thay vì luôn ép cứng `450x450` hay `800x400`.
- [ ] **AC-03 (Android Resize Event Listener):**
  - `ScheduleWidgetProvider.kt` override đầy đủ `onAppWidgetOptionsChanged`, tự động trigger cập nhật lại `RemoteViews` khi người dùng kéo thanh chốt resize trên launcher.
- [ ] **AC-04 (Anti-Distortion Geometry Verification):**
  - Khi widget 2x2 được kéo dài thành hình chữ nhật ngang (ví dụ tỉ lệ 1.66 như ảnh người dùng), nền bitmap được vẽ với đúng tỉ lệ kích thước thật, đảm bảo bán kính bo góc 4 đỉnh luôn tròn trịa, không bị biến dạng thành hình elip.
- [ ] **AC-05 (iOS 17+ containerBackground Support):**
  - `ios/Runner/ScheduleWidgetKit.swift` hỗ trợ API `containerBackground(for: .widget)` khi chạy trên iOS 17+ và fallback `background()` trên iOS 14-16.
- [ ] **AC-06 (iOS Content Margins Disabled):**
  - Cấu hình widget trên `ScheduleWidgetKit.swift` hỗ trợ `.contentMarginsDisabled()` trên iOS 15+/17+ để loại bỏ khoảng đệm lồng nhau.
- [ ] **AC-07 (Automated Tests & Zero Regression):**
  - Toàn bộ test suite `flutter test` đạt **100% PASS**, không có bất kỳ regression nào trên toàn bộ 22 test suites hiện hành.
