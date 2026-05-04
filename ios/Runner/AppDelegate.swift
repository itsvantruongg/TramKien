import Flutter
import UIKit
import UserNotifications
import background_fetch

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Đăng ký background_fetch (Quan trọng cho iOS)
    BackgroundFetchPlugin.register(with: self.registrar(forPlugin: "BackgroundFetchPlugin")!)
    
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Hiển thị thông báo kể cả khi app đang mở (foreground)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .badge, .sound])
  }
}
