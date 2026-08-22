# Kế hoạch fix Background Sync — Tram_Kien v1.0.5+3

> Nguồn: `Audit background_sync_service.dart` (2026-08-18)
> Nguyên tắc: fix theo thứ tự phụ thuộc, không phải chỉ theo mức độ ưu tiên đơn thuần —
> một số bug Trung/Thấp phải fix TRƯỚC bug Cao vì là nền tảng cho fix sau.

---

## Thứ tự thực thi tổng quan

```
Phase 0 (Nền tảng, bắt buộc trước)
  └─ B5 → B4 → B6
Phase 1 (Cao — Root cause data)
  └─ B1 → B7 → B3
Phase 2 (Cao — Reconcile, phụ thuộc Phase 1)
  └─ B2
Phase 3 (Trung bình còn lại)
  └─ B10 (phụ thuộc B1/B7 hoàn tất)
Phase 4 (Thấp)
  └─ B8 → B9 (đã ổn, chỉ verify) → B11
```

Lý do đảo thứ tự: B5/B4/B6 tuy xếp "Trung bình" trong audit nhưng là hạ tầng an toàn
(mutex, guard, logging) — nếu fix B1/B2 (thay đổi luồng ghi DB) mà chưa có mutex,
rủi ro race condition cao hơn. Fix hạ tầng trước giúp debug Phase 1–2 dễ hơn.

---

## Phase 0 — Hạ tầng an toàn (làm trước tiên)

### B5 — Chỉ đăng ký periodic task sau khi login thành công
- **File:** `main.dart:42`, `lib/providers/app_provider.dart`
- **Việc cần làm:**
  1. Xóa lệnh gọi `BackgroundSyncService.schedulePeriodicSync()` ra khỏi `main()`.
  2. Gọi `schedulePeriodicSync()` ngay sau bước login thành công trong `AppProvider`
     (chỗ đang lưu MSSV/PW vào SharedPreferences).
  3. Gọi `BackgroundSyncService.cancelAll()` khi user logout.
- **Test:** Cài app mới, KHÔNG login → kiểm tra WorkManager không có task nào đăng ký
  (dùng `adb shell dumpsys jobscheduler` hoặc log trong `initialize()`).

### B4 — Thêm mutex/lock chống chạy chồng (foreground fetch vs background fetch)
- **File:** `background_sync_service.dart`
- **Việc cần làm:**
  1. Thêm static flag `static bool _isSyncing = false;` ở đầu class.
  2. Đầu `_runSyncLogic()`: nếu `_isSyncing == true` → log và `return` ngay.
  3. Set `_isSyncing = true` trước Step 1, dùng `try { ... } finally { _isSyncing = false; }`
     bọc toàn bộ logic để đảm bảo luôn reset kể cả khi exception.
  4. Áp dụng flag này cho CẢ đường gọi foreground (nếu có nơi nào khác trong app gọi
     cùng hàm sync thủ công, ví dụ nút "làm mới") — không chỉ riêng BG task.
- **Test:** Giả lập gọi `_runSyncLogic()` 2 lần liên tiếp gần nhau (dùng `Future.wait`
  trong unit test) → xác nhận lần thứ 2 bị skip, không có 2 transaction DB chạy song song.

### B6 — Bọc try/catch riêng cho từng bước, log rõ nguyên nhân
- **File:** `background_sync_service.dart:79, 95–98, 227`
- **Việc cần làm:**
  1. `DatabaseService.setMssv(mssv)` (dòng 79) → bọc try/catch riêng, log lỗi cụ thể
     (không để throw ra ngoài làm crash job).
  2. Snapshot "TRƯỚC" (`GradeDb.getDiem()`, dòng 95–98) → bọc try/catch riêng, nếu lỗi
     thì dùng danh sách rỗng làm baseline thay vì crash toàn bộ job.
  3. `LocalNotificationService.scheduleClasses()` (dòng 227) → bọc try/catch riêng,
     lỗi ở bước này không được làm mất dữ liệu đã ghi DB thành công trước đó.
  4. Chuẩn hóa log: mỗi catch phải log kèm tên bước (`[BG][StepX]`) để sau này debug
     dễ hơn khi user report "không thấy đồng bộ".
- **Test:** Giả lập lỗi từng bước (mock throw) → xác nhận job không crash toàn bộ,
  các bước sau vẫn chạy nếu không phụ thuộc bước lỗi.

