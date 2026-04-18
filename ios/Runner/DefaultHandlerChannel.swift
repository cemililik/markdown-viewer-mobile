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
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
}
