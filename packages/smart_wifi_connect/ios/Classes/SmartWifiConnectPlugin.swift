import Flutter
import UIKit
import NetworkExtension

public class SmartWifiConnectPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "smart_wifi_connect", binaryMessenger: registrar.messenger())
        let instance = SmartWifiConnectPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "connect":
            handleConnect(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func handleConnect(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let ssid = args["ssid"] as? String, !ssid.isEmpty else {
            result([
                "success": false,
                "status": "invalidArguments",
                "message": "SSID is required"
            ] as [String: Any])
            return
        }

        let password = args["password"] as? String ?? ""
        let joinOnce = args["joinOnce"] as? Bool ?? false

        let configuration: NEHotspotConfiguration
        if password.isEmpty {
            configuration = NEHotspotConfiguration(ssid: ssid)
        } else {
            configuration = NEHotspotConfiguration(ssid: ssid, passphrase: password, isWEP: false)
        }

        configuration.joinOnce = joinOnce

        NEHotspotConfigurationManager.shared.apply(configuration) { error in
            if let error = error as NSError? {
                let nsError = error as NSError
                if nsError.domain == NEHotspotConfigurationErrorDomain {
                    switch nsError.code {
                    case NEHotspotConfigurationError.userDenied.rawValue:
                        result([
                            "success": false,
                            "status": "userCancelled",
                            "message": "User denied the Wi-Fi configuration",
                            "platformCode": "userDenied"
                        ] as [String: Any])
                    case NEHotspotConfigurationError.alreadyAssociated.rawValue:
                        result([
                            "success": true,
                            "status": "connected",
                            "message": "Already connected to \(ssid)",
                            "platformCode": "alreadyAssociated"
                        ] as [String: Any])
                    case NEHotspotConfigurationError.applicationIsNotInForeground.rawValue:
                        result([
                            "success": false,
                            "status": "failed",
                            "message": "App must be in foreground to configure Wi-Fi",
                            "platformCode": "applicationIsNotInForeground"
                        ] as [String: Any])
                    case NEHotspotConfigurationError.invalid.rawValue:
                        result([
                            "success": false,
                            "status": "invalidArguments",
                            "message": "Invalid Wi-Fi configuration",
                            "platformCode": "invalid"
                        ] as [String: Any])
                    default:
                        result([
                            "success": false,
                            "status": "failed",
                            "message": error.localizedDescription,
                            "platformCode": String(nsError.code)
                        ] as [String: Any])
                    }
                } else {
                    result([
                        "success": false,
                        "status": "failed",
                        "message": error.localizedDescription,
                        "platformCode": nsError.domain
                    ] as [String: Any])
                }
            } else {
                result([
                    "success": true,
                    "status": "connected",
                    "message": "Connected to \(ssid)"
                ] as [String: Any])
            }
        }
    }
}
