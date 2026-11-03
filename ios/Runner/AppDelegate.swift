import Flutter
import UIKit
import UserNotifications
import background_fetch
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // GeneratedPluginRegistrant sẽ tự động đăng ký các plugin bao gồm BackgroundFetch
    
    if let controller = window?.rootViewController as? FlutterViewController {
      let widgetChannel = FlutterMethodChannel(name: "com.tramkien.hau/widget", binaryMessenger: controller.binaryMessenger)
      widgetChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
        switch call.method {
        case "updateWidget":
          if #available(iOS 14.0, *) {
            if let sharedDefaults = UserDefaults(suiteName: "group.vn.edu.hau.tramkien") {
              let standardDefaults = UserDefaults.standard
              let keys = [
                "flutter.widget_schedule_data",
                "flutter.widget_schedule_data_single_day",
                "flutter.widget_schedule_data_three_days",
                "flutter.widget_schedule_data_seven_days",
                "flutter.widget_schedule_data_tomorrow",
                "flutter.widget_theme_config"
              ]
              for key in keys {
                if let val = standardDefaults.object(forKey: key) {
                  sharedDefaults.set(val, forKey: key)
                  let strippedKey = key.replacingOccurrences(of: "flutter.", with: "")
                  sharedDefaults.set(val, forKey: strippedKey)
                }
              }
            }
            WidgetCenter.shared.reloadAllTimelines()
            result(true)
          } else {
            result(false)
          }
        case "getAppGroupDirectory":
          if let containerUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.vn.edu.hau.tramkien") {
            result(containerUrl.path)
          } else {
            result(nil)
          }
        default:
          result(FlutterMethodNotImplemented)
        }
      }
      let intentChannel = FlutterMethodChannel(name: "com.tramkien.hau/initial_intent", binaryMessenger: controller.binaryMessenger)
      intentChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
        switch call.method {
        case "getInitialRoute":
          result(self?.initialUrlString)
        case "clearInitialIntent":
          self?.initialUrlString = nil
          result(true)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private var initialUrlString: String? = nil

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    let urlStr = url.absoluteString
    if urlStr.starts(with: "tramkien://") {
      initialUrlString = urlStr
      if let controller = window?.rootViewController as? FlutterViewController {
        let channel = FlutterMethodChannel(name: "com.tramkien.hau/initial_intent", binaryMessenger: controller.binaryMessenger)
        channel.invokeMethod("onNewIntent", urlStr)
      }
      return true
    }
    return super.application(app, open: url, options: options)
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
