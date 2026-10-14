import UIKit
import Flutter
// import GoogleMaps
import flutter_local_notifications

// TODO(uiscene): not migrated to the UIScene lifecycle. Flutter's migrator skips
// a customized AppDelegate, so this app stays on the legacy UIApplication
// lifecycle and builds fine on 3.47.2 (warning only). Apple enforces UIScene for
// apps built with the iOS 27 SDK - migrate before that Xcode upgrade.
// https://docs.flutter.dev/release/breaking-changes/uiscenedelegate
@main
@objc class AppDelegate: FlutterAppDelegate {
  static let methodChannelName: String = "com.ensembleui.host.platform"
  var methodChannel: FlutterMethodChannel?
    
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    methodChannel =  FlutterMethodChannel(name: AppDelegate.methodChannelName, binaryMessenger: controller.binaryMessenger)
//     GMSServices.provideAPIKey("AIzaSyD8vwvoaEPEgYemp1EkIETetJMvyS4Ptqk")
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
                GeneratedPluginRegistrant.register(with: registry) }

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
    
  override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    // Calling flutter method "urlOpened" from iOS
    methodChannel?.invokeMethod("urlOpened", arguments: url.absoluteString)
    return true
  }
}
