# Technical Specification: Đồng Bộ Bền Bỉ, Phân Tích Lịch Học Linh Hoạt & Toàn Vẹn Dữ Liệu (Sync Resilience & Data Integrity)

- **Mã tài liệu:** SPEC-SYNC-RESILIENCE-01
- **Phân hệ:** Data Ingestion, Schedule Matching, Auth Lifecycle & Background Sync
- **Tác giả:** Senior Business Analyst & Software Architect
- **Trạng thái:** Approved / Ready for Implementation

---

## 1. YÊU CẦU & BẢNG PHÂN TÍCH HIỆN TRẠNG (REQUIREMENTS & GAP AUDIT)

| Hạng mục / Vị trí | Hiện trạng (Current State) | Rủi ro & Hạn chế (Risks) | Giải pháp chuẩn kiến trúc (Target Standard) |
| :--- | :--- | :--- | :--- |
| **1. Date Pattern Matcher**<br>`ScheduleProvider:316`<br>`LocalNotificationService:159` | Tìm vị trí dấu gạch nối bằng `tg.indexOf('-', 10)`. Giả định ngày bắt đầu luôn dài $\ge 10$ ký tự. | **Lỗi Magic Number:** Nếu web trường trả về ngày không có số 0 ở đầu (`5/9/2026-15/1/2027`), dấu `-` nằm ở index 8 hoặc 9 $\rightarrow$ `indexOf` trả về `-1`. Môn học bị biến mất khỏi màn hình hôm nay và không được đặt báo thức. | Dùng Regex `RegExp(r'\d{1,2}/\d{1,2}/\d{4}')` trích xuất danh sách các mốc ngày (ít nhất 2 mốc start/end). Miễn nhiễm với mọi độ dài ngày tháng, dấu nối (`-`, `–`, `—`) và khoảng trắng. |
| **2. Early-Stop Network Guard**<br>`ScheduleApi:188-195` | `if (dot >= 3 && !dotHasItems) break;`. Dừng quét khi Đợt 3 không có môn. | **Ngắt sớm do rớt mạng:** Nếu Đợt 3 có môn nhưng bị timeout/rớt mạng (`r.success == false`), `dotHasItems` vẫn là `false`. App hiểu nhầm là đợt trống và dừng quét, làm mất lịch của Đợt 4..8. | Chỉ dừng khi Đợt 3 mạng thành công 100% nhưng không có môn: `dot >= 3 && !dotHasItems && bothSuccess`. Nếu có request lỗi mạng, không ngắt sớm và đánh dấu `complete = false`. |
| **3. Transient Network Retries**<br>`GlobalApiQueue:115-125` | Chỉ bắt `TimeoutException` và `SocketException` để retry. Các lỗi khác rơi vào `catch` chung và bị fail ngay lập tức. | **Rớt kết nối bất thường:** Khi chuyển vùng mạng (4G $\leftrightarrow$ WiFi), Dart ném `http.ClientException`, `HandshakeException`, `TlsException`, `HttpException`. Các lỗi này không được retry mà bị fail ngay. | Mở rộng khối `on Exception catch` hoặc bắt các transient exceptions phổ biến của network để kích hoạt retry 2 lần với exponential backoff (2s, 4s). |
| **4. History Sync Flags on Logout**<br>`AppProvider:286-327` | Khi logout, app xóa file DB SQLite `schedify_uid$uid.db`, nhưng không xóa 2 cờ `has_done_initial_full_sync_$mssv` và `has_done_history_schedule_$mssv` trong `SharedPreferences`. | **Mất trắng lịch cũ vĩnh viễn:** Đăng nhập lại, app thấy cờ `has_done == true` nên bỏ qua quét lịch sử. DB mới tạo chỉ có 1 kỳ hiện tại, toàn bộ lịch cũ của các năm trước biến mất vĩnh viễn. | Trong `AppProvider.logout()`, bổ sung xóa sạch 2 cờ `has_done_initial_full_sync_$mssvToDelete` và `has_done_history_schedule_$mssvToDelete`. |
| **5. Infinite Reconcile Loop**<br>`ScheduleDb:7`<br>`AppProvider:188` | `needsReconcile()` kiểm tra bất kỳ dòng nào có `fetched_app_version != currentVer`. Khi `true`, gọi `syncAll()` nhưng `syncAll` chỉ kéo kỳ hiện tại. | **Lặp force-sync vĩnh viễn:** Các kỳ cũ trong DB vẫn giữ version cũ. Mỗi lần cold-start mở app, `needsReconcile` luôn trả về `true`, phá vỡ cache TTL 2 giờ của kỳ hiện tại. | Sau khi fetch thành công kỳ hiện tại ở phiên bản mới, thực hiện cập nhật hàng loạt `UPDATE lich_hoc SET fetched_app_version = ? WHERE fetched_app_version IS NULL OR fetched_app_version != ?` (và tương tự cho `lich_thi`) để dập cờ reconcile. |

