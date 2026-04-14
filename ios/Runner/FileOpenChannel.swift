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
    /// Each source URL maps to a unique cache filename: the basename is
    /// prefixed with a short (8-char) hex hash of `url.path` so two files
    /// with the same basename from different directories never collide
    /// (e.g. `/docs/README.md` and `/notes/README.md` both named
    /// `README.md` map to distinct `<hash>_README.md` entries).
    ///
    /// For non-scoped URLs (e.g. AirDrop inbox paths that are already
    /// inside the app sandbox) the copy is still attempted; if it fails
    /// the original path is returned as-is because the file is still
    /// accessible without a security scope. When the URL **is** security-
    /// scoped and the copy fails, the failure is reported as an error
    /// string to Dart rather than handing over the now-inaccessible path.
    func deliver(url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

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
            // Prefix the basename with a short hash of the source path so
            // two files with the same name from different directories do not
            // overwrite each other in the shared cache directory.
            let hash = String(format: "%08x", url.path.hashValue & 0xFFFFFFFF)
            let uniqueName = "\(hash)_\(url.lastPathComponent)"
            let dest = cacheDir.appendingPathComponent(uniqueName)
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: url, to: dest)
            emit(dest.path)
        } catch {
            if scoped {
                // The security scope will be released by the defer before
                // Dart can read the file, so url.path is inaccessible.
                // Report the failure instead of handing over a dead path.
                emit(FlutterError(
                    code: "FILE_OPEN_ERROR",
                    message: "Failed to copy security-scoped file: \(error.localizedDescription)",
                    details: url.lastPathComponent
                ))
            } else {
                // Non-scoped URLs (e.g. app-sandbox paths from AirDrop inbox)
                // are already accessible without a scope — fall back to the
                // original path.
                emit(url.path)
            }
        }
    }

    private func emit(_ value: Any) {
        if let sink = eventSink {
            sink(value)
        } else {
            if let path = value as? String {
                pendingPaths.append(path)
            }
            // Errors cannot be buffered (no FlutterError queue); they are
            // dropped when the stream is not yet listening. This matches the
            // behaviour of the previous single-slot implementation where a
            // scoped-copy failure during cold-start was also silently lost.
        }
    }
}
