import Flutter
import UIKit

/// Entry point for the unity_kit iOS plugin.
///
/// Registers the platform view factory so Flutter can create Unity views
/// via the `com.unity_kit/unity_view` view type.
public class SwiftUnityKitPlugin: NSObject, FlutterPlugin {

    public static func register(with registrar: any FlutterPluginRegistrar) {
        let factory = UnityKitViewFactory(registrar: registrar)
        registrar.register(
            factory,
            withId: "com.unity_kit/unity_view"
        )

        NSLog("[UnityKit] Plugin registered")
    }
}
