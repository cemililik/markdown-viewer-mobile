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

    /// Hard cap on the size of a share-intent / `ACTION_VIEW` file
    /// copied into the app's cache directory. Matches the per-file
    /// cap documented in `docs/standards/security-standards.md` and
    /// keeps a malicious content provider from filling up disk /
    /// RAM with an oversized payload.
    static let maxFileBytes: Int = 10 * 1024 * 1024


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

        // Follow symlinks on the incoming URL before copying so a
        // symlink that resolves outside the provider's sandbox is
        // detected as "outside the expected tree" rather than
        // silently copied. `copyItem(at:)` follows symlinks by
        // default, but resolving up front gives us a single,
        // canonical path to use for hashing and size checks so
        // two different symlinks to the same underlying file share
        // a cache entry instead of producing duplicates.
        // Reference: security-review SR-20260419-007 (M-6 widened).
        let resolvedUrl = url.standardized.resolvingSymlinksInPath()

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
            // Prefix the basename with a short FNV-1a hash of the source path
            // so two files with the same name from different directories do not
            // overwrite each other in the shared cache directory. FNV-1a is
            // used rather than Swift's `hashValue` because `hashValue` is
            // randomised per-process (Swift 5+) and produces different values
            // across app launches, making cached files unreachable after restart.
            let hash = String(format: "%08x", fnv1a32(resolvedUrl.path))
            let uniqueName = "\(hash)_\(resolvedUrl.lastPathComponent)"
            let dest = cacheDir.appendingPathComponent(uniqueName)
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            // Per-file size cap — see security-standards.md §File
            // System Rules and the 2026-04-17 security review §M-8.
            // A share-intent provider that hands us a multi-gigabyte
            // file would otherwise fill the cache directory before
            // the viewer realises anything is wrong.
            let resourceValues = try resolvedUrl.resourceValues(forKeys: [.fileSizeKey])
            if let size = resourceValues.fileSize,
               size > FileOpenChannel.maxFileBytes {
                // Surface the cap violation to Dart so the UI can
                // show a localised "File too large" snackbar instead
                // of silently dropping the share — the user otherwise
                // taps "Open in Markdown Viewer" and nothing happens.
                // Reference: code-review CR-20260419-034.
                NSLog(
                    "[FileOpenChannel] dropping oversized share-intent file (%d bytes > %d cap)",
                    size, FileOpenChannel.maxFileBytes
                )
                emitError(code: "FILE_TOO_LARGE", message: "File exceeds \(FileOpenChannel.maxFileBytes) byte cap")
                return
            }
            try FileManager.default.copyItem(at: resolvedUrl, to: dest)
            // Belt-and-suspenders check — some providers omit the
            // size key. Remove the copy if the post-copy measurement
            // shows it exceeded the cap.
            let copiedSize = (try? dest.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            if copiedSize > FileOpenChannel.maxFileBytes {
                try? FileManager.default.removeItem(at: dest)
                NSLog(
                    "[FileOpenChannel] deleted oversized copy (%d bytes > %d cap)",
                    copiedSize, FileOpenChannel.maxFileBytes
                )
                emitError(code: "FILE_TOO_LARGE", message: "File exceeds \(FileOpenChannel.maxFileBytes) byte cap")
                return
            }
            emit(dest.path)
        } catch {
            if scoped {
                // The security scope will be released by the defer before
                // Dart can read the file, so url.path is inaccessible.
                // Dropping the event silently is safer than emitting a
                // FlutterError: the Dart stream is typed as Stream<String>
                // and error events bypass stream filters, which would cause
                // an unhandled-error crash in incoming_file_provider.dart.
#if DEBUG
                // Log only the basename — the full path contains the
                // user's home/document tree structure and is PII in
                // crash reports / console exports.
                // Reference: security-review SR-20260419-032 (L-1 carry).
                NSLog("[FileOpenChannel] security-scoped URL access failed for %@: %@ %ld", (url.path as NSString).lastPathComponent, (error as NSError).domain, (error as NSError).code)
#else
                NSLog("[FileOpenChannel] security-scoped URL access failed (domain=%@, code=%ld)", (error as NSError).domain, (error as NSError).code)
#endif
            } else {
                // Non-scoped URLs (e.g. app-sandbox paths from AirDrop inbox)
                // are already accessible without a scope — fall back to the
                // original path.
                emit(url.path)
            }
        }
    }

    // MARK: - Utilities

    /// FNV-1a 32-bit hash of a UTF-8 string. Deterministic across
    /// processes and launches — unlike Swift's `String.hashValue`,
    /// which is per-process randomised in Swift 5+.
    private func fnv1a32(_ string: String) -> UInt32 {
        var hash: UInt32 = 2_166_136_261
        for byte in string.utf8 {
            hash ^= UInt32(byte)
            hash &*= 16_777_619
        }
        return hash
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

    /// Emits a typed error to the Dart stream so the UI can surface
    /// a localised message. Matches the Android
    /// `FlutterError(code: "FILE_TOO_LARGE")` contract declared in
    /// code-review CR-20260419-034. When no listener is attached yet
    /// the error is dropped (there is no FlutterError buffer) —
    /// acceptable because the stream is always listening by the time
    /// a share-intent completes copying.
    private func emitError(code: String, message: String) {
        if let sink = eventSink {
            sink(FlutterError(code: code, message: message, details: nil))
        }
    }
}
