# 🚀 Hướng dẫn Cài đặt & Sử dụng Trạm Kiến

Tài liệu này hướng dẫn bạn cách thiết lập môi trường, chạy ứng dụng và cài đặt bản build có sẵn lên thiết bị di động.


## 1. 📥 Cách Clone Project về máy

Vì **Trạm Kiến** đã được cấu hình đầy đủ mọi thư mục và tài nguyên, bạn chỉ cần tải mã nguồn về và bắt đầu sử dụng ngay:

```bash
# 1. Clone dự án từ GitHub
git clone https://github.com/itsvantruongg/TramKien.git

# 2. Vào thư mục dự án
cd TramKien

# 3. Cập nhật thư viện (Lệnh này sẽ tự động đồng bộ dự án với môi trường máy bạn)
flutter pub get
```

---

## 2. 🤖 Chạy và Build cho Android

Mọi cấu hình trong thư mục `android` đã được tối ưu hóa, bạn chỉ việc thực thi các lệnh sau:

### a. Chạy trong môi trường phát triển (Debug)
Kết nối điện thoại Android (đã bật Gỡ lỗi USB) hoặc trình giả lập và chạy:
```bash
flutter run
```

### b. Build file APK để cài đặt (Release)
```bash
# Tạo file APK để cài đặt trực tiếp lên điện thoại
flutter build apk --release
```
*File sau khi build sẽ nằm tại: `build/app/outputs/flutter-apk/app-release.apk`*

**Lưu ý:** Bạn cần cấu hình file `android/key.properties` và `android/local.properties` (xem chi tiết ở phần cuối) để có thể build thành công bản Release.

---

## 3. 🍎 Cài đặt file IPA lên iPhone (Sideload qua AltStore)

Tải file `.ipa` từ repo hoặc link tải về, bạn có thể cài đặt lên iPhone mà không cần App Store bằng cách sử dụng **AltStore**.

### Bước 1: Chuẩn bị trên Máy tính (Windows/Mac)
Bạn cần tải và cài đặt các công cụ sau:
1. **iTunes:** [Tải bản Win64](https://www.apple.com/itunes/download/win64) | [Tải bản Win32](https://www.apple.com/itunes/download/win32) (Lưu ý: **KHÔNG** dùng bản từ Microsoft Store).
2. **iCloud:** [Tải về tại đây](https://updates.cdn-apple.com/2020/windows/001-39935-20200911-1A70AA56-F448-11EA-8CC0-99D41950005E/iCloudSetup.exe).
3. **AltServer:** Truy cập [altstore.io](https://altstore.io/) để tải bản cài đặt cho Windows hoặc macOS.

### Bước 2: Cài đặt AltStore lên iPhone
1. Kết nối iPhone với máy tính bằng cáp.
2. Mở **AltServer** trên máy tính (nó sẽ hiện icon dưới thanh Taskbar).
3. Click chuột phải vào icon AltServer -> **Install AltStore** -> Chọn iPhone của bạn.
4. Đăng nhập Apple ID của bạn (để ký chứng chỉ ứng dụng).
5. Sau khi cài xong, trên iPhone vào: **Cài đặt** -> **Cài đặt chung** -> **Quản lý thiết bị** -> Chọn Apple ID của bạn và bấm **Tin cậy**.

### Bước 3: Cài đặt file IPA Trạm Kiến
1. Tải file `.ipa` của Trạm Kiến về iPhone (qua Safari hoặc gửi qua Telegram/Zalo).
2. Mở ứng dụng **AltStore** trên iPhone.
3. Chuyển sang tab **My Apps** -> Bấm dấu **[+]** ở góc trên trái.
4. Chọn file `.ipa` bạn vừa tải về.
5. Đợi quá trình cài đặt hoàn tất. Ứng dụng sẽ xuất hiện trên màn hình chính!

*Lưu ý: Với tài khoản miễn phí, bạn cần kết nối iPhone với máy tính cùng mạng Wifi 7 ngày một lần để AltStore tự động làm mới (Refresh) chứng chỉ.*

---

## 🛠 Cấu hình nâng cao (Chỉ dành cho Release)

Nếu bạn chỉ muốn chạy thử ứng dụng để học hỏi, bạn **CÓ THỂ BỎ QUA** phần này. Flutter sẽ tự động xử lý mọi thứ ở chế độ Debug.

Chỉ thực hiện các bước dưới đây nếu bạn muốn build file APK hoàn chỉnh:

1. **`android/local.properties`**: Chứa đường dẫn Android SDK. Thường tự sinh ra sau khi chạy lệnh `flutter run`.
2. **`android/key.properties`**: **Bắt buộc** để ký bản quyền APK. Bạn hãy tự tạo một file mới với thông tin của riêng bạn:

```properties
storePassword=mật_khẩu_của_bạn
keyPassword=mật_khẩu_của_bạn
keyAlias=upload
storeFile=upload-keystore.jks
```

---
**🎉 Chúc mừng! Bạn đã sẵn sàng khám phá Trạm Kiến.**
