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
///    If the Flutter stream has not started listening yet, the paths are
///    buffered and flushed in FIFO order when `onListen` fires.
///
/// 2. **Warm-start** — `scene(_:openURLContexts:)` fires while the
///    scene is already active. By this point the stream is live so each
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

    /// FIFO queue of sandbox paths buffered while the stream is not yet
    /// listening. Flushed in order on the next `onListen` call.
    ///
    /// A queue rather than a single slot preserves every URL when the OS
    /// delivers multiple `UIOpenURLContext` objects in one callback (e.g.
    /// opening several files at once from the Files app cold-start).
    private var pendingPaths: [String] = []

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
        for path in pendingPaths {
            sink(path)
        }
        pendingPaths.removeAll()
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    // MARK: - URL delivery

    /// Called by `SceneDelegate` with each URL the OS hands to the app.
    ///
    /// Security-scoped URLs from the Files app or document providers
    /// require `startAccessingSecurityScopedResource()` before the file
    /// can be read. Because `dart:io` cannot hold the scope open across
    /// the platform bridge, we copy the file into the app's cache
    /// directory while the scope is active and hand the copy's path to
    /// Dart. The scope is released via `defer` after the copy completes.
    ///
    /// If the copy fails (e.g. for a non-scoped URL that is already
    /// accessible) we fall back to the original path so the caller still
    /// has a chance to open the file.
    func deliver(url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let path: String
        do {
            let cacheDir = try FileManager.default.url(
                for: .cachesDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appendingPathComponent("file_open", isDirectory: true)
            try FileManager.default.createDirectory(
                at: cacheDir, withIntermediateDirectories: true
            )
            let dest = cacheDir.appendingPathComponent(url.lastPathComponent)
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: url, to: dest)
            path = dest.path
        } catch {
            // Non-scoped URLs (e.g. app-sandbox paths from AirDrop inbox)
            // are already accessible — fall back to the original path.
            path = url.path
        }

        if let sink = eventSink {
            sink(path)
        } else {
            pendingPaths.append(path)
        }
    }
}
