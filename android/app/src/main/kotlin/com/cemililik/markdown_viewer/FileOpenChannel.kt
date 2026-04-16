package com.cemililik.markdown_viewer

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.File
import java.io.FileOutputStream

/**
 * Delivers incoming file paths to Dart via an [EventChannel] so that
 * the viewer can open a markdown document shared or tapped from another
 * app (Files, email client, GitHub Mobile, etc.).
 *
 * Two entry points exist on Android:
 *
 * 1. **Cold-start / re-launch** — the OS fires `MainActivity.onCreate`
 *    with an `ACTION_VIEW` or `ACTION_SEND` intent. The activity calls
 *    [handleIntent] early in its lifecycle. If the Flutter stream is not
 *    yet listening, the path is buffered in [pendingPath] and flushed
 *    when the [EventChannel.StreamHandler.onListen] fires.
 *
 * 2. **Warm-start** — the app is already running and another app sends
 *    an intent. The OS calls `onNewIntent` on `MainActivity`, which
 *    forwards to [handleIntent]. By this point the stream is live so
 *    the path is emitted immediately.
 *
 * ### Content URI handling
 *
 * Modern Android delivers `content://` URIs rather than `file://` for
 * shared content. `dart:io` cannot read content URIs, so we copy the
 * stream into the app's cache directory and hand Dart the absolute
 * filesystem path. The cache file is overwritten on each open (same
 * name = no unbounded growth).
 *
 * ### Channel name
 *
 * `com.cemililik.markdown_viewer/file_open` — matches the Dart
 * [EventChannel] in `incoming_file_provider.dart`.
 */
class FileOpenChannel :
    FlutterPlugin,
    ActivityAware,
    PluginRegistry.NewIntentListener {

    companion object {
        const val CHANNEL_NAME = "com.cemililik.markdown_viewer/file_open"
    }

    private var channel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    private var applicationContext: Context? = null
    private var activityBinding: ActivityPluginBinding? = null

    /** Buffered path when the stream is not yet listening. */
    private var pendingPath: String? = null

    // MARK: - FlutterPlugin

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        channel = EventChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel?.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                eventSink = sink
                pendingPath?.let { sink.success(it) }
                pendingPath = null
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setStreamHandler(null)
        channel = null
        applicationContext = null
        eventSink = null
        pendingPath = null
    }

    // MARK: - ActivityAware

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addOnNewIntentListener(this)
        // Deliver the launch intent in case the plugin attached after
        // the activity was already created (hot restart scenario).
        handleIntent(binding.activity.intent)
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addOnNewIntentListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding?.removeOnNewIntentListener(this)
        activityBinding = null
    }

    override fun onDetachedFromActivity() {
        activityBinding?.removeOnNewIntentListener(this)
        activityBinding = null
    }

    // MARK: - NewIntentListener

    override fun onNewIntent(intent: Intent): Boolean {
        return handleIntent(intent)
    }

    // MARK: - Intent handling

    /**
     * Resolves [intent] to a filesystem path and either emits it on the
     * live [eventSink] or stores it in [pendingPath] for delivery on
     * the next [EventChannel.StreamHandler.onListen].
     *
     * Returns `true` when the intent was consumed (ACTION_VIEW / SEND).
     */
    private fun handleIntent(intent: Intent): Boolean {
        val action = intent.action ?: return false
        if (action != Intent.ACTION_VIEW && action != Intent.ACTION_SEND) return false

        val uri: Uri? = when (action) {
            Intent.ACTION_SEND -> intent.getParcelableExtra(Intent.EXTRA_STREAM)
            else -> intent.data
        }
        if (uri == null) return false

        val path = resolveUri(uri) ?: return false
        deliver(path)
        return true
    }

    /**
     * Converts [uri] to an absolute filesystem path readable by Dart.
     *
     * Both `file://` and `content://` URIs are copied into
     * `cacheDir/file_open/<sanitised-name>` so Dart always receives a
     * path inside the app sandbox. `file://` URIs are additionally
     * validated to be inside the app's cache or files directory.
     */
    private fun resolveUri(uri: Uri): String? {
        val context = applicationContext ?: return null

        // file:// URIs: validate the path is inside the app sandbox,
        // then copy to cache just like content:// URIs to avoid
        // granting Dart access to arbitrary filesystem locations.
        if (uri.scheme == "file") {
            val decoded = uri.path ?: return null
            val canonical = File(decoded).canonicalFile
            val cacheRoot = context.cacheDir.canonicalFile
            val filesRoot = context.filesDir.canonicalFile
            if (!canonical.path.startsWith(cacheRoot.path + File.separator) &&
                !canonical.path.startsWith(filesRoot.path + File.separator) &&
                canonical != cacheRoot && canonical != filesRoot
            ) {
                return null
            }
            return try {
                val safeName = sanitizeFileName(canonical.name)
                val cacheDir = File(context.cacheDir, "file_open").also { it.mkdirs() }
                val dest = File(cacheDir, safeName)
                canonical.inputStream().use { input ->
                    FileOutputStream(dest).use { output -> input.copyTo(output) }
                }
                dest.absolutePath
            } catch (_: Exception) {
                null
            }
        }

        // content:// or any other provider URI — copy to cache.
        return try {
            val rawName = uri.lastPathSegment
                ?.substringAfterLast('/')
                ?.ifBlank { null }
                ?: "opened_file.md"
            val fileName = sanitizeFileName(rawName)
            val cacheDir = File(context.cacheDir, "file_open").also { it.mkdirs() }
            val dest = File(cacheDir, fileName)
            context.contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(dest).use { output -> input.copyTo(output) }
            }
            dest.absolutePath
        } catch (_: Exception) {
            null
        }
    }

    /**
     * Strips path separators and `..` sequences so the name cannot
     * escape the target directory when used with [File] constructor.
     */
    private fun sanitizeFileName(name: String): String {
        val stripped = name
            .replace("..", "")
            .replace('/', '_')
            .replace('\\', '_')
            .trim()
        if (stripped.isBlank()) return "opened_file.md"
        return stripped
    }

    private fun deliver(path: String) {
        val sink = eventSink
        if (sink != null) {
            sink.success(path)
        } else {
            pendingPath = path
        }
    }
}