---

## 2. ĐẶC TẢ CHI TIẾT LOGIC & THUẬT TOÁN (SPECIFICATIONS)

### 2.1. Regex Date Pattern Extraction (ScheduleProvider & LocalNotificationService)

Thay thế hàm `_lichHocMatchesDate`:
```dart
static bool _lichHocMatchesDate(LichHoc l, DateTime date) {
  final thuStr = l.thu.replaceAll('Thứ', '').trim();
  final thuNum = int.tryParse(thuStr);
  if (thuNum == null || thuNum < 2 || thuNum > 8) return false;
  final expectedWeekday = thuNum == 8 ? 7 : thuNum - 1;
  if (date.weekday != expectedWeekday) return false;

  final tg = l.thoiGian.trim();
  final dateMatches = RegExp(r'\d{1,2}/\d{1,2}/\d{4}')
      .allMatches(tg)
      .map((m) => m.group(0)!)
      .toList();

  if (dateMatches.length < 2) return false;

  DateTime? parseDMY(String s) {
    final p = s.split('/');
    if (p.length == 3) {
      final d = int.tryParse(p[0]);
      final m = int.tryParse(p[1]);
      final y = int.tryParse(p[2]);
      if (d != null && m != null && y != null) {
        return DateTime(y, m, d);
      }
    }
    return null;
  }

  final start = parseDMY(dateMatches[0]);
  final end = parseDMY(dateMatches[1]);
  if (start == null || end == null) return false;

  final targetDate = DateTime(date.year, date.month, date.day);
  return !targetDate.isBefore(start) && !targetDate.isAfter(end);
}
```

### 2.2. Early-Stop Network Guard (`lib/services/api/schedule_api.dart`)

Trong vòng lặp `for (int dot = 1; dot <= 8; dot++)` của `fetchLichHocAllDotsWithStatus`:
```dart
final dotResults = await Future.wait(dotFutures);
bool dotHasItems = false;
bool dotAllSuccessful = true;

for (int cn = 0; cn <= 1; cn++) {
  final r = dotResults[cn];
  if (!r.success) {
    complete = false;
    dotAllSuccessful = false;
  }
  if (r.items.isNotEmpty) {
    dotHasItems = true;
    allResults.addAll(r.items);
  }
}

// Early-Stop Heuristic: Chỉ dừng khi Đợt 3 thành công mạng 100% nhưng không có môn
if (dot >= 3 && !dotHasItems && dotAllSuccessful) {
  print('   🛑 [Early-Stop] Đợt $dot rỗng ở cả 2 ngành (mạng OK) → kết thúc quét kỳ này.');
  break;
}
```

### 2.3. Mở rộng Transient Network Error Retry (`lib/services/global_api_queue.dart`)

