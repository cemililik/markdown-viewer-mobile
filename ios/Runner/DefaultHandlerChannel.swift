import Flutter
import UIKit

/// iOS implementation of the `com.cemililik.markdown_viewer/default_handler`
/// method channel.
///
/// iOS does not expose a public API for an app to claim the default
/// role for a file type like `.md`. The default is resolved by the
/// system at share-sheet / "Open In" time based on `LSHandlerRank`
/// and the UTI registration in `Info.plist`. This channel therefore
/// always answers `false` for `openDefaultHandlerSettings` — callers
/// are expected to hide the CTA on iOS and rely on the educational
/// copy in the onboarding flow instead.
///
/// Kept as a registered channel (rather than omitted on iOS) so the
/// Dart side can call `invokeMethod` without platform-gating the call
/// site — the `false` return lets the UI collapse the action.
final class DefaultHandlerChannel: NSObject {

    static let channelName = "com.cemililik.markdown_viewer/default_handler"

    static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: messenger
        )
        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "openDefaultHandlerSettings":
                result(false)
            case "isDefault":
                // iOS has no public API to answer "am I the default
                // handler for .md?", and the default resolution is
                // opaque to the app (`LSHandlerRank` ordering). A
                // future Dart-side query needs a deterministic answer
                // so the UI can hide its "Set as default" affordance
                // without platform-gating the call site. Always
                // answer `false` — the onboarding copy already
                // explains why the option is absent on iOS.
                // Reference: code-review CR-20260419-035.
                result(false)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
}
