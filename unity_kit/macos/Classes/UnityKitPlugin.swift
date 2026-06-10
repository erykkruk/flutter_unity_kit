import Cocoa
import FlutterMacOS

/// macOS implementation of the unity_kit plugin.
///
/// Desktop Unity-as-a-library embedding is still a work in progress (the same
/// status as upstream Unity desktop support), so this plugin currently answers
/// the lifecycle/query method calls with safe defaults and reports that the
/// embedded player view is unavailable. The Dart API surface stays usable so
/// apps can compile and run on macOS without `MissingPluginException`.
public class UnityKitPlugin: NSObject, FlutterPlugin {
  private static let channelName = "com.unity_kit/unity_view_0"

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger
    )
    let instance = UnityKitPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "unity#isReady", "unity#isLoaded", "unity#isPaused":
      result(false)
    case "unity#postMessage",
         "unity#pausePlayer",
         "unity#resumePlayer",
         "unity#unloadPlayer",
         "unity#quitPlayer",
         "unity#dispose":
      // No-op until desktop player embedding lands.
      result(nil)
    case "unity#createPlayer":
      result(
        FlutterError(
          code: "unsupported",
          message: "Unity player embedding is not yet available on macOS.",
          details: nil
        )
      )
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
