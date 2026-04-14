import Flutter
import UIKit

/// Delivers incoming file URLs to Dart via an [FlutterEventChannel] so
/// that the viewer can open a markdown document tapped from the Files
/// app, a mail attachment, AirDrop, or any "Open In" source.
///
/// Two entry points exist on iOS when the app uses a `SceneDelegate`:
///
/// 1. **Cold-start** — `scene(_:willConnectTo:options:)` fires with
///    `UIOpenURLContext` objects in `connectionOptions`. `SceneDelegate`
///    calls `FileOpenChannel.shared.deliver(url:)` during this callback.
///    If the Flutter stream has not started listening yet, the URL is
///    buffered and flushed when `onListen` fires.
///
/// 2. **Warm-start** — `scene(_:openURLContexts:)` fires while the
///    scene is already active. By this point the stream is live so the
///    path is emitted immediately.
///
/// The singleton is registered with the Flutter binary messenger in
/// `AppDelegate.didInitializeImplicitFlutterEngine(_:)`.
///
/// ### Channel name
///
/// `com.cemililik.markdown_viewer/file_open` — matches the Dart
/// `EventChannel` in `incoming_file_provider.dart` and the Android
/// `FileOpenChannel`.
final class FileOpenChannel: NSObject, FlutterStreamHandler {

    static let shared = FileOpenChannel()
    static let channelName = "com.cemililik.markdown_viewer/file_open"

    private var eventSink: FlutterEventSink?

    /// Buffered path when the stream is not yet listening. Flushed
    /// on the next `onListen` call.
    private var pendingPath: String?

    private override init() { super.init() }

    // MARK: - Registration

    /// Registers this handler on [messenger]. Call once from
    /// `AppDelegate.didInitializeImplicitFlutterEngine(_:)`.
    static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterEventChannel(name: channelName, binaryMessenger: messenger)
        channel.setStreamHandler(shared)
    }

    // MARK: - FlutterStreamHandler

    func onListen(withArguments arguments: Any?, eventSink sink: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = sink
        if let path = pendingPath {
            sink(path)
            pendingPath = nil
        }
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    // MARK: - URL delivery

    /// Called by `SceneDelegate` with each URL the OS hands to the app.
    ///
    /// Security-scoped URLs from the Files app require
    /// `startAccessingSecurityScopedResource()` before the path is
    /// readable. We start access, copy the path, then stop — the actual
    /// file reading happens on the Dart side via normal `dart:io`, which
    /// only needs the path string.
    func deliver(url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        let path = url.path
        if scoped { url.stopAccessingSecurityScopedResource() }

        if let sink = eventSink {
            sink(path)
        } else {
            pendingPath = path
        }
    }
}
