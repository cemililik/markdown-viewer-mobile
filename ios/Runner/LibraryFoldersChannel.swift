import Flutter
import UIKit
import UniformTypeIdentifiers

/// Native iOS implementation of the library folder picker + enumerator.
///
/// Flutter's `file_picker` plugin returns the raw path of a folder chosen
/// through `UIDocumentPickerViewController` but does not persist the
/// security-scoped access claim that iOS attaches to that URL. The claim
/// is only valid on the original `NSURL` object, which the plugin
/// deallocates as soon as it hands the path back to Dart — so a later
/// `Directory(path).list()` from `dart:io` trips
/// `PathAccessException(Permission denied)`. The same problem applies
/// to paths resolved from iCloud Drive, external Files app locations,
/// and anywhere outside the app's own sandbox.
///
/// This channel bypasses `file_picker` for folder selection on iOS and
/// owns the full lifecycle:
///
/// 1. `pickDirectory` shows the system folder picker, starts the
///    security-scoped access on the returned URL, builds an
///    `.withSecurityScope` bookmark, stops the access, and returns
///    `{path, bookmark}` to Dart. The bookmark is persisted alongside
///    the folder entry in `LibraryFoldersStoreImpl`.
/// 2. `listDirectory` resolves a persisted bookmark back to a URL,
///    claims the scope for the duration of the listing, enumerates the
///    immediate children, releases the scope, and returns a normalized
///    `[{path, name, isDirectory}]` list.
/// 3. `listDirectoryRecursive` walks the subtree with the same
///    claim/release pattern and returns every markdown leaf as a flat
///    list. The recursive walk is done natively because each child URL
///    inherits the parent's security scope — there is no way to hand
///    those URLs back to `dart:io` and have them stay valid.
///
/// The shape of the Dart-side method channel is:
///
/// | Method                      | Arguments              | Returns                        |
/// | --------------------------- | ---------------------- | ------------------------------ |
/// | `pickDirectory`             | none                   | `{path, bookmark}` or `null`   |
/// | `listDirectory`             | `{bookmark}`           | `[{path, name, isDirectory}]`  |
/// | `listDirectoryRecursive`    | `{bookmark}`           | `[{path, name, isDirectory}]`  |
///
/// All errors are surfaced as `FlutterError` with a stable `code`
/// so the Dart side can map them to localized messages:
/// `BOOKMARK_FAILED`, `BOOKMARK_STALE`, `ACCESS_DENIED`, `LIST_FAILED`,
/// `NO_ROOT_VIEW`.
final class LibraryFoldersChannel: NSObject, UIDocumentPickerDelegate {
  static let channelName = "dev.markdownviewer/library_folders"

  /// Hard cap on the size of a single file returned through
  /// `readFileBytes`. Matches the per-file cap documented in
  /// `docs/standards/security-standards.md` §File System Rules.
  /// Loading a file larger than this fully into memory risks an OOM
  /// crash on low-end devices.
  static let maxFileBytes: Int = 10 * 1024 * 1024