---

## Phase 1 — Root cause dữ liệu rác (Cao)

### B1 + B7 — Diff-delete theo scope cho `lich_hoc` và `lich_thi`
- **File:** `schedule_db.dart:8–69` (saveLichHoc), `schedule_db.dart:130–163` (saveLichThi)
- **Việc cần làm:**
  1. Xác định "scope" của một lần fetch: `(mssv, hoc_ky, nam_hoc, dot_hoc)` — đây là
     phạm vi dữ liệu mà 1 lần fetch bao phủ.
  2. Sửa `saveLichHoc(items, {required mssv, required scope})`:
     - Trong 1 transaction: `DELETE FROM lich_hoc WHERE mssv=? AND hoc_ky=? AND nam_hoc=? AND dot_hoc=? AND is_manual=0`
       (chỉ xóa record do API tạo, **giữ nguyên `is_manual=1`** — lịch user tự thêm tay).
     - Sau đó `INSERT` toàn bộ `items` mới trong CÙNG transaction.
  3. Áp dụng tương tự cho `saveLichThi()`.
  4. Cập nhật nơi gọi trong `background_sync_service.dart` để truyền đúng `scope`
     tương ứng với kỳ/năm đang fetch (`fetchLichHocFromStart` cần trả về kèm scope
     đã fetch, không chỉ list phẳng).
  5. **Migration DB v16:** thêm cột `fetched_app_version TEXT`, `synced_at INTEGER`
     vào bảng `lich_hoc` và `lich_thi` (đã note "Planned v16" trong audit) — ghi giá
     trị này mỗi lần insert để phục vụ Phase 2 (reconcile).
- **Rủi ro cần lưu ý:** Nếu xóa nhầm dữ liệu `is_manual=1`, user mất lịch tự thêm →
  bắt buộc test kỹ điều kiện `is_manual=0` trong câu DELETE.
- **Test:**
  - Seed DB với 5 record cũ (trong đó 1 record `is_manual=1`) → chạy `saveLichHoc`
    với 3 record mới cùng scope → xác nhận: 4 record cũ (is_manual=0) bị xóa,
    1 record is_manual=1 vẫn còn, 3 record mới được thêm → tổng 4 record.
  - Test rollback: giả lập lỗi giữa chừng insert → xác nhận transaction rollback,
    không mất dữ liệu cũ.

### B3 — `GradeDb.saveDiem()` không kiểm tra complete flag
- **File:** `background_sync_service.dart:128–134`, `grade_api.dart:16–139`
- **Việc cần làm (chọn 1 trong 2 hướng):**
  - **Hướng A (khuyến nghị, ít thay đổi):** Giữ nguyên BG job chỉ fetch overview,
    nhưng thêm rõ ràng flag `source: 'overview'` khi ghi DB, và **không ghi đè**
    lên record đã có `source: 'per_semester'` mới hơn — tránh BG job "hạ cấp"
    dữ liệu chi tiết đã có từ lần user mở app fetch full.
  - **Hướng B (đầy đủ hơn, tốn quota API hơn):** Đổi BG job sang gọi
    `fetchDiemAllKyWithSummary()` (có `complete` flag) thay vì `fetchDiem()` overview,
    đồng bộ cách xử lý với `saveLichHoc`/`saveLichThi` (chỉ ghi khi `complete=true`).
  - Quyết định hướng A hay B cần cân nhắc: BG job chạy 6h/lần, fetch full có tốn
    thời gian/băng thông hơn overview không đáng kể? Nếu server HAU không giới hạn,
    nên chọn B để nhất quán logic toàn hệ thống.
- **Test:** Seed DB có bản ghi `source=per_semester` chi tiết → chạy BG job (overview) →
  xác nhận bản ghi chi tiết KHÔNG bị ghi đè bởi data overview nghèo hơn (nếu chọn hướng A).

---

## Phase 2 — Reconcile khi mở app (Cao, phụ thuộc Phase 1)

### B2 — Implement reconcile ở `app_provider.dart init()`
- **File:** `app_provider.dart` (init), phụ thuộc cột `fetched_app_version`/`synced_at`
  từ B1/B7 migration v16.
