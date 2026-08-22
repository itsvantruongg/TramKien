# TASK: Fix lỗi "môn học ảo" tồn đọng sau update version — Reconciliation theo scope, KHÔNG bắt logout/login lại

**Version áp dụng:** 1.0.6
**Nguyên tắc cốt lõi:** Sửa tận gốc bug đồng bộ dữ liệu mà KHÔNG làm gián đoạn trải nghiệm user (không force logout, không bắt đăng nhập lại thủ công). Toàn bộ quá trình chạy ngầm, tự động, an toàn khi mất mạng.

---

## Bối cảnh bug (đã audit xác nhận)

`ScheduleDb.saveLichHoc()` trong `lib/services/db/schedule_db.dart` hiện tại hoạt động kiểu **insert-or-ignore, không bao giờ xóa** record cũ. Khi server thay đổi dữ liệu (môn bị hủy, đổi lịch, đổi đợt học) giữa các lần app update, record cũ trong SQLite tồn tại vĩnh viễn, hiển thị sai lệch với `tinchi.hau.edu.vn`. App cũng không có cơ chế nào phát hiện "vừa được update lên version mới" để trigger dọn dẹp tự động — lỗi này từng chỉ được che tạm bằng việc user vô tình logout/login.

**Ràng buộc bắt buộc:** KHÔNG được xóa sạch DB vô điều kiện. Phải giữ nguyên record `is_manual = 1` (user tự thêm tay). Không bắt user phải thao tác gì thêm (không hiện màn login, không yêu cầu logout).

---

## Yêu cầu 1: Thêm cột theo dõi nguồn dữ liệu — Migration DB version 16

**File:** `lib/services/database_service.dart`

1. Tăng `_version` từ 15 lên 16.
2. Trong `onUpgrade`, thêm case `if (oldV < 16)`:
   - `ALTER TABLE lich_hoc ADD COLUMN fetched_app_version TEXT`
   - `ALTER TABLE lich_hoc ADD COLUMN synced_at TEXT` (ISO8601 timestamp)
3. Trong `onCreate` (cho user cài mới hoàn toàn), thêm 2 cột này ngay từ đầu vào schema `lich_hoc`.

---

## Yêu cầu 2: Sửa `saveLichHoc()` — reconciliation (diff-delete) theo scope, an toàn khi fetch fail

**File:** `lib/services/db/schedule_db.dart`

**Logic mới:**
1. Hàm nhận thêm tham số `bool fetchSuccess` (truyền vào từ nơi gọi, dựa trên kết quả thật của API call — không suy đoán).
2. Chỉ thực hiện xóa + ghi khi đồng thời: `fetchSuccess == true` VÀ `list.isNotEmpty`.
   - Nếu fetch fail hoặc list rỗng do lỗi mạng → **giữ nguyên toàn bộ DB hiện có, không đụng vào gì cả**, return sớm.
3. Khi điều kiện ở bước 2 thỏa mãn, trong **1 transaction duy nhất**:
   - Xóa các record thuộc đúng scope `(hoc_ky, nam_hoc, dot_hoc, chuyen_nganh)` với điều kiện `is_manual = 0` (giữ nguyên record tay).
   - Insert lại toàn bộ `list` mới, kèm giá trị `fetched_app_version = <current app version>` và `synced_at = <now, ISO8601>`.
4. Log rõ số lượng record bị xóa / được insert (dùng `print` hoặc logger có sẵn trong project) để dev có thể theo dõi khi debug.
5. Xóa comment cũ `// KHÔNG xóa - chỉ insert-or-ignore để giữ data cũ`, thay bằng comment mô tả đúng hành vi mới.

