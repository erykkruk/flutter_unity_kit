import Flutter
import UIKit

/// Entry point for the unity_kit iOS plugin.
///
/// Registers the platform view factory so Flutter can create Unity views
/// via the `com.unity_kit/unity_view` view type.
public class SwiftUnityKitPlugin: NSObject, FlutterPlugin {

    /// View-independent channel, so the environment can be checked before
    /// any Unity view exists.
    private static let environmentChannelName = "com.unity_kit/environment"
    private static let environmentMethod = "environment"

    public static func register(with registrar: any FlutterPluginRegistrar) {
        let factory = UnityKitViewFactory(registrar: registrar)
        registrar.register(
            factory,
            withId: "com.unity_kit/unity_view"
        )

        let channel = FlutterMethodChannel(
            name: environmentChannelName,
            binaryMessenger: registrar.messenger()
        )
        channel.setMethodCallHandler { call, result in
            switch call.method {
            case environmentMethod:
                result(UnityEnvironmentProbe.probe())
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        NSLog("[UnityKit] Plugin registered")
    }
}
