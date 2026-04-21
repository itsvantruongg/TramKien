# 🚀 Hướng dẫn Setup trên máy mới

Sau khi clone repo về, thực hiện các bước sau để có thể chạy app:

## 📋 Yêu cầu

- ✅ Flutter 3.0.0+ (chạy `flutter --version`)
- ✅ Dart 3.0.0+ (kèm theo Flutter)
- ✅ Android SDK (API 21+) hoặc Xcode (iOS 11+)
- ✅ Git

## 🔧 Setup trên máy mới

### Bước 1: Clone repo
```bash
git clone https://github.com/<your-username>/demo.git
cd demo
```

### Bước 2: Cài đặt Flutter dependencies
```bash
flutter pub get
```

### Bước 3: Cấu hình Android (bắt buộc nếu build cho Android)

#### a) Tạo file `android/local.properties`
```properties
sdk.dir=C:\Android\sdk
# Hoặc nếu dùng Linux/macOS:
# sdk.dir=/path/to/android/sdk
```

#### b) Tạo key signing (cho release build)
```bash
# Windows
cd android
keytool -genkey -v -keystore app\release-key.keystore -keyalg RSA -keysize 2048 -validity 10000 -alias demo

# Tạo file android/key.properties
echo keyAlias=demo > key.properties
echo keyPassword=<password-bạn-vừa-tạo> >> key.properties
echo storeFile=release-key.keystore >> key.properties
echo storePassword=<password-bạn-vừa-tạo> >> key.properties
```

### Bước 4: Cấu hình iOS (nếu build cho iOS)
```bash
cd ios
pod install
cd ..
```

### Bước 5: Chạy app

#### Development mode
```bash
flutter run

# Hoặc chỉ định device
flutter devices                      # Xem danh sách device
flutter run -d emulator-5554         # Chỉ định device Android
flutter run -d "iPhone 14"           # Chỉ định device iOS
```

#### Release mode
```bash
# Android
flutter build apk --release
# File output: build/app/outputs/flutter-app.apk

# iOS
flutter build ios --release
```

## ⚠️ Lưu ý quan trọng

### Credentials không được push lên GitHub
Các file sau **KHÔNG** có trong repo (đã `.gitignore`):
- ✅ `android/local.properties` - Path Android SDK
- ✅ `android/key.properties` - Key signing
- ✅ Credentials app HAU (lưu lại trong Secure Storage ở runtime)

**Bạn phải tự tạo những files này trên máy mới!**

### Environment-specific
Một số config cần điều chỉnh theo máy:
- **Android SDK path** - Khác nhau tuỳ vào đường dẫn cài Flutter
- **iOS build settings** - Nếu có Team ID, certificate

## 🔍 Troubleshooting

| Lỗi | Giải pháp |
|---|---|
| `Android SDK not found` | Kiểm tra `android/local.properties`, đảm bảo path đúng |
| `Podfile error` | Chạy `cd ios && pod install && cd ..` |
| `Build error` | Chạy `flutter clean && flutter pub get` rồi build lại |
| `Permission denied` (macOS) | `chmod +x gradlew` |

## ✅ Kiểm tra setup

```bash
# Xem tất cả dependency installed
flutter doctor -v

# Test run app
flutter run

# Nếu thành công sẽ thấy app chạy trên emulator/device
```

---

**🎉 Nếu không có lỗi, bạn đã setup thành công!**
