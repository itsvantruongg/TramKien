# BÁO CÁO ĐÁNH GIÁ CƠ CHẾ ĐỒNG BỘ API, HIỆU QUẢ VÀ TỔNG HỢP BUG NGẦM

> **Dự án**: Schedify / Ứng dụng Quản lý Học tập HAU  
> **Mục tiêu**: Đánh giá cơ chế điều phối request chống quá tải/block server trường (ASP.NET Tinchi HAU), rà soát hiệu quả thực tế và liệt kê toàn bộ các bug ngầm tiềm ẩn (mất data, lỗi background sync, lỗi xác thực session/cookie).

---

## MỤC LỤC
1. [Tổng quan hiện trạng & Các cơ chế bảo vệ đã có](#1-tổng-quan-hiện-trạng--các-cơ-chế-bảo-vệ-đã-có)
2. [Đánh giá hiệu quả thực tế & Rủi ro](#2-đánh-giá-hiệu-quả-thực-tế--rủi-ro)
3. [Tổng hợp chi tiết các Bug ngầm & Đoạn mã liên quan](#3-tổng-hợp-chi-tiết-các-bug-ngầm--đoạn-mã-liên-quan)
   - [Bug 1: Chạm/Vuốt làm mới ở màn hình con không có Mutex/Debounce (Nhân bản request)](#bug-1-chạmvuốt-làm-mới-ở-màn-hình-con-không-có-mutexdebounce-nhân-bản-request)
   - [Bug 2: Background Sync luôn bị Timeout 25s do nghẽn hàng đợi](#bug-2-background-sync-luôn-bị-timeout-25s-do-nghẽn-hàng-đợi)
   - [Bug 3: Quét càn quét 8 đợt × 2 ngành cho tất cả kỳ quá khứ (Bão request)](#bug-3-quét-càn-quét-8-đợt--2-ngành-cho-tất-cả-kỳ-quá-khứ-bão-request)
   - [Bug 4: Không chọn "Ghi nhớ mật khẩu" khiến Background Sync tê liệt hoàn toàn](#bug-4-không-chọn-ghi-nhớ-mật-khẩu-khiến-background-sync-tê-liệt-hoàn-toàn)
   - [Bug 5: Background Sync gọi sai API Điểm → Không bao giờ bắt được Điểm mới](#bug-5-background-sync-gọi-sai-api-điểm--không-bao-giờ-bắt-được-điểm-mới)
   - [Bug 6: Mất dữ liệu Lịch học khi mạng chập chờn (Partial Sync Data Loss)](#bug-6-mất-dữ-liệu-lịch-học-khi-mạng-chập-chờn-partial-sync-data-loss)
   - [Bug 7: Tham số tính toán Dynamic Timeout trong GlobalApiQueue bị lệch](#bug-7-tham-số-tính-toán-dynamic-timeout-trong-globalapiqueue-bị-lệch)
   - [Bug 8: Background Sync spam login thất bại liên tục khi người dùng đổi mật khẩu](#bug-8-background-sync-spam-login-thất-bại-liên-tục-khi-người-dùng-đổi-mật-khẩu)
4. [Bảng tóm tắt khuyến nghị & Giải pháp khắc phục](#4-bảng-tóm-tắt-khuyến-nghị--giải-pháp-khắc-phục)

---

## 1. TỔNG QUAN HIỆN TRẠNG & CÁC CƠ CHẾ BẢO VỆ ĐÃ CÓ

Hệ thống đã được thiết kế với nhiều lớp bảo vệ để tương thích với server ASP.NET IIS của trường:

1. **Hàng đợi tập trung (`GlobalApiQueue`)**:
   - `_maxConcurrent = 2`: Giới hạn tối đa 2 request chạy đồng thời để tránh hiện tượng khóa phiên (**ASP.NET Session State Lock**).
   - **Priority Queue**: Ưu tiên theo mức độ quan trọng `critical` (Auth/Info) > `high` (Lịch hiện tại) > `normal` (Điểm/Học phí) > `low` (Lịch sử các kỳ cũ).
   - **Exponential Backoff Retry**: Tự động thử lại khi gặp `TimeoutException` hoặc `SocketException` sau 2s, 4s.
2. **Khóa chống Thundering Herd khi hết Session (`_isReauthing`)**:
   - Dùng `Completer<bool>` tại `HauApiService.reauthenticateIfNeeded()`: Gom tất cả các request phát hiện session hết hạn vào chung 1 lần gọi `login()` duy nhất.
3. **Khóa liên Isolate (`SyncMutex`)**:
   - Sử dụng file lock nguyên tử (`.lock`) ngăn chặn Foreground UI và Background Workmanager/Fetch chạy đè lên nhau.
4. **Bộ nhớ đệm SQLite & TTL (`isStale`)**:
   - Lịch học kỳ cũ cache 7 ngày, kỳ hiện tại 2 giờ, điểm & học phí 6 giờ.
   - Throttling 30 phút khi mở lại app (`AppLifecycleState.resumed`).

---

## 2. ĐÁNH GIÁ HIỆU QUẢ THỰC TẾ & RỦI RO

- **Ưu điểm**:
  - Triệt tiêu hoàn toàn lỗi nghẽn socket hoặc crash do gửi đồng thời hàng chục request cùng lúc.
  - Không gây giật lag UI khi đang gửi nhận dữ liệu.
- **Rủi ro còn tồn tại**:
  - Dù đã khống chế được **tính đồng thời (`concurrency = 2`)**, nhưng **tổng số lượng request (`volume`)** trong 1 lần sync vẫn quá lớn (~140 - 160 requests cho sinh viên năm 3-4).
  - Gửi 150 request nối tiếp nhau liên tục trong 30–60s vẫn có thể kích hoạt cơ chế chống cào dữ liệu (WAF/Rate Limit) của trường hoặc bị trả về lỗi `503 Service Unavailable`.

---

## 3. TỔNG HỢP CHI TIẾT CÁC BUG NGẦM & ĐOẠN MÃ LIÊN QUAN

---

### BUG 1: Chạm/Vuốt làm mới ở màn hình con không có Mutex/Debounce (Nhân bản request)
- **Vị trí**:
  - `lib/screens/schedule_screen.dart` (Dòng 1083)
  - `lib/screens/grades_screen.dart` (Dòng 102)
  - `lib/screens/finance_screen.dart` (Dòng 43)
  - `lib/providers/app_provider.dart` (Dòng 624, 642, 672)
  - `lib/providers/schedule_provider.dart` (Dòng 120)

- **Đoạn mã hiện tại**:
  ```dart
  // lib/providers/app_provider.dart
  Future<void> syncSchedule({bool forceRefresh = true}) async {
    // KHÔNG hề có kiểm tra _isSyncing, cũng KHÔNG acquire SyncMutex!
    final prevLichHocCount = scheduleProvider.lichHoc.length;
    final prevLichThiCount = scheduleProvider.lichThi.length;
    await Future.wait([
      scheduleProvider.syncLichHoc(forceRefresh: forceRefresh),
      scheduleProvider.syncLichThi(forceRefresh: forceRefresh),
    ]);
    ...
  }
  ```
  ```dart
  // lib/providers/schedule_provider.dart
  Future<void> syncLichHoc({bool forceRefresh = false}) async {
    // KHÔNG kiểm tra if (_lichHocState) return;
    _lichHocState = true;
    notifyListeners();
    ...
  }
  ```
- **Hậu quả**: Nếu user vuốt làm mới 2-3 lần liên tục hoặc chuyển qua lại giữa các tab và vuốt làm mới, hàng trăm request sẽ tiếp tục bị đẩy thêm vào `GlobalApiQueue`, khiến hàng đợi phình to lên **300 – 500 request chờ**.

---

### BUG 2: Background Sync luôn bị Timeout 25s do nghẽn hàng đợi
- **Vị trí**: `lib/services/background_sync_service.dart` (Dòng 168–174)

- **Đoạn mã hiện tại**:
  ```dart
  // lib/services/background_sync_service.dart
  final results = await Future.wait<dynamic>([
    GradeApi.fetchDiem(),
    ScheduleApi.fetchLichHocFromStartWithStatus(mssv: mssv),
    ScheduleApi.fetchLichThiFromStartWithStatus(mssv: mssv),
    FinanceApi.fetchAndSaveHocPhi(),
  ]).timeout(const Duration(seconds: 25)); // <-- TIMEOUT CỐ ĐỊNH 25S
  ```
- **Hậu quả**: `ScheduleApi.fetchLichHocFromStartWithStatus` tạo ra ~128 request. Với `_maxConcurrent = 2`, quá trình này cần ít nhất 35–50 giây. Vì vậy, `Future.wait` hầu như **luôn luôn văng TimeoutException sau 25s**, khiến Background Sync luôn báo lỗi thất bại, nhưng các request con trong isolate vẫn chạy ngầm gây tốn pin và spam server vô ích.

---

### BUG 3: Quét càn quét 8 đợt × 2 ngành cho tất cả kỳ quá khứ (Bão request)
- **Vị trí**: `lib/services/api/schedule_api.dart` (Dòng 148–160, 243–266)

- **Đoạn mã hiện tại**:
  ```dart
  // lib/services/api/schedule_api.dart
  for (int dot = 1; dot <= 8; dot++) {
    for (int cn = 0; cn <= 1; cn++) {
      futures.add(_fetchLichHocWithRetry(
        hocKy: hocKy,
        namHoc: namHoc,
        chuyenNganh: cn,
        dotHoc: dot,
        priority: priority,
      ));
    }
  }
  ```
- **Hậu quả**: Dù là học kỳ của 2-3 năm trước (lịch đã cố định không bao giờ đổi), hệ thống vẫn bắn đủ 16 request/kỳ. Sinh viên năm 4 tạo ra $8 \times 16 = 128$ requests lịch học trong mỗi lần đồng bộ lịch sử.

---

### BUG 4: Không chọn "Ghi nhớ mật khẩu" khiến Background Sync tê liệt hoàn toàn
- **Vị trí**:
  - `lib/providers/app_provider.dart` (Dòng 211–219)
  - `lib/services/background_sync_service.dart` (Dòng 94–101)

- **Đoạn mã hiện tại**:
  ```dart
  // lib/providers/app_provider.dart
  if (remember) {
    await prefs.setString(_kMssv, mssv);
    await prefs.setString(_kPw, password);
  } else {
    await prefs.remove(_kMssv); // XÓA SẠCH
    await prefs.remove(_kPw);   // XÓA SẠCH
  }
  ...
  BackgroundSyncService.schedulePeriodicSync(); // VẪN ĐĂNG KÝ CHẠY NỀN!
  ```
  ```dart
  // lib/services/background_sync_service.dart (chạy ở Isolate nền)
  final mssv = prefs.getString('saved_mssv') ?? '';
  final pw = prefs.getString('saved_pw') ?? '';

  if (mssv.isEmpty || (mssv != 'admin' && pw.isEmpty)) {
    debugPrint('⚙️ [BG] Bỏ qua: thiếu thông tin đăng nhập (MSSV/PW)');
    return; // THOÁT NGAY LẬP TỨC
  }
  ```
- **Hậu quả**: Nếu user bỏ chọn "Ghi nhớ đăng nhập", Workmanager vẫn được lên lịch chạy mỗi 15 phút nhưng sẽ luôn thoát ngay ở Step 1, hoàn toàn không thể lấy session/cookie và không fetch được gì.

---

### BUG 5: Background Sync gọi sai API Điểm → Không bao giờ bắt được Điểm mới
- **Vị trí**:
  - `lib/services/background_sync_service.dart` (Dòng 169, 283–298)

- **Đoạn mã hiện tại**:
  ```dart
  // lib/services/background_sync_service.dart
  // Gọi GradeApi.fetchDiem() -> chỉ lấy Overview (hoc_ky = 0, is_overview = 1)
  final results = await Future.wait<dynamic>([
    GradeApi.fetchDiem(), 
    ...
  ]);
  ```
  ```dart
  // So sánh snapshot để bắn thông báo:
  final prevDiem = await GradeDb.getDiem(); // Mặc định is_overview = 0 (điểm theo kỳ)
  ...
  // newDiem cũng đọc is_overview = 0, trong khi fetchedDiem chỉ lưu overview (hoc_ky = 0)
  final addedDiem = newDiemKeys.difference(prevDiemKeys);
  ```
- **Hậu quả**: Background Sync **không đồng bộ bảng điểm chi tiết các kỳ** và tập `addedDiem` luôn rỗng → **Không bao giờ gửi được thông báo push "Có điểm mới"**.

---

### BUG 6: Mất dữ liệu Lịch học khi mạng chập chờn (Partial Sync Data Loss)
- **Vị trí**:
  - `lib/providers/schedule_provider.dart` (Dòng 148–153)
  - `lib/services/db/schedule_db.dart` (Dòng 50–77)

- **Đoạn mã hiện tại**:
  ```dart
  // lib/providers/schedule_provider.dart
  final result = await ScheduleApi.fetchLichHocFromStartWithStatus(mssv: _mssv);
  if (result.items.isNotEmpty) {
    // Lưu DB ngay cả khi result.complete == false (bị rớt mạng giữa chừng)
    await ScheduleDb.saveLichHoc(result.items);
  }
  ```
  ```dart
  // lib/services/db/schedule_db.dart
  // Scope Delete: Xóa sạch toàn bộ môn học trong học kỳ đó trước khi chèn mới
  for (final s in scopes) {
    await txn.delete(
      'lich_hoc',
      where: 'hoc_ky = ? AND nam_hoc = ? AND dot_hoc = ? AND is_manual = 0',
      whereArgs: [s.hocKy, s.namHoc, s.dotHoc],
    );
  }
  ```
- **Hậu quả**: Nếu một đợt học có 8 môn, nhưng do mạng lag chỉ tải được 3 môn (`result.complete = false`), hàm `saveLichHoc` sẽ xóa sạch 8 môn cũ trong SQLite và chỉ chèn 3 môn mới vào. **5 môn còn lại bị xóa mất khỏi bộ nhớ offline**.

---

### BUG 7: Tham số tính toán Dynamic Timeout trong GlobalApiQueue bị lệch
- **Vị trí**: `lib/services/global_api_queue.dart` (Dòng 49–50, 92–95)

- **Đoạn mã hiện tại**:
  ```dart
  // lib/services/global_api_queue.dart
  Duration dynamicTimeout(int queuePositionAtStart) =>
      Duration(seconds: 15 + queuePositionAtStart * 8);

  void _drain() {
    while (_activeCount < _maxConcurrent && _queue.isNotEmpty) {
      final positionAtStart = _activeCount; // <-- LỖI: _activeCount chỉ nhận giá trị 0 hoặc 1
      final next = _queue.removeAt(0);
      _activeCount++;
      _runTask(next, positionAtStart);
    }
  }
  ```
- **Hậu quả**: `positionAtStart` luôn bằng `0` hoặc `1` thay vì vị trí hàng đợi `_queue.length`. Timeout cho mỗi task đơn lẻ bị cố định ở mức 15s hoặc 23s thay vì tăng động theo độ dài hàng đợi.

---

### BUG 8: Background Sync spam login thất bại liên tục khi người dùng đổi mật khẩu
- **Vị trí**: `lib/services/background_sync_service.dart` (Dòng 127–134)

- **Đoạn mã hiện tại**:
  ```dart
  // lib/services/background_sync_service.dart
  final loginError = await HauApiService.login(mssv, pw);
  if (loginError != null) {
    debugPrint('⚙️ [BG][Step4-Login] Login thất bại: $loginError');
    return; // Thoát âm thầm, không hủy task Workmanager
  }
  ```
- **Hậu quả**: Khi user đổi mật khẩu, Workmanager cứ 15 phút lại thức dậy gửi request đăng nhập sai lên trường. Gửi liên tục nhiều lần có thể khiến tài khoản trường bị khóa tạm thời.

---

## 4. BẢNG TÓM TẮT KHUYẾN NGHỊ & GIẢI PHÁP KHẮC PHỤC

| Bug | Mức độ | Hướng xử lý đề xuất |
| :--- | :---: | :--- |
| **Spam vuốt màn hình con (Bug 1)** | 🔴 Cao | Thêm `if (_isSyncing \|\| _lichHocState) return;` và áp dụng `SyncMutex` vào `syncSchedule()`, `syncGrades()`, `syncFinance()`. |
| **Timeout 25s Background (Bug 2)** | 🔴 Cao | Ở Background chỉ fetch học kỳ hiện tại (16 request) thay vì quét toàn bộ từ năm nhất; hoặc nâng timeout lên `Duration(seconds: 90)`. |
| **Quét full 8 đợt kỳ cũ (Bug 3)** | 🟡 Trung bình | Các kỳ cũ chỉ đọc DB local. Khi pull-to-refresh chỉ quét học kỳ hiện tại; chỉ quét full lịch sử khi user bấm nút "Tải lại toàn bộ lịch sử". |
| **Bỏ nhớ mật khẩu hỏng BG (Bug 4)** | 🔴 Cao | Lưu mật khẩu vào `flutter_secure_storage` dành riêng cho Background Worker (độc lập với tùy chọn UI "Ghi nhớ mật khẩu"), hoặc hủy `schedulePeriodicSync` khi `remember == false`. |
| **BG Sync gọi sai API Điểm (Bug 5)** | 🔴 Cao | Đổi `GradeApi.fetchDiem()` thành `GradeApi.fetchDiemAllKyWithSummary(mssv: mssv)` trong `_runSyncLogic()`. |
| **Mất data do Partial Sync (Bug 6)** | 💥 Mất data | Trong `ScheduleProvider.syncLichHoc`, chỉ gọi `saveLichHoc` khi `result.complete == true`. Nếu `complete == false`, giữ nguyên dữ liệu SQLite cũ. |
| **Dynamic Timeout sai biến (Bug 7)** | 🟢 Nhẹ | Sửa `positionAtStart` thành `_queue.length` trước khi `_queue.removeAt(0)`. |
| **Spam login sai mật khẩu (Bug 8)** | 🟡 Trung bình | Khi `loginError != null`, bắn local notification: *"Phiên đăng nhập hết hạn, vui lòng mở app"* và gọi `BackgroundSyncService.cancelAll()`. |