- **Việc cần làm:**
  1. Khi app khởi động (foreground) và user đã login: so sánh `fetched_app_version`
     lưu trong local record với version hiện tại của app.
  2. Nếu lệch version (ví dụ sau khi app update logic parse thay đổi) → trigger
     full refetch + diff-delete cho toàn bộ scope hiện có (không chờ BG job 6h).
  3. Đây LÀ nơi dọn "môn ảo" còn sót lại từ trước khi có B1/B7 (dữ liệu legacy).
  4. Đảm bảo dùng cùng mutex `_isSyncing` (từ B4) để tránh đụng độ với BG job nếu
     app mở đúng lúc BG job đang chạy.
- **Test:** Giả lập DB có `fetched_app_version` cũ hơn version hiện tại → mở app →
  xác nhận reconcile được trigger đúng 1 lần, không lặp vô hạn.

---

## Phase 3 — Trung bình còn lại

### B10 — Notification diff 2 chiều (phát hiện cả tăng và giảm)
- **File:** `background_sync_service.dart:192–210`
- **Phụ thuộc:** Phải làm SAU B1/B7, vì trước đó dữ liệu append-only khiến so sánh
  count không phản ánh đúng thực tế.
- **Việc cần làm:**
  1. Thay so sánh `length` bằng so sánh **set diff** theo khóa định danh
     (ví dụ `ten_hoc_phan + thu + tiet + hoc_ky` làm composite key).
  2. Tính `added = newSet - prevSet`, `removed = prevSet - newSet`.
  3. Notify riêng cho từng trường hợp: "Lịch học mới" (added) và "Môn học đã bị hủy"
     (removed) — 2 nội dung thông báo khác nhau.
- **Test:** Seed prev = 3 môn, new = 2 môn giữ nguyên + 1 môn mới thay 1 môn bị hủy →
  xác nhận cả 2 thông báo (thêm + hủy) đều được tạo đúng.

---

## Phase 4 — Thấp

### B8 — Log khi job bị defer do `requiresBatteryNotLow`
- **File:** `background_sync_service.dart:283`
- **Việc cần làm:** Không nhất thiết bỏ constraint (an toàn cho pin user), nhưng
  thêm cách để biết job bị defer: lưu `last_attempted_at` mỗi khi WorkManager
  dispatch (kể cả trước khi check battery), so sánh với `last_synced_at` để hiển
  thị cảnh báo nhẹ trong app "Đồng bộ ngầm bị trì hoãn do pin yếu" nếu lệch quá 12h.
- **Test:** Không bắt buộc automated test — verify bằng cách log thủ công trên thiết
  bị thật với pin < 15%.

### B9 — Verify iOS `NetworkType.ANY`
- **File:** `background_sync_service.dart:297`
- **Việc cần làm:** Không cần đổi code — audit đã xác nhận `_checkNetwork()` thủ
  công đang bù đắp đủ cho giới hạn của `ANY`. Chỉ cần thêm comment trong code giải
  thích lý do giữ cả 2 lớp kiểm tra (constraint + thủ công) để dev sau không xóa nhầm.

### B11 — `fee_details`/`payment_receipts` append-only
- **File:** `finance_db.dart:48–91`
- **Việc cần làm:** Áp dụng pattern diff-delete tương tự B1/B7 nhưng theo scope
  `(mssv, hoc_ky, nam_hoc)` cho học phí. Ưu tiên thấp vì học phí ít thay đổi, có thể
  gộp chung sprint với B1/B7 nếu muốn tái dùng code (refactor thành hàm chung
  `_diffDeleteAndInsert<T>()` generic dùng cho cả 3 bảng).

---

## Checklist bàn giao cho agent (copy nguyên văn khi giao việc)

```
Thực hiện fix theo đúng thứ tự Phase 0 → Phase 1 → Phase 2 → Phase 3 → Phase 4
trong file fix-plan-background-sync.md. Sau MỖI bug fix xong:
1. Chạy lại test case tương ứng đã mô tả trong plan.
2. KHÔNG chuyển sang bug tiếp theo nếu test case của bug hiện tại chưa pass.
3. Với B1/B7 (diff-delete): bắt buộc viết migration v16 và test rollback trước
   khi coi là hoàn thành — đây là thay đổi rủi ro cao nhất (có thể mất dữ liệu).
4. Sau khi xong toàn bộ Phase 1, chạy lại toàn bộ luồng _runSyncLogic() end-to-end
   trên môi trường staging/emulator với tài khoản test thật trước khi merge.
5. Báo cáo lại: bug nào đã fix, bug nào bị block và lý do.
```