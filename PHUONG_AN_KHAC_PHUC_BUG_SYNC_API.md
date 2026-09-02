# BẢN PHÂN TÍCH CÁC PHƯƠNG ÁN KHẮC PHỤC BUG NGẦM & ĐÁNH GIÁ ƯU / NHƯỢC ĐIỂM

> **Tài liệu**: Phương án khắc phục các lỗ hổng & Bug ngầm hệ thống Đồng bộ API  
> **Dự án**: Schedify (App Sinh viên HAU)  
> **Quy chuẩn**: Mỗi bug cung cấp từ 3 đến 5 giải pháp cụ thể kèm đánh giá **Ưu điểm / Nhược điểm** và **Đề xuất tối ưu**.

---

## MỤC LỤC
1. [Bug 1: Vuốt làm mới màn hình con thiếu Mutex / Debounce (Nhân bản request)](#bug-1-vuốt-làm-mới-màn-hình-con-thiếu-mutex--debounce-nhân-bản-request)
2. [Bug 2: Background Sync luôn bị Timeout 25s do nghẽn hàng đợi](#bug-2-background-sync-luôn-bị-timeout-25s-do-nghẽn-hàng-đợi)
3. [Bug 3: Quét càn quét 8 đợt × 2 ngành cho tất cả kỳ quá khứ (Bão request)](#bug-3-quét-càn-quét-8-đợt--2-ngành-cho-tất-cả-kỳ-quá-khứ-bão-request)
4. [Bug 4: Không chọn "Ghi nhớ mật khẩu" khiến Background Sync tê liệt hoàn toàn](#bug-4-không-chọn-ghi-nhớ-mật-khẩu-khiến-background-sync-tê-liệt-hoàn-toàn)
5. [Bug 5: Background Sync gọi sai API Điểm (`GradeApi.fetchDiem` vs `fetchDiemAllKyWithSummary`)](#bug-5-background-sync-gọi-sai-api-điểm-gradeapifetchdiem-vs-fetchdiemallkywithsummary)
6. [Bug 6: Mất dữ liệu Lịch học khi mạng chập chờn (Partial Sync Data Loss)](#bug-6-mất-dữ-liệu-lịch-học-khi-mạng-chập-chờn-partial-sync-data-loss)
7. [Bug 7: Tham số tính toán Dynamic Timeout trong GlobalApiQueue bị lệch](#bug-7-tham-số-tính-toán-dynamic-timeout-trong-globalapiqueue-bị-lệch)
8. [Bug 8: Background Sync spam login thất bại liên tục khi người dùng đổi mật khẩu](#bug-8-background-sync-spam-login-thất-bại-liên-tục-khi-người-dùng-đổi-mật-khẩu)
9. [Bảng ma trận tổng hợp & Mức độ ưu tiên triển khai](#9-bảng-ma-trận-tổng-hợp--mức-độ-ưu-tiên-triển-khai)

---

## BUG 1: Vuốt làm mới màn hình con thiếu Mutex / Debounce (Nhân bản request)

### 📌 Mô tả vấn đề:
Khi người dùng kéo `RefreshIndicator` ở các màn hình con (Lịch học, Điểm, Học phí) liên tục hoặc chuyển qua lại giữa các tab rồi vuốt làm mới, các hàm `syncSchedule()`, `syncGrades()`, `syncFinance()` không kiểm tra cờ đang chạy (`_isSyncing`) hay `SyncMutex`, khiến hàng trăm request bị dồn vào `GlobalApiQueue`.

---

### 💡 Các phương án khắc phục:

#### Phương án 1.1: Bổ sung State Guard & Khóa cục bộ tại Provider
Thêm kiểm tra `if (_isSyncing || _loadingState) return;` vào đầu tất cả các hàm sync đơn lẻ trong `AppProvider` và các Sub-Provider.
```dart
Future<void> syncSchedule({bool forceRefresh = true}) async {
  if (_isSyncing || scheduleProvider.lichHocLoading || scheduleProvider.lichThiLoading) {
    debugPrint('⚠️ [Schedule] Sync đang chạy, bỏ qua request trùng lặp.');
    return;
  }
  _isSyncing = true;
  try {
    await Future.wait([
      scheduleProvider.syncLichHoc(forceRefresh: forceRefresh),
      scheduleProvider.syncLichThi(forceRefresh: forceRefresh),
    ]);
  } finally {
    _isSyncing = false;
  }
}
```
- **Ưu điểm**: Cực kỳ đơn giản, trực diện, không tạo overhead, sửa lỗi tức thì.
- **Nhược điểm**: Chỉ bảo vệ trong cùng một Isolate giao diện; nếu có sự kiện từ Isolate khác vẫn cần Mutex.

---

#### Phương án 1.2: Áp dụng `SyncMutex` toàn cục cho cả các hàm sync đơn lẻ
Bắt buộc gọi `SyncMutex.acquireLock(_currentMssv)` trước khi chạy bất kỳ thao tác sync nào (`syncSchedule`, `syncGrades`, `syncFinance`).
```dart
Future<void> syncSchedule({bool forceRefresh = true}) async {
  final acquired = await SyncMutex.acquireLock(_currentMssv);
  if (!acquired) {
    debugPrint('⚙️ [Schedule] Bị hoãn do có tiến trình sync khác đang giữ lock.');
    return;
  }
  try {
    // Thực hiện sync
  } finally {
    await SyncMutex.releaseLock(_currentMssv);
  }
}
```
- **Ưu điểm**: Đồng bộ và nhất quán 100% giữa Foreground UI (các màn hình khác nhau) và Background Worker Isolate.
- **Nhược điểm**: Nếu không cẩn thận trong khối `finally` có thể gây giữ lock lâu; cần đặt timeout hợp lý cho lock.

---

#### Phương án 1.3: Áp dụng Throttling theo thời gian (Cooldown 30s)
Đặt thời gian tối thiểu giữa 2 lần vuốt làm mới trên cùng 1 màn hình (ví dụ: 30 giây). Nếu vuốt lại trong thời gian này, chỉ tải lại từ cache SQLite và hiển thị thông báo nhẹ (Toast / SnackBar: *"Dữ liệu vừa được cập nhật, thử lại sau ít phút"*).
```dart
DateTime? _lastScheduleSync;
Future<void> syncSchedule({bool forceRefresh = true}) async {
  final now = DateTime.now();
  if (_lastScheduleSync != null && now.difference(_lastScheduleSync!) < const Duration(seconds: 30)) {
    await scheduleProvider.refreshFromCache();
    return;
  }
  _lastScheduleSync = now;
  // Thực hiện sync...
}
```
- **Ưu điểm**: Ngăn chặn hoàn toàn hành vi cố tình kéo giật màn hình liên tục của người dùng, giảm tải tối đa cho server trường.
- **Nhược điểm**: Người dùng có thể cảm thấy bớt linh hoạt nếu họ thực sự vừa đăng ký lớp mới và muốn kiểm tra ngay.

---

#### Phương án 1.4: Triệt tiêu trùng lặp (Deduplication) ở tầng `GlobalApiQueue`
Trong `GlobalApiQueue`, kiểm tra nếu một Task với cùng `Url + Method + QueryParams` đang nằm trong hàng đợi hoặc đang chạy, trả về luôn `Future` của Task đó thay vì tạo mới.
- **Ưu điểm**: Bảo vệ triệt để ở tầng network thấp nhất, mọi caller gọi bừa bãi thế nào cũng chỉ phát sinh 1 request HTTP.
- **Nhược điểm**: Phức tạp trong việc băm và định danh Key duy nhất cho từng closure task; khó xử lý khi một request cố tình muốn fetch dữ liệu mới nhất (force refresh).

---

> 🎯 **KHUYẾN NGHỊ**: Kết hợp **Phương án 1.1** (State Guard) + **Phương án 1.2** (`SyncMutex`).

---

## BUG 2: Background Sync luôn bị Timeout 25s do nghẽn hàng đợi

### 📌 Mô tả vấn đề:
Trong `background_sync_service.dart`, lệnh `Future.wait([...]).timeout(const Duration(seconds: 25))` bọc lấy việc fetch toàn bộ 4 API (trong đó Lịch học quét từ năm nhất tạo ra ~128 request). Với `_maxConcurrent = 2`, quá trình này cần ít nhất 35–50 giây $\rightarrow$ Background sync luôn văng lỗi `TimeoutException` và thất bại.

---

### 💡 Các phương án khắc phục:

#### Phương án 2.1: Giới hạn phạm vi Background Sync — Chỉ fetch Học kỳ hiện tại
Ở chế độ chạy nền, Lịch học và Lịch thi chỉ quét học kỳ hiện tại ($1 \times 16 = 16$ requests) thay vì quét toàn bộ lịch sử các năm cũ.
```dart
// Trong background_sync_service.dart
final sem = ScheduleProvider.detectCurrentSemester();
final results = await Future.wait<dynamic>([
  GradeApi.fetchDiemRecent(mssv: mssv),
  ScheduleApi.fetchLichHocAllDotsWithStatus(hocKy: sem.hocKy, namHoc: sem.namHoc, mssv: mssv),
  ScheduleApi.fetchLichThiWithStatus(hocKy: sem.hocKy, namHoc: sem.namHoc),
  FinanceApi.fetchAndSaveHocPhi(),
]).timeout(const Duration(seconds: 25));
```
- **Ưu điểm**: Thời gian chạy nền cực nhanh (chỉ mất ~5–8 giây), đảm bảo 100% không bao giờ bị timeout 25s, tiết kiệm pin và dung lượng 4G tối đa.
- **Nhược điểm**: Không cập nhật được lịch thi hoặc điểm của các kỳ cũ nếu có thay đổi muộn từ phía nhà trường (thực tế các kỳ cũ hiếm khi đổi).

---

#### Phương án 2.2: Tăng Timeout của `Future.wait` lên 60s – 90s
Nâng thời gian chờ của `Future.wait` trong background lên `Duration(seconds: 75)`.
- **Ưu điểm**: Giữ nguyên logic quét toàn bộ lịch sử mà không cần sửa cấu trúc fetch.
- **Nhược điểm**: Trên iOS (`background_fetch`), hệ điều hành chỉ cấp tối đa khoảng 30s cho headless task; nếu chạy quá lâu sẽ bị iOS cưỡng chế tắt tiến trình và phạt giảm tần suất đánh thức ứng dụng.

---

#### Phương án 2.3: Tách Background Sync thành chuỗi tác vụ độc lập (Checkpoint / Pipeline)
Không dùng `Future.wait` gộp cả 4 API, mà chạy tuần tự từng API theo mức độ ưu tiên: `Lịch học HK này` $\rightarrow$ `Lịch thi` $\rightarrow$ `Điểm mới` $\rightarrow$ `Học phí`. Mỗi phần hoàn tất đến đâu ghi ngay vào SQLite đến đó.
```dart
// Checkpoint 1: Lịch học
try {
  final lichHoc = await ScheduleApi.fetchLichHocCurrentSemester(mssv: mssv).timeout(const Duration(seconds: 12));
  if (lichHoc.complete) await ScheduleDb.saveLichHoc(lichHoc.items);
} catch (e) { debugPrint('Lỗi sync lịch: $e'); }

// Checkpoint 2: Điểm
try {
  final diem = await GradeApi.fetchDiemRecent(mssv: mssv).timeout(const Duration(seconds: 10));
  // Lưu điểm...
} catch (e) { ... }
```
- **Ưu điểm**: Tính chịu lỗi cực cao; nếu một mục bị chậm/timeout thì các mục khác vẫn hoàn tất và lưu vào DB thành công, không bị "chết chùm".
- **Nhược điểm**: Code dài hơn, cần quản lý khối `try-catch` riêng lẻ cho từng service.

---

#### Phương án 2.4: Tăng số slot đồng thời riêng cho Background Worker (`_maxConcurrent = 3`)
Trong Isolate của Background Sync, cấu hình `GlobalApiQueue` chạy tối đa 3 request đồng thời thay vì 2 để rút ngắn tổng thời gian.
- **Ưu điểm**: Tăng tốc độ đồng bộ lên khoảng 30–40%.
- **Nhược điểm**: Tăng nguy cơ bị khóa session state nếu server ASP.NET IIS của trường bị nghẽn.

---

> 🎯 **KHUYẾN NGHỊ**: Kết hợp **Phương án 2.1** (Chỉ fetch kỳ hiện tại) + **Phương án 2.3** (Lưu checkpoint độc lập từng service).

---

## BUG 3: Quét càn quét 8 đợt × 2 ngành cho tất cả kỳ quá khứ (Bão request)

### 📌 Mô tả vấn đề:
`ScheduleApi.fetchLichHocFromStartWithStatus` lặp qua từng năm từ `startYear` đến nay. Mỗi năm có 2 kỳ, mỗi kỳ luôn bắn cố định 16 request ($8 \text{ đợt} \times 2 \text{ ngành}$), tạo ra 128–160 requests cho sinh viên năm 3–4 dù các kỳ cũ từ nhiều năm trước không hề có thay đổi.

---

### 💡 Các phương án khắc phục:

#### Phương án 3.1: Chiến lược đồng bộ 2 tầng (Two-Tier Sync)
- **Tầng 1 (Mặc định khi mở app / Pull-to-refresh / Background)**: Chỉ quét học kỳ hiện tại (16 requests). Các kỳ cũ đọc 100% từ SQLite.
- **Tầng 2 (Thủ công)**: Thêm nút *"Đồng bộ toàn bộ lịch sử các năm"* trong màn hình Cài đặt / Quản lý lịch để sinh viên chủ động bấm khi cần nạp lại toàn bộ dữ liệu từ năm nhất.
- **Ưu điểm**: Cắt giảm 90% số lượng request trong 99% các lần sử dụng app (từ 160 requests xuống 16 requests).
- **Nhược điểm**: Cần thiết kế thêm 1 nút bấm trong giao diện Cài đặt.

---

#### Phương án 3.2: Lưu danh sách Đợt rỗng (Empty Dot Blacklist Cache) vào SQLite
Khi quét một kỳ cũ lần đầu tiên, nếu đợt 3, 4, 5, 6, 7, 8 trả về rỗng, lưu vào bảng `cache_meta` rằng các đợt đó rỗng. Ở các lần đồng bộ sau, hệ thống sẽ bỏ qua hoàn toàn các đợt này.
- **Ưu điểm**: Tự động học và tối ưu theo từng sinh viên; không cần người dùng can thiệp; vẫn tự động quét lại nếu là học kỳ hiện tại.
- **Nhược điểm**: Cần viết thêm logic quản lý bảng blacklist đợt trong database.

---

#### Phương án 3.3: Thuật toán Dừng sớm (Adaptive Early-Exit)
Khi quét một học kỳ cũ, quét tuần tự đợt 1 $\rightarrow$ đợt 2 $\rightarrow$ đợt 3... Nếu gặp **2 đợt liên tiếp không có môn học**, lập tức dừng lại không quét các đợt tiếp theo của kỳ đó.
- **Ưu điểm**: Rất dễ cài đặt, không cần lưu trữ thêm trạng thái vào SQLite.
- **Nhược điểm**: Trường hợp cá biệt sinh viên học đợt 1 và học đợt 7 (học lại/học vượt kỳ hè), thuật toán dừng sớm có thể bỏ sót đợt 7 nếu đợt 2 và 3 rỗng.

---

#### Phương án 3.4: Tăng thời gian TTL Cache của các kỳ cũ lên 30–60 ngày
Đặt thời gian hết hạn (`TTL`) cho cache lịch học các kỳ cũ là 30 hoặc 60 ngày thay vì 7 ngày.
- **Ưu điểm**: Không cần sửa đổi logic duyệt vòng lặp `for`.
- **Nhược điểm**: Khi hết hạn 30 ngày, cơn "bão" 160 requests vẫn sẽ xảy ra 1 lần.

---

> 🎯 **KHUYẾN NGHỊ**: Áp dụng **Phương án 3.1** (Chiến lược 2 tầng: Tự động chỉ sync kỳ này, thủ công mới sync full).

---

## BUG 4: Không chọn "Ghi nhớ mật khẩu" khiến Background Sync tê liệt hoàn toàn

### 📌 Mô tả vấn đề:
Khi người dùng đăng nhập mà không tích chọn "Ghi nhớ mật khẩu" (`remember = false`), `AppProvider` chủ động xóa `saved_mssv` và `saved_pw` khỏi `SharedPreferences`. Nhưng `BackgroundSyncService` vẫn được đăng ký chạy nền, dẫn đến việc task nền thức dậy không tìm thấy tài khoản/mật khẩu và thoát ngay lập tức.

---

### 💡 Các phương án khắc phục:

#### Phương án 4.1: Tách biệt Credentials giao diện và Credentials chạy nền (Dùng `flutter_secure_storage`)
Lưu tài khoản và mật khẩu vào phân vùng mã hóa an toàn (`FlutterSecureStorage` - Android KeyStore / iOS Keychain) dành riêng cho Background Worker. "Ghi nhớ mật khẩu" trên giao diện chỉ quyết định việc có tự điền vào Form đăng nhập khi mở app hay không.
```dart
// Lưu an toàn cho Background Worker độc lập với tùy chọn UI
final secureStorage = const FlutterSecureStorage();
await secureStorage.write(key: 'bg_mssv', value: mssv);
await secureStorage.write(key: 'bg_pw', value: password);
```
- **Ưu điểm**: Background Sync luôn hoạt động trơn tru; dữ liệu mật khẩu được mã hóa phần cứng an toàn tuyệt đối; khi bấm "Đăng xuất" sẽ xóa sạch cả 2 nơi.
- **Nhược điểm**: Cần thêm package `flutter_secure_storage`.

---

#### Phương án 4.2: Tự động Hủy Background Sync nếu người dùng không chọn Ghi nhớ
Nếu `remember == false`, lập tức gọi `BackgroundSyncService.cancelAll()`. Đồng thời trong phần Cài đặt hiển thị chú thích rõ ràng: *"Cần bật Ghi nhớ đăng nhập để nhận thông báo nền"*.
```dart
if (remember) {
  await prefs.setString(_kMssv, mssv);
  await prefs.setString(_kPw, password);
  await BackgroundSyncService.schedulePeriodicSync();
} else {
  await prefs.remove(_kMssv);
  await prefs.remove(_kPw);
  await BackgroundSyncService.cancelAll(); // HỦY CHẠY NỀN
}
```
- **Ưu điểm**: Tôn trọng tuyệt đối quyền riêng tư của người dùng; không chạy ngầm vô ích gây tốn pin khi không có quyền lưu thông tin.
- **Nhược điểm**: Người dùng sẽ không nhận được thông báo đẩy lịch học/điểm mới nếu họ không bật ghi nhớ.

---

#### Phương án 4.3: Mặc định luôn ghi nhớ phiên đăng nhập (Chuẩn hóa như các App hiện đại)
Bỏ checkbox "Ghi nhớ đăng nhập" trên màn hình Login (hoặc luôn đặt `true` theo mặc định). App chỉ xóa phiên và thông tin khi người dùng chủ động bấm nút "Đăng xuất" trong Cài đặt.
- **Ưu điểm**: Đơn giản hóa trải nghiệm đăng nhập, triệt tiêu 100% khả năng lỗi thiếu thông tin chạy nền.
- **Nhược điểm**: Không có tùy chọn cho người dùng muốn nhập mật khẩu thủ công mỗi lần mở app trên máy dùng chung.

---

#### Phương án 4.4: Lưu Cookie / Session Token thay vì lưu Password
Chỉ lưu chuỗi Cookie session vào SharedPreferences cho Background Worker.
- **Ưu điểm**: Không cần lưu trữ mật khẩu gốc của người dùng.
- **Nhược điểm**: Session cookie của ASP.NET thường hết hạn sau 20–60 phút không hoạt động; khi hết hạn background worker sẽ không thể tự đăng nhập lại được.

---

> 🎯 **KHUYẾN NGHỊ**: **Phương án 4.1** (Lưu Secure Storage) hoặc **Phương án 4.2** (Hủy task kèm thông báo UI rõ ràng).

---

## BUG 5: Background Sync gọi sai API Điểm (`GradeApi.fetchDiem` vs `fetchDiemAllKyWithSummary`)

### 📌 Mô tả vấn đề:
Trong `background_sync_service.dart`, hàm sync gọi `GradeApi.fetchDiem()` (chỉ lấy trang Overview Index gán `hoc_ky = 0`). Khi lưu vào SQLite, nó không cập nhật bảng điểm chi tiết các kỳ (`is_overview = 0`), khiến snapshot so sánh `prevDiem` vs `newDiem` luôn không thấy thay đổi $\rightarrow$ Không bao giờ phát hiện được điểm mới trong nền.

---

### 💡 Các phương án khắc phục:

#### Phương án 5.1: Chuyển sang gọi `GradeApi.fetchDiemAllKyWithSummary(mssv: mssv)`
Đổi lời gọi API trong `_runSyncLogic()` sang hàm đầy đủ đã được hoàn thiện cho Foreground.
```dart
// Trong background_sync_service.dart
final results = await Future.wait<dynamic>([
  GradeApi.fetchDiemAllKyWithSummary(mssv: mssv), // Sửa tại đây
  ScheduleApi.fetchLichHocAllDotsWithStatus(...),
  ...
]);
```
- **Ưu điểm**: Đồng bộ chuẩn xác 100% dữ liệu chi tiết giữa Foreground và Background; giải quyết triệt để lỗi snapshot điểm.
- **Nhược điểm**: `fetchDiemAllKyWithSummary` duyệt qua tất cả các kỳ nên sẽ tốn thêm khoảng 6–10 requests.

---

#### Phương án 5.2: Xây dựng hàm chuyên biệt `GradeApi.fetchDiemRecentSemester({int count = 2})`
Viết một hàm rút gọn trong `GradeApi` chỉ fetch điểm của **2 học kỳ gần nhất** kèm trang Index.
```dart
static Future<DiemResult> fetchDiemRecentSemester({required String mssv, int count = 2}) async {
  // Chỉ lấy điểm HK hiện tại và HK liền trước
}
```
- **Ưu điểm**: Tối ưu tối đa cho Background Sync (chỉ tốn đúng 2–3 requests); điểm mới luôn chỉ xuất hiện ở các kỳ gần nhất.
- **Nhược điểm**: Cần viết thêm 1 hàm mới trong `grade_api.dart`.

---

#### Phương án 5.3: So sánh trực tiếp trên trang Overview Index
Sửa logic so sánh snapshot điểm trong background: Thay vì so sánh danh sách môn chi tiết (`is_overview = 0`), so sánh trực tiếp bảng Overview và trường `tbcTichLuyHe10` từ `DiemSummary`.
- **Ưu điểm**: Tận dụng được lời gọi `fetchDiem()` hiện tại (chỉ 1 request).
- **Nhược điểm**: Bảng Overview trên web trường nhiều khi không hiển thị chi tiết điểm thành phần/điểm thi của từng môn mới.

---

> 🎯 **KHUYẾN NGHỊ**: Áp dụng **Phương án 5.2** (Viết `fetchDiemRecentSemester` cho Background) hoặc **Phương án 5.1**.

---

## BUG 6: Mất dữ liệu Lịch học khi mạng chập chờn (Partial Sync Data Loss)

### 📌 Mô tả vấn đề:
Trong `ScheduleProvider.syncLichHoc`, hệ thống gọi `ScheduleDb.saveLichHoc(result.items)` ngay cả khi `result.complete == false` (bị rớt mạng giữa chừng). Do `saveLichHoc` thực hiện **Scope Delete** (xóa sạch dữ liệu kỳ đó trước khi chèn mới), các môn học cũ chưa kịp tải lại sẽ bị xóa mất khỏi SQLite.

---

### 💡 Các phương án khắc phục:

#### Phương án 6.1: Thêm điều kiện kiểm tra `if (result.complete)` trước khi lưu DB
Chỉ cho phép ghi đè SQLite khi toàn bộ quá trình fetch báo thành công 100% (`complete == true`).
```dart
// lib/providers/schedule_provider.dart
final result = await ScheduleApi.fetchLichHocFromStartWithStatus(mssv: _mssv);
if (result.complete && result.items.isNotEmpty) {
  await ScheduleDb.saveLichHoc(result.items);
  await DatabaseService.updateCacheMeta(currentKey, 'synced');
} else {
  debugPrint('⚠️ [LichHoc] Fetch không hoàn tất (mạng chập chờn) -> Giữ nguyên dữ liệu SQLite cũ.');
}
```
- **Ưu điểm**: Cực kỳ ngắn gọn (chỉ 1 dòng `if`), an toàn tuyệt đối, đồng bộ hoàn hảo với logic trong `BackgroundSyncService`.
- **Nhược điểm**: Nếu mạng lỗi ở 1 đợt nhỏ không quan trọng, các môn mới của các đợt khác cũng phải chờ lần sync sau mới được lưu.

---

#### Phương án 6.2: Áp dụng Upsert theo từng bản ghi (Atomic Upsert Merge)
Bỏ cơ chế xóa phạm vi (`Scope Delete`). Dùng câu lệnh SQLite `INSERT OR REPLACE` dựa trên khóa duy nhất gồm: `(ten_hoc_phan, thoi_gian, thu, tiet, dot_hoc, nam_hoc, hoc_ky)`.
```sql
CREATE UNIQUE INDEX IF NOT EXISTS idx_lich_hoc_unique 
ON lich_hoc(ten_hoc_phan, thoi_gian, thu, tiet, dot_hoc, nam_hoc, hoc_ky);
```
- **Ưu điểm**: Tải được môn nào cập nhật ngay môn đó vào DB mà không bao giờ làm mất các môn khác nếu mạng bị đứt giữa chừng.
- **Nhược điểm**: Nếu nhà trường thực sự HỦY một môn học đã có trước đó, bản ghi bị hủy sẽ không tự biến mất (cần thêm cơ chế dọn dẹp theo `synced_at`).

---

#### Phương án 6.3: Sử dụng Bảng tạm trung gian (Staging Table Transaction)
Ghi toàn bộ kết quả fetch vào bảng tạm `lich_hoc_staging`. Chỉ khi nào toàn bộ quá trình quét xong xuôi và xác nhận hợp lệ, mới thực hiện hoán đổi (`swap/replace`) dữ liệu sang bảng chính `lich_hoc` trong 1 Transaction duy nhất.
- **Ưu điểm**: Chuẩn kiến trúc cơ sở dữ liệu ACID, không bao giờ rơi vào trạng thái dữ liệu dở dang.
- **Nhược điểm**: Tốn thêm dung lượng bộ nhớ DB và phải tạo thêm bảng tạm.

---

#### Phương án 6.4: Đánh dấu Soft-Delete kết hợp Timestamp
Thêm cột `last_seen_timestamp` vào bảng `lich_hoc`. Khi fetch được môn nào, cập nhật timestamp của môn đó thành `DateTime.now()`. Sau khi sync xong (nếu `complete == true`), xóa những môn có timestamp cũ hơn.
- **Ưu điểm**: Vừa an toàn khi mạng lag, vừa xóa được môn bị trường hủy bỏ.
- **Nhược điểm**: Phải nâng cấp schema database (`ALTER TABLE`).

---

> 🎯 **KHUYẾN NGHỊ**: Áp dụng **Phương án 6.1** (Kiểm tra `result.complete`) ngay lập tức, về lâu dài kết hợp **Phương án 6.4**.

---

## BUG 7: Tham số tính toán Dynamic Timeout trong GlobalApiQueue bị lệch

### 📌 Mô tả vấn đề:
Trong `global_api_queue.dart`, hàm `_drain()` truyền `positionAtStart = _activeCount;` (chỉ nhận giá trị `0` hoặc `1`) vào `dynamicTimeout(int queuePositionAtStart)`. Do đó, timeout không hề tăng động theo độ dài hàng đợi thực tế mà chỉ cố định ở 15s hoặc 23s.

---

### 💡 Các phương án khắc phục:

#### Phương án 7.1: Sửa đúng biến độ dài hàng đợi (`_queue.length`) kèm Clamp trần
Lấy vị trí thực tế của task trong hàng đợi trước khi lấy ra (`removeAt(0)`), đồng thời dùng `.clamp` để giới hạn trần timeout tối đa (ví dụ không quá 45s).
```dart
void _drain() {
  while (_activeCount < _maxConcurrent && _queue.isNotEmpty) {
    final queueLengthBefore = _queue.length; // Lấy độ dài hàng đợi thực tế
    final next = _queue.removeAt(0);
    _activeCount++;
    _runTask(next, queueLengthBefore);
  }
}

Duration dynamicTimeout(int queueLength) {
  final calculatedSec = 15 + (queueLength * 3); // 15s base + 3s mỗi task phía trước
  return Duration(seconds: calculatedSec.clamp(15, 45)); // Giới hạn từ 15s đến 45s
}
```
- **Ưu điểm**: Khôi phục đúng 100% ý đồ thiết kế timeout động; bảo vệ hệ thống không bị timeout quá sớm khi hàng đợi dài, đồng thời không bị treo vô hạn nhờ hàm `.clamp`.
- **Nhược điểm**: Cần điều chỉnh hệ số nhân (nhân 3s thay vì nhân 8s để tránh phình quá nhanh).

---

#### Phương án 7.2: Áp dụng Timeout cố định theo mức độ ưu tiên (Priority-based Timeout)
Bỏ công thức tính toán động theo số lượng hàng đợi. Đặt timeout tĩnh chuẩn xác theo `RequestPriority`.
```dart
Duration getTimeoutByPriority(RequestPriority p) {
  switch (p) {
    case RequestPriority.critical: return const Duration(seconds: 30);
    case RequestPriority.high:     return const Duration(seconds: 25);
    case RequestPriority.normal:   return const Duration(seconds: 20);
    case RequestPriority.low:      return const Duration(seconds: 15);
  }
}
```
- **Ưu điểm**: Rõ ràng, dễ debug, dự đoán chính xác thời gian phản hồi của từng loại request; giải phóng slot nhanh cho các request ít quan trọng.
- **Nhược điểm**: Khi hàng đợi quá dài, các task đứng sau có thể phải chờ lâu trước khi tới lượt chạy thực sự (nhưng khi đã vào `_runTask` thì thời gian chạy đơn lẻ vẫn chuẩn).

---

#### Phương án 7.3: Cho phép chỉ định Timeout trực tiếp khi `enqueue()`
Bổ sung tham số tùy chọn `Duration? customTimeout` khi gọi `GlobalApiQueue.instance.enqueue(...)`.
```dart
Future<T> enqueue<T>(
  Future<T> Function() task, {
  RequestPriority priority = RequestPriority.normal,
  Duration? timeout,
})
```
- **Ưu điểm**: Linh hoạt tối đa cho từng endpoint cụ thể (ví dụ login cần 25s, check home chỉ cần 10s).
- **Nhược điểm**: Phải rà soát và bổ sung tham số ở các nơi gọi `enqueue` trong code.

---

> 🎯 **KHUYẾN NGHỊ**: Áp dụng **Phương án 7.1** (Sửa biến `_queue.length` kèm clamp trần 45s).

---

## BUG 8: Background Sync spam login thất bại liên tục khi người dùng đổi mật khẩu

### 📌 Mô tả vấn đề:
Khi sinh viên đổi mật khẩu trên trang trường, hàm `HauApiService.login` trong nền trả về thông báo lỗi. Tuy nhiên `background_sync_service.dart` chỉ in log rồi thoát, không hủy task Workmanager và không thông báo cho người dùng, khiến hệ điều hành tiếp tục thử login sai mỗi 15 phút $\rightarrow$ Nguy cơ server trường khóa tài khoản sinh viên do spam đăng nhập sai.

---

### 💡 Các phương án khắc phục:

#### Phương án 8.1: Hủy Background Task & Gửi Local Notification thông báo cho sinh viên
Khi phát hiện lỗi đăng nhập do sai tài khoản/mật khẩu, lập tức hủy toàn bộ lịch chạy nền và bắn thông báo nhắc người dùng mở app cập nhật lại.
```dart
final loginError = await HauApiService.login(mssv, pw);
if (loginError != null) {
  debugPrint('⚙️ [BG] Đăng nhập thất bại: $loginError');
  if (loginError.contains('Sai') || loginError.contains('mật khẩu') || loginError.contains('tài khoản')) {
    // 1. Hủy lịch sync nền để chống spam khóa nick
    await BackgroundSyncService.cancelAll();
    // 2. Bắn thông báo ngay cho sinh viên
    await LocalNotificationService.showImmediate(
      id: 9999,
      title: 'Phiên đăng nhập đã hết hạn ⚠️',
      body: 'Không thể tự động đồng bộ lịch học/điểm do sai mật khẩu. Vui lòng mở ứng dụng để đăng nhập lại.',
    );
  }
  return;
}
```
- **Ưu điểm**: Bảo vệ tài khoản sinh viên an toàn tuyệt đối; người dùng nhận được thông báo ngay để kịp thời cập nhật.
- **Nhược điểm**: Cần đảm bảo khi người dùng mở lại app và đăng nhập thành công, app sẽ tự động đăng ký lại `BackgroundSyncService.schedulePeriodicSync()`.

---

#### Phương án 8.2: Áp dụng bộ đếm số lần thất bại (Max Retry Counter)
Lưu biến đếm `bg_login_fail_count` vào `SharedPreferences`. Nếu đăng nhập thất bại 3 lần liên tiếp mới tiến hành hủy task và bắn thông báo.
```dart
int failCount = prefs.getInt('bg_login_fail_count') ?? 0;
if (loginError != null) {
  failCount++;
  await prefs.setInt('bg_login_fail_count', failCount);
  if (failCount >= 3) {
    await BackgroundSyncService.cancelAll();
    // Bắn thông báo...
  }
  return;
} else {
  await prefs.setInt('bg_login_fail_count', 0); // Reset khi thành công
}
```
- **Ưu điểm**: Tránh việc hủy nhầm chạy nền nếu server trường chỉ bị lỗi chập chờn 1 lần duy nhất.
- **Nhược điểm**: Tốn thêm 1 key lưu trữ trong SharedPreferences.

---

#### Phương án 8.3: Phân loại lỗi mạng vs Lỗi xác thực
- Nếu là `SocketException`, `TimeoutException`, HTTP `500/502/503`: Coi là lỗi mạng $\rightarrow$ Giữ nguyên lịch sync để lần sau thử lại.
- Nếu là lỗi trả về từ form đăng nhập (sai user/pass): Coi là lỗi xác thực $\rightarrow$ Dừng sync ngay.
- **Ưu điểm**: Phản ứng chính xác theo từng ngữ cảnh lỗi.
- **Nhược điểm**: Phụ thuộc vào việc parse đúng thông báo lỗi từ trang trường.

---

> 🎯 **KHUYẾN NGHỊ**: Kết hợp **Phương án 8.3** (Phân loại lỗi) + **Phương án 8.1** (Hủy task & Thông báo cho sinh viên).

---

## 9. BẢNG MA TRẬN TỔNG HỢP & MỨC ĐỘ ƯU TIÊN TRIỂN KHAI

| Bug | Mức độ | Phương án khuyến nghị tối ưu | Độ phức tạp | Ước lượng thời gian |
| :--- | :---: | :--- | :---: | :---: |
| **Bug 1: Spam Pull-to-Refresh** | 🔴 Cao | Thêm State Guard (`_isSyncing`) + Khóa `SyncMutex` | Thấp | 15 phút |
| **Bug 2: Timeout 25s Background** | 🔴 Cao | Chỉ fetch Kỳ hiện tại + Tách Checkpoint độc lập | Trung bình | 30 phút |
| **Bug 3: Bão request kỳ cũ** | 🟡 Trung bình | Chiến lược 2 tầng (Auto sync kỳ này, manual sync full) | Trung bình | 45 phút |
| **Bug 4: Bỏ nhớ mật khẩu hỏng BG** | 🔴 Cao | Dùng `FlutterSecureStorage` lưu credentials nền | Trung bình | 30 phút |
| **Bug 5: BG Sync gọi sai API Điểm** | 🔴 Cao | Viết hàm `fetchDiemRecent` riêng cho Background Worker | Thấp | 20 phút |
| **Bug 6: Mất data Lịch do mạng lag** | 💥 Mất data | Chỉ gọi `saveLichHoc` khi `result.complete == true` | Rất thấp | 5 phút |
| **Bug 7: Dynamic Timeout sai biến** | 🟢 Nhẹ | Sửa `_queue.length` kèm `.clamp(15, 45)` | Rất thấp | 5 phút |
| **Bug 8: Spam login sai mật khẩu** | 🟡 Trung bình | Phân loại lỗi $\rightarrow$ Hủy task & Bắn push notification | Thấp | 20 phút |
