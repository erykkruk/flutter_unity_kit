import Flutter
import UIKit

/// Factory that creates `UnityKitViewController` instances for each
/// platform view requested by Flutter.
///
/// Registered with the view type identifier `com.unity_kit/unity_view`.
final class UnityKitViewFactory: NSObject, FlutterPlatformViewFactory {

    // MARK: - Properties

    private let registrar: FlutterPluginRegistrar

    // MARK: - Init

    init(registrar: FlutterPluginRegistrar) {
        self.registrar = registrar
        super.init()
    }

    // MARK: - FlutterPlatformViewFactory

    func createArgsCodec() -> (any FlutterMessageCodec & NSObjectProtocol) {
        return FlutterStandardMessageCodec.sharedInstance()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> any FlutterPlatformView {
        return UnityKitViewController(
            frame: frame,
            viewId: viewId,
            messenger: registrar.messenger(),
            args: args
        )
    }
}
