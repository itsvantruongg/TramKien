# BẢNG ĐĂNG KÝ ID HỆ THỐNG WIDGET (ID REGISTRY)
**Dự án:** Trạm Kiến (`com.tramkien.hau`)  
**Tài liệu quy chuẩn:** `SPEC-DYNAMIC-SQLITE-WIDGET-SYSTEM-01`  
**Ngày cập nhật:** 31/10/2026

---

## 1. Thông số Định danh Nền tảng (Platform Identifiers)

| Thuộc tính | Giá trị thật (Concrete Value) |
|---|---|
| **Android Application ID** | `com.tramkien.hau` |
| **Android Widget Package** | `com.tramkien.hau` |
| **iOS App Bundle ID** | `com.tramkien.hau` |
| **iOS Widget Extension Target** | `TramKienWidgets` |
| **iOS Widget Extension Bundle ID** | `com.tramkien.hau.TramKienWidgets` |
| **iOS WidgetBundle Struct** | `TramKienWidgetBundle` |
| **Shared App Group ID** | `group.vn.edu.hau.tramkien` |
| **Snapshot File Name** | `widget_schedule_snapshot.json` |
| **MethodChannel Cầu nối** | `com.tramkien.hau/widget` |

---

## 2. Bảng Đăng ký Widget Android

### 2.1 Thành phần Provider & Layout XML
| Widget | Provider Class | XML Metadata Provider | Layout File Chính | Layout File Phụ (Item) | Tên Chuỗi Nhãn (`strings.xml`) |
|---|---|---|---|---|---|
| **Hôm nay (2x2)** | `TodayWidgetProvider` | `res/xml/widget_today_info.xml` | `res/layout/widget_today.xml` | N/A | `@string/widget_today_label` |
| **Tháng + Hôm nay (4x2)** | `MonthWidgetProvider` | `res/xml/widget_month_info.xml` | `res/layout/widget_month.xml` | N/A | `@string/widget_month_label` |
| **3 Ngày (4x2)** | `ThreeDayWidgetProvider` | `res/xml/widget_three_day_info.xml` | `res/layout/widget_three_day.xml` | N/A | `@string/widget_three_day_label` |
| **Tuần (4x4)** | `WeekWidgetProvider` | `res/xml/widget_week_info.xml` | `res/layout/widget_week.xml` | `widget_week_row.xml`, `widget_week_header.xml` | `@string/widget_week_label` |
| **Dịch vụ Danh sách Tuần** | `WeekWidgetService` (`RemoteViewsService`) | N/A | N/A | N/A | N/A |
| **Receiver Thời gian / Boot** | `WidgetTimeReceiver` | N/A | N/A | N/A | N/A |

### 2.2 Intent Actions chuẩn
Tiền tố: `com.tramkien.hau.widget.action.`
- `com.tramkien.hau.widget.action.REFRESH`: Làm mới toàn bộ widget khi có dữ liệu snapshot mới hoặc khi người dùng chạm nút refresh.
- `com.tramkien.hau.widget.action.PREV`: Lùi tháng (MonthWidget) hoặc lùi tuần (WeekWidget).
- `com.tramkien.hau.widget.action.NEXT`: Tiến tháng (MonthWidget) hoặc tiến tuần (WeekWidget).
- `com.tramkien.hau.widget.action.OPEN_DAY`: Chạm ngày trong lưới tháng / cột ngày mở deep link ngày đó trong app.
- `com.tramkien.hau.widget.action.OPEN_SESSION`: Chạm môn học / ca thi mở deep link chi tiết phiên trong app.

### 2.3 Quy chuẩn View ID (XML View IDs)
- **Hôm nay (2x2)**: `today_root`, `today_status_badge`, `today_subject_name`, `today_time_room`, `today_progress_bar`, `today_countdown_text`, `today_empty_container`, `today_empty_text`
- **Tháng + Hôm nay (4x2)**: `month_root`, `month_header_title`, `month_btn_prev`, `month_btn_next`, `month_grid_container`, `month_cell_0..41`, `month_today_title`, `month_today_count`, `month_card_1`, `month_card_2`, `month_more_badge`, `month_empty_container`
- **3 Ngày (4x2)**: `three_root`, `three_col_0`, `three_col_1`, `three_col_2`, `three_header_0..2`, `three_card_0_1`, `three_card_0_2`, `three_card_1_1`, `three_card_1_2`, `three_card_2_1`, `three_card_2_2`, `three_badge_0..2`
- **Tuần (4x4)**: `week_root`, `week_title`, `week_btn_prev`, `week_btn_next`, `week_strip_container`, `week_day_pill_0..6`, `week_list_view`, `week_empty_container`, `week_empty_text`

