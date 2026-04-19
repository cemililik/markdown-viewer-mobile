package com.cemililik.markdown_viewer

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.ByteArrayOutputStream

/**
 * Android implementation of the library folder picker + enumerator
 * that mirrors the Swift [LibraryFoldersChannel] on iOS.
 *
 * On Android 11+ the Storage Access Framework enforces `content://`
 * tree URIs for any folder outside the app's own sandbox: a folder
 * picked via `ACTION_OPEN_DOCUMENT_TREE` returns a URI (not a
 * filesystem path) that only `ContentResolver` / `DocumentFile` can
 * read. `dart:io`'s `File` and `Directory` have no knowledge of
 * content URIs and fail on the first access. The fix is to route
 * every access to a picked folder through this channel, which:
 *
 * 1. Calls `takePersistableUriPermission` so the granted tree URI
 *    survives the next cold start.
 * 2. Walks the tree through `DocumentFile.fromTreeUri(...)`, which
 *    enumerates children without needing a filesystem path.
 * 3. When a markdown file is tapped in the folder body, streams
 *    its bytes back through `readFileBytes`. The Dart side writes
 *    those bytes into the app's own cache directory and hands the
 *    resulting filesystem path to the existing viewer code, so
 *    `DocumentRepositoryImpl` keeps using plain `dart:io` without
 *    any SAF awareness.
 *
 * The channel name, method set, and argument shapes match the iOS
 * Swift channel exactly so the Dart wrapper in
 * `NativeLibraryFoldersChannel` can dispatch without branching.
 *
 * Cross-platform contract:
 *
 * | Method                   | Arguments                      | Returns                        |
 * | ------------------------ | ------------------------------ | ------------------------------ |
 * | `pickDirectory`          | none                           | `{path, bookmark}` or `null`   |
 * | `listDirectory`          | `{bookmark, subPath?}`         | `[{path, name, isDirectory}]`  |
 * | `listDirectoryRecursive` | `{bookmark}`                   | `[{path, name, isDirectory}]`  |
 * | `readFileBytes`          | `{bookmark, path}`             | `Uint8List`                    |
 *
 * On Android:
 *
 * - `path` in every payload is a stringified content URI, not a
 *   filesystem path. The drawer / folder body never try to hand
 *   that string to `dart:io`; it is always routed back through
 *   this channel.
 * - `bookmark` is the root tree URI as a string. The same string
 *   is stored in [LibraryFoldersStoreImpl] so the entry survives
 *   a cold start.
 * - `subPath` is also a content URI string, pointing at a
 *   sub-directory inside the bookmarked tree. Drilling into the
 *   tree uses child URIs returned by prior `listDirectory` calls.
 *
 * Error codes match the iOS channel (`BOOKMARK_STALE`, `ACCESS_DENIED`,
 * `LIST_FAILED`, `READ_FAILED`, `INVALID_ARGS`) so the Dart error
 * mapper does not need a platform branch.
 */
