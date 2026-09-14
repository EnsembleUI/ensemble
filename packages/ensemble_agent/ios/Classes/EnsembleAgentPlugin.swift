import Flutter
import UIKit

/// iOS plugin shell for Apple Foundation Models.
///
/// Capability detection and generate/stream are implemented behind availability
/// checks so the plugin compiles on older SDKs and returns standardized
/// unavailable reasons when Foundation Models are not present.
@objc public class SwiftEnsembleAgentPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?
  private var activeRequestId: String?
  private var cancelledRequestIds = Set<String>()

  public static func register(with registrar: FlutterPluginRegistrar) {
    let messenger = registrar.messenger()
    let methodChannel = FlutterMethodChannel(name: "ensemble_agent", binaryMessenger: messenger)
    let eventChannel = FlutterEventChannel(name: "ensemble_agent/events", binaryMessenger: messenger)
    let instance = SwiftEnsembleAgentPlugin()
    registrar.addMethodCallDelegate(instance, channel: methodChannel)
    eventChannel.setStreamHandler(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getCapabilities":
      result(capabilitiesMap())
    case "generate":
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "invalid_args", message: "Expected map arguments.", details: nil))
        return
      }
      generate(args: args, result: result)
    case "stream":
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "invalid_args", message: "Expected map arguments.", details: nil))
        return
      }
      stream(args: args, result: result)
    case "cancel":
      if let args = call.arguments as? [String: Any],
         let requestId = args["requestId"] as? String {
        cancelledRequestIds.insert(requestId)
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  private func capabilitiesMap() -> [String: Any] {
    // Foundation Models require a newer OS/SDK. Until linked, report unavailable.
    // When available, Apple supports native tool calling (Path A).
    if #available(iOS 18.0, *) {
      // Placeholder: real FoundationModels SystemLanguageModel checks go here.
      return [
        "available": false,
        "provider": "apple_foundation_models",
        "textGeneration": false,
        "streaming": false,
        "toolCalling": false,
        "nativeToolCalling": true,
        "structuredOutput": false,
        "imageInput": false,
        "unavailableReason": "modelUnavailable",
      ]
    }
    return [
      "available": false,
      "provider": "apple_foundation_models",
      "nativeToolCalling": false,
      "unavailableReason": "unsupportedOS",
    ]
  }

  private func generate(args: [String: Any], result: @escaping FlutterResult) {
    let caps = capabilitiesMap()
    if caps["available"] as? Bool != true {
      result(FlutterError(
        code: "unavailable",
        message: "Apple Foundation Models are not available on this device.",
        details: caps
      ))
      return
    }
    result(FlutterError(
      code: "unsupported_capability",
      message: "Native generate is not enabled in this build.",
      details: nil
    ))
  }

  private func stream(args: [String: Any], result: @escaping FlutterResult) {
    let requestId = args["requestId"] as? String ?? UUID().uuidString
    activeRequestId = requestId
    let caps = capabilitiesMap()
    if caps["available"] as? Bool != true {
      eventSink?([
        "type": "failed",
        "message": "Apple Foundation Models are not available on this device.",
        "code": "unavailable",
      ])
      result(nil)
      return
    }
    result(FlutterError(
      code: "unsupported_capability",
      message: "Native stream is not enabled in this build.",
      details: nil
    ))
  }
}