### 2.4 Request Codes (PendingIntent Request Code Mapping)
| Component | Action | Request Code | Flags |
|---|---|---|---|
| Today 2x2 | REFRESH | `1001` | `FLAG_UPDATE_CURRENT or FLAG_IMMUTABLE` |
| Today 2x2 | OPEN_SESSION | `1002` | `FLAG_UPDATE_CURRENT or FLAG_IMMUTABLE` |
| Month 4x2 | REFRESH | `2001` | `FLAG_UPDATE_CURRENT or FLAG_IMMUTABLE` |
| Month 4x2 | PREV | `2002` | `FLAG_UPDATE_CURRENT or FLAG_IMMUTABLE` |
| Month 4x2 | NEXT | `2003` | `FLAG_UPDATE_CURRENT or FLAG_IMMUTABLE` |
| Month 4x2 | OPEN_DAY | `2004` | `FLAG_UPDATE_CURRENT or FLAG_IMMUTABLE` |
| Month 4x2 | OPEN_SESSION | `2005` | `FLAG_UPDATE_CURRENT or FLAG_IMMUTABLE` |
| ThreeDay 4x2 | REFRESH | `3001` | `FLAG_UPDATE_CURRENT or FLAG_IMMUTABLE` |
| ThreeDay 4x2 | OPEN_DAY | `3002` | `FLAG_UPDATE_CURRENT or FLAG_IMMUTABLE` |
| ThreeDay 4x2 | OPEN_SESSION | `3003` | `FLAG_UPDATE_CURRENT or FLAG_IMMUTABLE` |
| Week 4x4 | REFRESH | `4001` | `FLAG_UPDATE_CURRENT or FLAG_IMMUTABLE` |
| Week 4x4 | PREV | `4002` | `FLAG_UPDATE_CURRENT or FLAG_IMMUTABLE` |
| Week 4x4 | NEXT | `4003` | `FLAG_UPDATE_CURRENT or FLAG_IMMUTABLE` |
| Week 4x4 | OPEN_DAY | `4004` | `FLAG_UPDATE_CURRENT or FLAG_IMMUTABLE` |
| Week 4x4 | OPEN_SESSION | `4005` | `FLAG_UPDATE_CURRENT or FLAG_IMMUTABLE` |

---

## 3. Bảng Đăng ký Widget iOS (WidgetKit)

| Widget Kind String | Swift Struct / View | Supported Families | Ghi chú |
|---|---|---|---|
| `TramKienTodayWidget` | `TodayWidget` / `TodayWidgetEntryView` | `.systemSmall` | Widget Hôm nay (2x2) |
| `TramKienMonthWidget` | `MonthWidget` / `MonthWidgetEntryView` | `.systemMedium` | Widget Tháng + Hôm nay (4x2) |
| `TramKienThreeDayWidget` | `ThreeDayWidget` / `ThreeDayWidgetEntryView` | `.systemMedium` | Widget 3 Ngày (4x2) |
| `TramKienWeekWidget` | `WeekWidget` / `WeekWidgetEntryView` | `.systemLarge` | Widget Tuần (4x4) |
| `TramKienLockWidget` | `LockWidget` / `LockWidgetEntryView` | `.accessoryRectangular`, `.accessoryCircular`, `.accessoryInline` | Lock screen đơn sắc (iOS 16+) |

### App Intents (iOS 17+)
- `ShiftMonthIntent`: Tham số `offset: Int`, key UserDefaults AppGroup `monthOffset_<widgetId>`.
- `ShiftWeekIntent`: Tham số `offset: Int`, key UserDefaults AppGroup `weekOffset_<widgetId>`.

---

## 4. Deep Link URL Schemes

Cú pháp:
- Mở xem lịch ngày: `tramkien://schedule?date=yyyy-MM-dd`
- Mở xem chi tiết phiên học/thi: `tramkien://schedule/session?id=<sessionId>&kind=class|exam`