**Test case bắt buộc viết (unit test hoặc test thủ công có ghi log kết quả):**
- TC1: Fetch mới khác hoàn toàn danh sách cũ trong cùng scope → DB sau cùng khớp 100% với danh sách mới.
- TC2: `fetchSuccess = false` → DB giữ nguyên như trước khi gọi hàm.
- TC3: DB có record `is_manual = 1` trong scope đang sync → record này còn nguyên sau khi sync.
- TC4: Sync 2 scope khác nhau (2 học kỳ) tuần tự → chỉ scope đang sync bị ảnh hưởng.

---

## Yêu cầu 3: Version-check khi khởi động + reconcile toàn bộ scope hiện có

**File:** `lib/providers/app_provider.dart`

**Dùng package:** `package_info_plus` để lấy version runtime thực tế (không hardcode string).

**Luồng xử lý trong `init()`:**

```
1. Đọc last_app_version từ SharedPreferences (key: 'last_app_version')
2. Lấy current_app_version từ package_info_plus
3. Load cache hiện có để hiển thị NGAY (giữ UX mượt, không block màn hình)

4. Nếu last_app_version == current_app_version:
   → Luồng bình thường, không làm gì thêm

5. Nếu last_app_version != current_app_version (bao gồm cả null/chưa từng lưu):
   a. Query getAllExistingScopes() — SELECT DISTINCT hoc_ky, nam_hoc, dot_hoc, 
      chuyen_nganh FROM lich_hoc (bao gồm cả scope không phải học kỳ hiện tại,
      vì user có thể có data nhiều kỳ)
   b. Nếu danh sách scope rỗng (DB chưa có data gì) → chỉ cần đảm bảo lần fetch 
      tiếp theo diễn ra bình thường, update last_app_version ngay, return.
   c. Với TỪNG scope, tuần tự (không chạy song song để tránh spam server):
      - Gọi fetchLichHocWithStatus() cho đúng scope đó
      - Gọi saveLichHoc(list, fetchSuccess: result.success, hocKy: ..., 
        namHoc: ..., ...) — dùng logic đã sửa ở Yêu cầu 2
      - Nếu fetch thành công → thêm scope vào danh sách "đã xong"
      - Nếu fetch fail → KHÔNG thêm vào "đã xong", thêm vào 
        pending_reconcile_scopes (lưu SharedPreferences dạng JSON)
   d. Sau khi xử lý hết tất cả scope:
      - Nếu TẤT CẢ đều thành công → cập nhật last_app_version = current_app_version,
        xóa sạch pending_reconcile_scopes
      - Nếu CÒN scope fail → KHÔNG cập nhật last_app_version (để lần mở app 
        tiếp theo tự động thử lại toàn bộ quy trình này)
   e. Trong lúc bước 5c đang chạy cho scope nào, nếu UI đang hiển thị đúng 
      scope đó → hiện trạng thái "đang đồng bộ" (loading nhẹ/badge, KHÔNG phải 
      full-screen loading) thay vì để user nhìn thấy data cache cũ chưa xác 
      nhận trong lúc chờ — tránh dù chỉ vài giây user nhìn nhầm môn ảo.

6. Nếu app mở lên mà pending_reconcile_scopes đã có sẵn từ lần trước 
   (do lần mở trước fetch fail) → tự động thử lại các scope đó ngay ở bước 5,
   không cần chờ version đổi lần nữa.
```

**Test case bắt buộc:**
- TC1: `last_app_version` cũ, version hiện tại mới, DB có 2 scope (2 học kỳ), cả 2 fetch thành công → cả 2 scope reconcile đúng, `last_app_version` được update.
- TC2: Version khác nhau, 1 trong 2 scope fetch fail (mô phỏng mất mạng) → scope fail giữ nguyên data cũ, scope thành công được reconcile, `last_app_version` KHÔNG update, `pending_reconcile_scopes` chứa đúng scope bị fail.
- TC3: Mở app lần tiếp theo với `pending_reconcile_scopes` có sẵn → tự động retry đúng scope đó mà không cần version đổi thêm lần nữa.
- TC4: Version giống nhau → không có hành vi đặc biệt, luồng init bình thường như cũ.

