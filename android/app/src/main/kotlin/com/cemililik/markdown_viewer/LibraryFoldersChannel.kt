package com.cemililik.markdown_viewer

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
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
            "path" to displayName,
            "bookmark" to treeUri.toString(),
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
        DocumentFile.fromTreeUri(context, Uri.parse(subPath))
            ?: run {
              result.error("BOOKMARK_STALE", "could not resolve sub tree uri", null)
              return
            }
      }
      val entries = mutableListOf<Map<String, Any>>()
      for (child in target.listFiles()) {
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
    try {
      val rootUri = Uri.parse(bookmark)
      val root = DocumentFile.fromTreeUri(context, rootUri)
      if (root == null) {
        result.error("BOOKMARK_STALE", "could not resolve tree uri", null)
        return
      }
      val out = mutableListOf<Map<String, Any>>()
      walk(root, out)
      out.sortBy { (it["name"] as String).lowercase() }
      result.success(out)
    } catch (error: Exception) {
      result.error("LIST_FAILED", error.localizedMessage, null)
    }
  }

  private fun walk(dir: DocumentFile, out: MutableList<Map<String, Any>>) {
    for (child in dir.listFiles()) {
      val name = child.name ?: continue
      if (name.startsWith(".")) continue
      if (child.isDirectory) {
        walk(child, out)
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
  }

  // MARK: - File bytes

  private fun readFileBytes(bookmark: String, path: String, result: MethodChannel.Result) {
    val context = applicationContext
    if (context == null) {
      result.error("NO_CONTEXT", "no application context attached", null)
      return
    }
    try {
      val uri = Uri.parse(path)
      val bytes = context.contentResolver.openInputStream(uri)?.use { input ->
        val buffer = ByteArrayOutputStream()
        input.copyTo(buffer)
        buffer.toByteArray()
      }
      if (bytes == null) {
        result.error("READ_FAILED", "could not open input stream", null)
        return
      }
      result.success(bytes)
    } catch (error: SecurityException) {
      result.error("ACCESS_DENIED", error.localizedMessage, null)
    } catch (error: Exception) {
      result.error("READ_FAILED", error.localizedMessage, null)
    }
  }
}