Trong `_runTask`:
```dart
try {
  final result = await queuedTask.task().timeout(timeoutDuration);
  if (!queuedTask.completer.isCompleted) {
    queuedTask.completer.complete(result);
  }
} on TimeoutException catch (e, st) {
  _handleRetry(queuedTask, e, st);
} on SocketException catch (e, st) {
  _handleRetry(queuedTask, e, st);
} on http.ClientException catch (e, st) {
  _handleRetry(queuedTask, e, st);
} on HttpException catch (e, st) {
  _handleRetry(queuedTask, e, st);
} catch (e, st) {
  // Kiểm tra chuỗi lỗi nếu là HandshakeException / TlsException
  final errStr = e.toString();
  if (errStr.contains('HandshakeException') ||
      errStr.contains('TlsException') ||
      errStr.contains('Connection closed') ||
      errStr.contains('Software caused connection abort')) {
    _handleRetry(queuedTask, e, st);
  } else {
    if (!queuedTask.completer.isCompleted) {
      queuedTask.completer.completeError(e, st);
    }
  }
}
```

### 2.4. Dọn dẹp cờ Lịch sử khi Logout (`lib/providers/app_provider.dart`)

Trong `logout()`:
```dart
final syncPrefs = await SharedPreferences.getInstance();
await syncPrefs.remove('has_done_initial_full_sync_$mssvToDelete');
await syncPrefs.remove('has_done_history_schedule_$mssvToDelete');
```

### 2.5. Dập cờ Reconcile khi Sync thành công (`lib/services/db/schedule_db.dart` & `app_provider.dart`)

Thêm hàm vào `ScheduleDb`:
```dart
static Future<void> stampAllRecordsWithAppVersion(String appVersion, {Database? db}) async {
  final d = db ?? await DatabaseService.db;
  await d.update(
    'lich_hoc',
    {'fetched_app_version': appVersion},
    where: 'is_manual = 0 AND (fetched_app_version IS NULL OR fetched_app_version != ?)',
    whereArgs: [appVersion],
  );
  await d.update(
    'lich_thi',
    {'fetched_app_version': appVersion},
    where: 'is_manual = 0 AND (fetched_app_version IS NULL OR fetched_app_version != ?)',
    whereArgs: [appVersion],
  );
}
```
Và gọi hàm này trong `_asyncBackgroundLoginAndSync` sau khi `syncAll` hoàn thành.

---

## 3. TIÊU CHUẨN NGHIỆM THU (ACCEPTANCE CRITERIA - AC CHECKLIST)

- [ ] **AC-01 (Date Matching):** Hàm `_lichHocMatchesDate` nhận diện chính xác ngày học với định dạng `5/9/2026-15/1/2027`, `05/09/2026 - 15/01/2027`, `05/09/2026 – 15/01/2027` (en-dash) và không bị phụ thuộc vào độ dài chuỗi trước dấu nối.
- [ ] **AC-02 (Early-Stop Guard):** Khi Đợt 3 gặp lỗi mạng (`r.success == false`), thuật toán Early-Stop KHÔNG được kích hoạt `break`. Vòng lặp vẫn tiếp tục hoặc giữ cờ `complete = false`.
- [ ] **AC-03 (Early-Stop Happy Path):** Khi Đợt 3 mạng thành công 100% và không có môn học ở cả 2 ngành, vòng lặp ngắt ngay tại Đợt 3 (không gửi request Đợt 4..8).
- [ ] **AC-04 (Network Retry Expansion):** `GlobalApiQueue` tự động thử lại khi gặp `http.ClientException` hoặc lỗi đứt socket với thời gian trễ 2s/4s.
- [ ] **AC-05 (Logout Cleanup):** Sau khi `logout()`, `has_done_initial_full_sync` và `has_done_history_schedule` bị xóa khỏi `SharedPreferences`. Đăng nhập lại cùng MSSV sẽ kích hoạt full sync đúng quy trình.
- [ ] **AC-06 (Reconcile Stamping):** Sau khi nâng cấp phiên bản và chạy xong `syncAll`, toàn bộ bản ghi `is_manual = 0` trong SQLite được gắn `fetched_app_version` mới, `ScheduleDb.needsReconcile()` trả về `false` ở lần khởi động kế tiếp.
- [ ] **AC-07 (Automated Tests):** Chạy `flutter test` thành công 100%, bổ sung test case mô phỏng cho các ca biên trên.