  /// Registers the channel against the main Flutter messenger. Called
  /// exactly once from `AppDelegate` on launch. The singleton instance
  /// is retained by the method-call handler closure so the delegate
  /// stays alive while the document picker is modally presented.
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    let instance = LibraryFoldersChannel()
    channel.setMethodCallHandler { call, result in
      instance.handle(call, result: result)
    }
  }

  private var pendingResult: FlutterResult?
  private var pickerController: UIDocumentPickerViewController?

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "pickDirectory":
      pickDirectory(result: result)

    case "listDirectory":
      guard let args = call.arguments as? [String: Any],
            let bookmark = args["bookmark"] as? String else {
        result(FlutterError(code: "INVALID_ARGS", message: "bookmark missing", details: nil))
        return
      }
      let subPath = args["subPath"] as? String
      listImmediate(bookmark: bookmark, subPath: subPath, result: result)

    case "listDirectoryRecursive":
      guard let args = call.arguments as? [String: Any],
            let bookmark = args["bookmark"] as? String else {
        result(FlutterError(code: "INVALID_ARGS", message: "bookmark missing", details: nil))
        return
      }
      listRecursive(bookmark: bookmark, result: result)

    case "readFileBytes":
      guard let args = call.arguments as? [String: Any],
            let bookmark = args["bookmark"] as? String,
            let filePath = args["path"] as? String else {
        result(FlutterError(code: "INVALID_ARGS", message: "bookmark or path missing", details: nil))
        return
      }
      readFileBytes(bookmark: bookmark, filePath: filePath, result: result)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Picker

  private func pickDirectory(result: @escaping FlutterResult) {
    // Only one pick in flight at a time. The user can only see one
    // picker sheet anyway; refuse overlapping calls loudly so a Dart
    // bug does not leak a pending result forever.
    if pendingResult != nil {
      result(FlutterError(code: "BUSY", message: "another pick is in flight", details: nil))
      return
    }
    pendingResult = result

    let picker: UIDocumentPickerViewController
    if #available(iOS 14.0, *) {
      picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
    } else {
      picker = UIDocumentPickerViewController(documentTypes: ["public.folder"], in: .open)
    }
    picker.allowsMultipleSelection = false
    picker.delegate = self
    pickerController = picker

    guard let root = Self.topViewController() else {
      pendingResult?(FlutterError(
        code: "NO_ROOT_VIEW",
        message: "no root view controller available to present the picker",
        details: nil
      ))
      pendingResult = nil
      pickerController = nil
      return
    }
    root.present(picker, animated: true)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    defer {
      pendingResult = nil
      pickerController = nil
    }
    guard let url = urls.first, let result = pendingResult else { return }

    // `startAccessingSecurityScopedResource` must be called before
    // building the bookmark, otherwise `bookmarkData(options:
    // .withSecurityScope)` raises a `NSFileReadNoPermission` error
    // on anything outside the app's sandbox.
    let started = url.startAccessingSecurityScopedResource()
    defer { if started { url.stopAccessingSecurityScopedResource() } }

    // If the scope claim failed we must NOT attempt to build a
    // security-scoped bookmark — the call raises, but more
    // importantly a bookmark built without the scope would be
    // unresolvable with `.withSecurityScope` later, leading to a
    // silently-broken folder that only surfaces on first cold start.
    if !started {
      result(FlutterError(
        code: "BOOKMARK_FAILED",
        message: "could not claim security scope on picked folder",
        details: nil
      ))
      return
    }

    do {
      // `.withSecurityScope` is macOS-only — on iOS the URL returned
      // by UIDocumentPickerViewController is already security-scoped
      // and `bookmarkData(options: [])` preserves that scope through
      // the round trip. `startAccessingSecurityScopedResource()`
      // above is the load-bearing call; the option flag is a no-op
      // here and was removed after Xcode flagged
      // "'withSecurityScope' is unavailable in iOS".
      let bookmarkData = try url.bookmarkData(
        options: [],
        includingResourceValuesForKeys: nil,
        relativeTo: nil
      )
      result([
        "path": url.path,
        "bookmark": bookmarkData.base64EncodedString(),
      ])
    } catch {
      // `error.localizedDescription` can include the full user path
      // (security-standards §Logs says "never log full filesystem
      // paths"), so we surface the description in `details` for
      // developer diagnostics but keep the user-facing `message` to
      // a constant string.
      result(FlutterError(
        code: "BOOKMARK_FAILED",
        message: "could not build security-scoped bookmark",
        details: error.localizedDescription
      ))
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    pendingResult?(nil)
    pendingResult = nil
    pickerController = nil
  }

  // MARK: - Listing

  private func listImmediate(bookmark: String, subPath: String?, result: @escaping FlutterResult) {
    withResolvedUrl(bookmark: bookmark, result: result) { rootUrl in
      // The caller may want a sub-directory under the bookmarked
      // root. Sub-URLs inherit the parent's security scope as
      // long as the root's `startAccessingSecurityScopedResource`
      // is still active, which `withResolvedUrl` guarantees. We
      // still defence-in-depth check that the requested sub-path
      // lives inside the root so a malicious caller cannot use
      // the channel to escape the bookmark.
      let targetUrl: URL
      if let sub = subPath, !sub.isEmpty, sub != rootUrl.path {
        // `standardized` collapses `.`/`..` but does NOT resolve
        // symlinks, so a symlink inside the bookmarked tree that
        // points outside it would pass the prefix check. Compare
        // fully-resolved-to-fully-resolved so a symlink escape
        // hatch is caught before `FileManager` opens the file.
        // Reference: security-review SR-20260419-007 (M-6 widened).
        let resolved = URL(fileURLWithPath: sub).standardized.resolvingSymlinksInPath()
        let rootResolved = rootUrl.standardized.resolvingSymlinksInPath()
        let rootPath = rootResolved.path
        if resolved.path != rootPath && !resolved.path.hasPrefix(rootPath + "/") {
          throw NSError(
            domain: "LibraryFoldersChannel",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "subPath escapes bookmark root"]
          )
        }
        targetUrl = resolved
      } else {
        targetUrl = rootUrl
      }

      let contents = try FileManager.default.contentsOfDirectory(
        at: targetUrl,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
      )
      var entries: [[String: Any]] = []
      for child in contents {
        let values = try child.resourceValues(forKeys: [.isDirectoryKey])
        let isDir = values.isDirectory ?? false
        if isDir {
          entries.append([
            "path": child.path,
            "name": child.lastPathComponent,
            "isDirectory": true,
          ])
        } else {
          let lower = child.lastPathComponent.lowercased()
          if lower.hasSuffix(".md") || lower.hasSuffix(".markdown") {
            entries.append([
              "path": child.path,
              "name": child.lastPathComponent,
              "isDirectory": false,
            ])
          }
        }
      }
      return entries
    }
  }

  private func listRecursive(bookmark: String, result: @escaping FlutterResult) {
    withResolvedUrl(bookmark: bookmark, result: result) { url in
      let keys: [URLResourceKey] = [.isRegularFileKey]
      guard let enumerator = FileManager.default.enumerator(
        at: url,
        includingPropertiesForKeys: keys,
        options: [.skipsHiddenFiles]
      ) else {
        return []
      }
      var entries: [[String: Any]] = []
      while let obj = enumerator.nextObject() as? URL {
        let values = try obj.resourceValues(forKeys: [.isRegularFileKey])
        if values.isRegularFile != true { continue }
        let lower = obj.lastPathComponent.lowercased()
        if lower.hasSuffix(".md") || lower.hasSuffix(".markdown") {
          entries.append([
            "path": obj.path,
            "name": obj.lastPathComponent,
            "isDirectory": false,
          ])
        }
      }
      return entries
    }
  }

  // MARK: - File bytes

  /// Reads the contents of [filePath] (which must live under the
  /// tree bookmarked by [base64]) while the security scope on the
  /// bookmarked root is claimed. The bytes are returned as a
  /// `FlutterStandardTypedData` so the Dart side can hand them
  /// straight to a cache `File.writeAsBytes(...)` without a
  /// base64 round trip.
  ///
  /// Sub-file URLs inherit the security scope of the bookmarked
  /// root as long as the root scope stays active, mirroring the
  /// pattern used by `listImmediate` + `subPath`.
  private func readFileBytes(bookmark base64: String, filePath: String, result: @escaping FlutterResult) {
    guard let rootUrl = resolveBookmarkOrFail(
      bookmark: base64,
      errorCode: "READ_FAILED",
      result: result
    ) else { return }
    defer { rootUrl.stopAccessingSecurityScopedResource() }

    do {
      // Fully-resolve both sides (standardize + follow symlinks) so
      // a symlink inside the bookmarked tree that points outside it
      // cannot smuggle reads past the sandbox boundary. See the
      // `listImmediate` fix above.
      // Reference: security-review SR-20260419-007.
      let fileUrl = URL(fileURLWithPath: filePath).standardized.resolvingSymlinksInPath()
      let rootResolved = rootUrl.standardized.resolvingSymlinksInPath()
      let rootPath = rootResolved.path
      if fileUrl.path != rootPath && !fileUrl.path.hasPrefix(rootPath + "/") {
        result(FlutterError(
          code: "ACCESS_DENIED",
          message: "path escapes bookmark root",
          details: nil
        ))
        return
      }
      // Per-file size cap — see `docs/standards/security-standards.md`
      // §File System Rules and the 2026-04-17 security review §M-5.
      // A user accidentally dropping a large log into a bookmarked
      // folder (or a malicious actor planting a big `.md`) would
      // otherwise load the entire file into RAM and OOM the process.
      let resourceValues = try fileUrl.resourceValues(forKeys: [.fileSizeKey])
      if let size = resourceValues.fileSize, size > Self.maxFileBytes {
        result(FlutterError(
          code: "FILE_TOO_LARGE",
          message:
            "file \(size) bytes exceeds the \(Self.maxFileBytes)-byte cap",
          details: nil
        ))
        return
      }
      let bytes = try Data(contentsOf: fileUrl)
      if bytes.count > Self.maxFileBytes {
        // Defensive post-read check for filesystems that do not
        // populate `fileSizeKey` (unusual, but network mounts like
        // SMB / WebDAV / some iCloud states can omit it).
        result(FlutterError(
          code: "FILE_TOO_LARGE",
          message:
            "file \(bytes.count) bytes exceeds the \(Self.maxFileBytes)-byte cap",
          details: nil
        ))
        return
      }
      result(FlutterStandardTypedData(bytes: bytes))
    } catch {
      result(FlutterError(
        code: "READ_FAILED",
        message: error.localizedDescription,
        details: nil
      ))
    }
  }

  /// Resolves [bookmark], starts the security scope, runs [work], stops
  /// the scope, and forwards the result to [result]. Common enough to
  /// factor out since both list variants share the same resolve /
  /// claim / release / error-surface shape.
  private func withResolvedUrl(
    bookmark base64: String,
    result: @escaping FlutterResult,
    work: (URL) throws -> [[String: Any]]
  ) {
    guard let url = resolveBookmarkOrFail(
      bookmark: base64,
      errorCode: "LIST_FAILED",
      result: result
    ) else { return }
    defer { url.stopAccessingSecurityScopedResource() }

    do {
      let entries = try work(url)
      result(entries)
    } catch {
      result(FlutterError(
        code: "LIST_FAILED",
        message: error.localizedDescription,
        details: nil
      ))
    }
  }

  /// Shared bookmark-resolve path used by both `readFileBytes` and
  /// `withResolvedUrl`. On success returns a URL with the security
  /// scope already claimed — the caller **must** stop access via
  /// `defer { url.stopAccessingSecurityScopedResource() }`.
  ///
  /// ## Stale-refresh contract
  ///
  /// When the OS flags the bookmark as stale, this helper mints a
  /// fresh `.withSecurityScope` bookmark and surfaces the base64 blob
  /// in `FlutterError.details`. The Dart wrapper reads it into
  /// `NativeFolderBookmarkStaleException.refreshedBookmark` so the
  /// caller can persist and retry without re-prompting the user.
  ///
  /// On any other failure the helper sends a typed `FlutterError`
  /// (`BOOKMARK_STALE` for bad base64, `ACCESS_DENIED` for a failed
  /// scope claim, [genericErrorCode] for everything else) and returns
  /// `nil`.
  private func resolveBookmarkOrFail(
    bookmark base64: String,
    errorCode genericErrorCode: String,
    result: @escaping FlutterResult
  ) -> URL? {
    guard let data = Data(base64Encoded: base64) else {
      result(FlutterError(
        code: "BOOKMARK_STALE",
        message: "bookmark not base64",
        details: nil
      ))
      return nil
    }
    do {
      var isStale = false
      // `.withSecurityScope` is macOS-only. On iOS the default
      // resolve options preserve the scope from a bookmark originally
      // captured through UIDocumentPickerViewController.
      let url = try URL(
        resolvingBookmarkData: data,
        options: [],
        relativeTo: nil,
        bookmarkDataIsStale: &isStale
      )
      if isStale {
        let started = url.startAccessingSecurityScopedResource()
        defer { if started { url.stopAccessingSecurityScopedResource() } }
        // If we could not claim the scope we cannot mint a fresh
        // bookmark either — report the stale state so the caller can
        // prompt the user to re-pick the folder. Don't attempt
        // bookmarkData() in that branch; it would throw
        // NSFileReadNoPermission on out-of-sandbox URLs.
        if !started {
          result(FlutterError(
            code: "BOOKMARK_STALE",
            message: "bookmark is stale and could not be refreshed",
            details: nil
          ))
          return nil
        }
        let freshData = try url.bookmarkData(
          options: [],
          includingResourceValuesForKeys: nil,
          relativeTo: nil
        )
        result(FlutterError(
          code: "BOOKMARK_STALE",
          message: "bookmark was stale and has been refreshed",
          details: freshData.base64EncodedString()
        ))
        return nil
      }
      let started = url.startAccessingSecurityScopedResource()
      if !started {
        result(FlutterError(
          code: "ACCESS_DENIED",
          message: "could not claim security-scoped access on bookmark",
          details: nil
        ))
        return nil
      }
      return url
    } catch {
      result(FlutterError(
        code: genericErrorCode,
        message: error.localizedDescription,
        details: nil
      ))
      return nil
    }
  }

  // MARK: - Helpers

  /// Walks the current window hierarchy to find a presenting view
  /// controller. UIKit gives no direct "current" handle under scene-
  /// based apps, so we reach through the active scene to its key
  /// window and follow the `presentedViewController` chain until we
  /// hit a leaf that can modally present the picker.
  private static func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .filter { $0.activationState == .foregroundActive }
    let window = scenes.first?.windows.first { $0.isKeyWindow } ?? scenes.first?.windows.first
    var top = window?.rootViewController
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }
}