class LibraryFoldersChannel :
    FlutterPlugin,
    ActivityAware,
    MethodChannel.MethodCallHandler,
    PluginRegistry.ActivityResultListener {

  companion object {
    private const val CHANNEL_NAME = "dev.markdownviewer/library_folders"
    private const val REQUEST_CODE_PICK_DIRECTORY = 0x4D4456 // "MDV"

    /** Maximum directory nesting depth accepted by `walk`. A SAF
     * tree deeper than this is almost certainly either a mount
     * loop or an adversarial payload designed to stall the
     * platform thread. Reference: code-review CR-20260419-033.
     */
    private const val MAX_WALK_DEPTH = 10

    /** Maximum markdown entries accepted by `walk`. Matches the
     * content-search file cap so downstream consumers never see a
     * bigger list than they budget for. */
    private const val MAX_WALK_ENTRIES = 2000

    /**
     * Hard cap on the size of a single file returned through
     * `readFileBytes`. Matches the per-file cap documented in
     * `docs/standards/security-standards.md` §File System Rules —
     * loading a larger file fully into memory risks an OOM on
     * low-end Android devices.
     */
    private const val MAX_FILE_BYTES: Long = 10L * 1024L * 1024L
  }

  private var channel: MethodChannel? = null
  private var applicationContext: Context? = null
  private var activityBinding: ActivityPluginBinding? = null
  private var pendingResult: MethodChannel.Result? = null

  // MARK: - FlutterPlugin

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    applicationContext = binding.applicationContext
    channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
    channel?.setMethodCallHandler(this)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel?.setMethodCallHandler(null)
    channel = null
    applicationContext = null
  }

  // MARK: - ActivityAware

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activityBinding = binding
    binding.addActivityResultListener(this)
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activityBinding = binding
    binding.addActivityResultListener(this)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activityBinding?.removeActivityResultListener(this)
    activityBinding = null
  }

  override fun onDetachedFromActivity() {
    activityBinding?.removeActivityResultListener(this)
    activityBinding = null
  }

  // MARK: - Method dispatch

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "pickDirectory" -> pickDirectory(result)

      "listDirectory" -> {
        val bookmark = call.argument<String>("bookmark")
        val subPath = call.argument<String>("subPath")
        if (bookmark == null) {
          result.error("INVALID_ARGS", "bookmark missing", null)
          return
        }
        listDirectory(bookmark, subPath, result)
      }

      "listDirectoryRecursive" -> {
        val bookmark = call.argument<String>("bookmark")
        if (bookmark == null) {
          result.error("INVALID_ARGS", "bookmark missing", null)
          return
        }
        listDirectoryRecursive(bookmark, result)
      }

      "readFileBytes" -> {
        val bookmark = call.argument<String>("bookmark")
        val path = call.argument<String>("path")
        if (bookmark == null || path == null) {
          result.error("INVALID_ARGS", "bookmark or path missing", null)
          return
        }
        readFileBytes(bookmark, path, result)
      }

      else -> result.notImplemented()
    }
  }

  // MARK: - Picker

  private fun pickDirectory(result: MethodChannel.Result) {
    val activity = activityBinding?.activity
    if (activity == null) {
      result.error("NO_ACTIVITY", "no attached activity to present the picker", null)
      return
    }
    if (pendingResult != null) {
      result.error("BUSY", "another pick is in flight", null)
      return
    }
    pendingResult = result
    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
      addFlags(
          Intent.FLAG_GRANT_READ_URI_PERMISSION or
              Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
      )
    }
    activity.startActivityForResult(intent, REQUEST_CODE_PICK_DIRECTORY)
  }

  override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
    if (requestCode != REQUEST_CODE_PICK_DIRECTORY) return false
    val result = pendingResult ?: return true
    pendingResult = null

    if (resultCode != Activity.RESULT_OK || data?.data == null) {
      result.success(null)
      return true
    }

    val treeUri = data.data!!
    val context = applicationContext
    if (context == null) {
      result.error("NO_CONTEXT", "no application context attached", null)
      return true
    }

    try {
      // Persist the read permission so the URI survives a cold
      // start. Without this, the next process launch would see a
      // `SecurityException` on the first `ContentResolver` access.
      context.contentResolver.takePersistableUriPermission(
          treeUri,
          Intent.FLAG_GRANT_READ_URI_PERMISSION
      )
    } catch (error: SecurityException) {
      result.error(
          "PERSIST_FAILED",
          "could not take persistable uri permission: ${error.localizedMessage}",
          null
      )
      return true
    }

    val root = DocumentFile.fromTreeUri(context, treeUri)
    val displayName = root?.name ?: treeUri.lastPathSegment ?: treeUri.toString()
    result.success(
        mapOf(
            "path" to treeUri.toString(),
            "bookmark" to treeUri.toString(),
            "displayName" to displayName,
        )
    )
    return true
  }

  // MARK: - Listing

  private fun listDirectory(bookmark: String, subPath: String?, result: MethodChannel.Result) {
    val context = applicationContext
    if (context == null) {
      result.error("NO_CONTEXT", "no application context attached", null)
      return
    }
    try {
      val rootUri = Uri.parse(bookmark)
      val root = DocumentFile.fromTreeUri(context, rootUri)
      if (root == null) {
        result.error("BOOKMARK_STALE", "could not resolve tree uri", null)
        return
      }
      val target: DocumentFile = if (subPath == null || subPath == bookmark) {
        root
      } else {
        val subUri = Uri.parse(subPath)
        if (!isDescendantUri(rootUri, subUri)) {
          result.error("ACCESS_DENIED", "subPath is not a descendant of the root tree", null)
          return
        }
        DocumentFile.fromTreeUri(context, subUri)
            ?: run {
              result.error("BOOKMARK_STALE", "could not resolve sub tree uri", null)
              return
            }
      }
      val entries = mutableListOf<Map<String, Any>>()
      for (child in target.listFiles() ?: emptyArray()) {
        val name = child.name ?: continue
        if (name.startsWith(".")) continue
        if (child.isDirectory) {
          entries += mapOf(
              "path" to child.uri.toString(),
              "name" to name,
              "isDirectory" to true,
          )
        } else {
          val lower = name.lowercase()
          if (lower.endsWith(".md") || lower.endsWith(".markdown")) {
            entries += mapOf(
                "path" to child.uri.toString(),
                "name" to name,
                "isDirectory" to false,
            )
          }
        }
      }
      // Sort: subdirs first, then files, both case-insensitive alpha.
      entries.sortWith(
          compareByDescending<Map<String, Any>> { it["isDirectory"] as Boolean }
              .thenBy { (it["name"] as String).lowercase() }
      )
      result.success(entries)
    } catch (error: Exception) {
      result.error("LIST_FAILED", error.localizedMessage, null)
    }
  }

  private fun listDirectoryRecursive(bookmark: String, result: MethodChannel.Result) {
    val context = applicationContext
    if (context == null) {
      result.error("NO_CONTEXT", "no application context attached", null)
      return
    }
    // SAF `DocumentFile.listFiles()` is an IPC round-trip per call,
    // and a pathologically nested tree would otherwise block the
    // platform thread long enough to trip the ANR watchdog. Run on
    // a background executor so the main thread stays live even for
    // deep walks; the caller awaits via the MethodChannel future.
    //
    // Depth and entry caps match the content-search file budget so
    // a malicious or accidentally-large folder cannot stall the
    // UI — `LIST_FAILED` is returned on cap hit so the Dart layer
    // can surface a "folder too large" message instead of silently
    // truncating.
    // Reference: code-review CR-20260419-033 + performance PR-20260419-028.
    Thread {
      try {
        val rootUri = Uri.parse(bookmark)
        val root = DocumentFile.fromTreeUri(context, rootUri)
        if (root == null) {
          runOnMain {
            result.error("BOOKMARK_STALE", "could not resolve tree uri", null)
          }
          return@Thread
        }
        val out = mutableListOf<Map<String, Any>>()
        val hitCap = walk(root, out, depth = 0)
        if (hitCap) {
          runOnMain {
            result.error(
                "LIST_FAILED",
                "folder exceeds depth / entry cap",
                null,
            )
          }
          return@Thread
        }
        out.sortBy { (it["name"] as String).lowercase() }
        runOnMain { result.success(out) }
      } catch (error: Exception) {
        runOnMain {
          result.error("LIST_FAILED", error.localizedMessage, null)
        }
      }
    }.start()
  }

  /**
   * Walks [dir] recursively, appending every markdown file to [out].
   * Returns `true` when traversal was aborted because the depth or
   * entry cap was reached; the caller surfaces `LIST_FAILED` in that
   * case rather than silently truncating the list.
   */
  private fun walk(
      dir: DocumentFile,
      out: MutableList<Map<String, Any>>,
      depth: Int,
  ): Boolean {
    if (depth > MAX_WALK_DEPTH) return true
    for (child in dir.listFiles() ?: emptyArray()) {
      if (out.size >= MAX_WALK_ENTRIES) return true
      val name = child.name ?: continue
      if (name.startsWith(".")) continue
      if (child.isDirectory) {
        if (walk(child, out, depth + 1)) return true
      } else {
        val lower = name.lowercase()
        if (lower.endsWith(".md") || lower.endsWith(".markdown")) {
          out += mapOf(
              "path" to child.uri.toString(),
              "name" to name,
              "isDirectory" to false,
          )
        }
      }
    }
    return false
  }

  /** Marshals [block] back onto the main thread so
   * `MethodChannel.Result` returns land on the channel's expected
   * dispatcher.
   *
   * Uses a `Handler` bound to the main `Looper` rather than the
   * activity's `runOnUiThread` because the activity reference can
   * be `null` by the time the background walker completes (plugin
   * detached, app moved to background, configuration change in
   * flight). Executing `block()` synchronously on the caller's
   * thread in that case would call `MethodChannel.Result` from a
   * worker `Thread` and crash with `CalledFromWrongThreadException`.
   */
  private val mainHandler = Handler(Looper.getMainLooper())

  private fun runOnMain(block: () -> Unit) {
    if (Looper.myLooper() == Looper.getMainLooper()) {
      block()
    } else {
      mainHandler.post(block)
    }
  }

  /**
   * Returns `true` when [childUri] sits under the tree rooted at [rootUri].
   * SAF tree URIs share a common prefix so a string-prefix check is sufficient.
   */
  private fun isDescendantUri(rootUri: Uri, childUri: Uri): Boolean {
    val rootStr = rootUri.toString()
    val childStr = childUri.toString()
    // SAF producers may emit either uppercase or lowercase percent-encoding
    // for the path separator; accept both without lowercasing the whole URI
    // (which would clobber case-sensitive authority/scheme components).
    return childStr == rootStr ||
        childStr.startsWith("$rootStr/") ||
        childStr.startsWith("$rootStr%2F") ||
        childStr.startsWith("$rootStr%2f")
  }

  // MARK: - File bytes

  private fun readFileBytes(bookmark: String, path: String, result: MethodChannel.Result) {
    val context = applicationContext
    if (context == null) {
      result.error("NO_CONTEXT", "no application context attached", null)
      return
    }
    try {
      val rootUri = Uri.parse(bookmark)
      val uri = Uri.parse(path)
      if (!isDescendantUri(rootUri, uri)) {
        result.error("ACCESS_DENIED", "path is not a descendant of the root tree", null)
        return
      }
      // Size-cap pre-check — ask the content provider for
      // OpenableColumns.SIZE first so a huge file is rejected
      // before any bytes are pulled into memory. SAF providers
      // that do not populate SIZE fall through to the streaming
      // guard below. See security-standards.md §File System Rules
      // and the 2026-04-17 security review §M-7.
      val advertisedSize = queryFileSize(context, uri)
      if (advertisedSize != null && advertisedSize > MAX_FILE_BYTES) {
        result.error(
            "FILE_TOO_LARGE",
            "file $advertisedSize bytes exceeds the $MAX_FILE_BYTES-byte cap",
            null,
        )
        return
      }
      val bytes = context.contentResolver.openInputStream(uri)?.use { input ->
        val buffer = ByteArrayOutputStream()
        val chunk = ByteArray(8 * 1024)
        var total = 0L
        while (true) {
          val n = input.read(chunk)
          if (n < 0) break
          total += n
          if (total > MAX_FILE_BYTES) {
            throw FileTooLargeException(total)
          }
          buffer.write(chunk, 0, n)
        }
        buffer.toByteArray()
      }
      if (bytes == null) {
        result.error("READ_FAILED", "could not open input stream", null)
        return
      }
      result.success(bytes)
    } catch (error: FileTooLargeException) {
      result.error(
          "FILE_TOO_LARGE",
          "file ${error.bytesRead} bytes exceeds the $MAX_FILE_BYTES-byte cap",
          null,
      )
    } catch (error: SecurityException) {
      result.error("ACCESS_DENIED", error.localizedMessage, null)
    } catch (error: Exception) {
      result.error("READ_FAILED", error.localizedMessage, null)
    }
  }

  /** Thrown when a streaming read exceeds the per-file cap. */
  private class FileTooLargeException(val bytesRead: Long) :
      RuntimeException("file exceeds $MAX_FILE_BYTES-byte cap at $bytesRead bytes")

  /**
   * Reads `OpenableColumns.SIZE` from the content resolver for a
   * SAF URI. Returns null when the provider does not populate the
   * column — callers must fall back to a streaming cumulative-bytes
   * guard in that case.
   */
  private fun queryFileSize(context: Context, uri: Uri): Long? {
    return context.contentResolver.query(
        uri,
        arrayOf(OpenableColumns.SIZE),
        null,
        null,
        null,
    )?.use { cursor ->
      if (cursor.moveToFirst()) {
        val index = cursor.getColumnIndex(OpenableColumns.SIZE)
        if (index >= 0 && !cursor.isNull(index)) cursor.getLong(index) else null
      } else {
        null
      }
    }
  }
}

