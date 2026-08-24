import Foundation
import UIKit

/// Reports which Unity runtime an iOS build actually carries.
///
/// The Android half of this check also inspects native library page
/// alignment; on iOS there is no equivalent requirement, so the alignment
/// fields are reported as unknown rather than faked.
enum UnityEnvironmentProbe {

    private static let unityFrameworkClass = "UnityFramework"

    /// Builds the report handed to Dart.
    static func probe() -> [String: Any] {
        let frameworkClass: AnyClass? = NSClassFromString(unityFrameworkClass)

        return [
            "runtime": frameworkClass == nil ? "absent" : "unityFramework",
            "playerClassName": frameworkClass == nil ? NSNull() : unityFrameworkClass,
            // No 16 KB page size requirement applies to iOS binaries.
            "pageAlignment": "unknown",
            "devicePageSizeBytes": Int(getpagesize()),
            "abi": currentArchitecture(),
            "platformVersion": UIDevice.current.systemVersion,
            "libraries": [] as [Any],
        ]
    }

    /// Architecture the process is running as, reported in the same shape
    /// as the Android ABI string.
    private static func currentArchitecture() -> String {
        #if targetEnvironment(simulator)
            #if arch(arm64)
                return "arm64-simulator"
            #else
                return "x86_64-simulator"
            #endif
        #elseif arch(arm64)
            return "arm64"
        #elseif arch(x86_64)
            return "x86_64"
        #else
            return "unknown"
        #endif
    }
}
