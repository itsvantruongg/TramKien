# Technical Specification: Chuyển Đổi Form Góp Ý Sang Headless Google Form & Tối Ưu UX (Headless Google Form Feedback)

- **Mã tài liệu:** SPEC-FEEDBACK-GOOGLE-FORM-01
- **Phân hệ:** User Profile, Customer Support & Feedback Ingestion
- **Tác giả:** Senior Business Analyst & Software Architect
- **Trạng thái:** Approved / Ready for Implementation

---

## 1. YÊU CẦU NGHIỆP VỤ & PHÂN TÍCH HIỆN TRẠNG (REQUIREMENTS & GAP AUDIT)

| Hạng mục / Tiêu chí | Hiện trạng (Current State) | Rủi ro & Hạn chế (Risks) | Giải pháp chuẩn kiến trúc (Target Standard) |
| :--- | :--- | :--- | :--- |
| **1. Trường dữ liệu Form**<br>`FeedbackScreen` | Yêu cầu 4 trường: Họ tên, **Số điện thoại**, Email, Nội dung. | **Rào cản tâm lý người dùng:** Sinh viên ngại cung cấp số điện thoại cá nhân vì sợ bị làm phiền/lộ thông tin. Phản hồi thực tế qua email nên trường SĐT là dư thừa. | **Bỏ hoàn toàn trường Số điện thoại.** Form chỉ còn 3 trường: Họ tên, Email, Nội dung góp ý. |
| **2. Tự động điền dữ liệu (Auto-Prefill UX)**<br>`FeedbackScreen:initState` | Bắt người dùng nhập thủ công lại toàn bộ Họ tên, Email dù đã đăng nhập vào app. | **Trải nghiệm kém (Friction):** Người dùng lười nhập lại thông tin cá nhân $\rightarrow$ giảm tỷ lệ gửi phản hồi/báo lỗi. | Tự động đọc thông tin sinh viên từ `AppProvider.student` (`hoTen` và `email`) để điền sẵn vào các ô tương ứng. Người dùng chỉ việc gõ nội dung. |
| **3. Cổng gửi dữ liệu (Backend Service)**<br>`FeedbackScreen:94` | Gửi qua bên thứ ba `formsubmit.co/ajax/loginchily1@gmail.com` kèm header giả mạo `Origin: https://tinchi.hau.edu.vn`. | **Lộ email cá nhân trên Git & rủi ro chặn CORS/Bot:** FormSubmit dễ bị lỗi chặn hoặc dính Captcha khi dùng trên mobile. Email cá nhân bị công khai trên mã nguồn mở. | **Chuyển sang Headless Google Form:** App gửi thẳng HTTP POST vào Google Form Endpoint của dự án. Không lộ email cá nhân, tự động ghi vào Google Sheet và kích hoạt thông báo Gmail miễn phí. |
| **4. Fallback Email**<br>`_openEmailFallback` | Mở ứng dụng Mail với nội dung kèm Số điện thoại. | Nội dung email dự phòng chứa trường SĐT không còn khớp với form mới. | Cập nhật template mailto loại bỏ số điện thoại, giữ định dạng sạch sẽ. |

---

## 2. ĐẶC TẢ KỸ THUẬT & API (TECHNICAL & API SPECS)

### 2.1. Google Form Contract & Field Mapping
- **Form Response Endpoint:**
  ```
  POST https://docs.google.com/forms/d/e/1FAIpQLSfe_FG1oCxfXZkRt0R766Rj9aWSX2z-w96-lMZsrxA6kAQlew/formResponse
  ```
- **Request Headers:**
  ```http
  Content-Type: application/x-www-form-urlencoded
  User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64)
  ```
- **Payload Mapping (Form Data):**
  | Tên trường trên UI | Mã Entry Google Form | Kiểu dữ liệu / Ràng buộc |
  | :--- | :--- | :--- |
  | **Họ và tên** | `entry.1036072439` | String, bắt buộc, trim khoảng trắng |
  | **Email** | `entry.336370746` | String, bắt buộc, regex email hợp lệ |
  | **Nội dung góp ý** | `entry.2114228` | String, bắt buộc, tối đa 500 ký tự |

### 2.2. Xử lý phản hồi (Response Handling)
- Google Form trả về HTTP `200 OK` (hoặc HTTP `302 Found` redirect).
- Nếu `response.statusCode < 400`: Coi là **Thành công (Success)**.
  - Hiển thị SnackBar thành công: *"✅ Gửi góp ý thành công! Cảm ơn bạn."*.
  - Làm sạch ô nhập nội dung `_contentCtrl.clear()`.
  - Giữ lại Họ tên và Email đã điền sẵn.
- Nếu `response.statusCode >= 400` hoặc xảy ra ngoại lệ mạng:
  - Bắt lỗi và hiển thị `_showErrorDialog` cho phép mở app email dự phòng (`_openEmailFallback`).

---

## 3. TIÊU CHUẨN NGHIỆM THU (ACCEPTANCE CRITERIA - AC CHECKLIST)

- [ ] **AC-01 (UI Cleanup):** Giao diện `FeedbackScreen` chỉ hiển thị 3 trường nhập liệu: "Họ và tên", "Email", "Nội dung" (đã gỡ bỏ hoàn toàn trường "Số điện thoại").
- [ ] **AC-02 (Auto-Prefill):** Khi mở màn hình, nếu `AppProvider.student` có dữ liệu, trường Họ và tên và Email tự động được điền sẵn.
- [ ] **AC-03 (Field Validation):**
  - Họ và tên: Không được để trống.
  - Email: Không được để trống, phải đúng định dạng email (`^[\w.-]+@[\w-]+\.\w+$`).
  - Nội dung: Không được để trống, giới hạn 500 ký tự.
- [ ] **AC-04 (Headless Submission):** Khi bấm "Gửi góp ý", app thực hiện gửi dữ liệu `entry.1036072439`, `entry.336370746`, `entry.2114228` bằng `http.post` dạng `application/x-www-form-urlencoded` đến Google Form `formResponse`.
- [ ] **AC-05 (Fallback Update):** Hàm `_openEmailFallback` tạo chuỗi mailto không còn chứa trường Số điện thoại.
- [ ] **AC-06 (Automated Tests):** Chạy `flutter test` đảm bảo 100% test cases trong dự án đều PASS.