---

## Yêu cầu 4: Rà soát hành vi `logout()` — giữ nguyên, chỉ bổ sung comment

**File:** `lib/providers/app_provider.dart`, `lib/services/database_service.dart`

- Không sửa logic (`deleteCurrentUserDb()` vẫn xóa hẳn file `.db` khi logout).
- Thêm comment rõ: hành vi này nhằm đảm bảo tài khoản khác không thấy data sót của tài khoản trước, không phải cơ chế dùng để sửa lỗi đồng bộ (từ sau bản 1.0.6, việc dọn dữ liệu rác đã được xử lý tự động qua version-check ở Yêu cầu 3, không còn phụ thuộc vào việc user tự logout).

---

## Yêu cầu 5: Filter an toàn khi parse tên môn học (phòng ngừa, ưu tiên thấp)

**File:** `lib/services/schedule_api.dart`

1. Bổ sung điều kiện loại tên môn học không hợp lệ: chuỗi chỉ gồm 1 ký tự lặp lại (regex `^(.)\1*$`, bắt các case như "hhhh", "aaaa").
2. Log cảnh báo (không throw exception) khi có record bị loại bởi filter này.

---

## Yêu cầu 6: UI — tránh hiển thị "nhấp nháy" trong lúc reconcile

**File:** màn hình hiển thị lịch học (`schedule_screen.dart` hoặc tương đương)

- Khi `ScheduleProvider` đang trong trạng thái reconcile (theo Yêu cầu 3 bước 5e), hiện 1 badge/label nhỏ dạng "Đang cập nhật lịch học..." ở góc màn hình, không che toàn bộ UI, không dùng full-screen spinner.
- Khi reconcile xong (dù thành công hay fail), badge tự ẩn, danh sách môn học refresh lại theo data mới nhất trong DB.

---

## Rollout note (ghi vào CHANGELOG / PR description)

1. Version 1.0.6 chứa fix reconciliation dữ liệu lịch học.
2. User đang chạy bản có bug (có data rác từ trước): lần đầu mở app sau khi update lên 1.0.6, hệ thống tự động dọn sạch data rác theo từng scope, KHÔNG cần đăng xuất/đăng nhập lại, KHÔNG gián đoạn UX.
3. Record lịch học tự thêm tay (`is_manual = 1`) không bị ảnh hưởng trong toàn bộ quá trình.
4. Nếu lúc update đúng lúc mất mạng, app vẫn hoạt động bình thường với data cache cũ, và sẽ tự retry đồng bộ ở lần mở app kế tiếp có mạng — không cần user làm gì.

---

## Definition of Done

- [ ] Migration DB version 16 thêm `fetched_app_version`, `synced_at` vào `lich_hoc`.
- [ ] `saveLichHoc()` reconcile đúng scope, giữ `is_manual=1`, an toàn tuyệt đối khi `fetchSuccess=false`.
- [ ] Toàn bộ delete+insert trong 1 transaction.
- [ ] Version-check tự động chạy khi khởi động, xử lý đúng multi-scope, không bắt login lại.
- [ ] Cơ chế `pending_reconcile_scopes` hoạt động đúng khi fetch fail và retry ở lần mở sau.
- [ ] `logout()` giữ nguyên hành vi, có comment giải thích rõ mục đích.
- [ ] Filter tên môn học bổ sung, có log, không crash.
- [ ] UI hiện badge "đang cập nhật" nhẹ nhàng, không full-screen loading, không giật màn hình.
- [ ] Toàn bộ test case ở Yêu cầu 2 (4 TC) và Yêu cầu 3 (4 TC) pass.
- [ ] Test thủ công end-to-end: giả lập DB có data rác (bản cũ), cài đè bản 1.0.6, mở app → xác nhận lịch sạch sau vài giây, không hiện màn login, record tay không mất, không giật UI.