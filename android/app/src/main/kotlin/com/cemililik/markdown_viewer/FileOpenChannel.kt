package com.cemililik.markdown_viewer

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
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

        /**
         * Hard cap on the size of a share-intent / `ACTION_VIEW`
         * payload copied into the app's cache directory. Matches
         * the per-file cap in `docs/standards/security-standards.md`
         * §File System Rules — keeps a malicious content provider
         * from filling disk / RAM with an oversized payload.
         */
        private const val MAX_FILE_BYTES: Long = 10L * 1024L * 1024L
    }

    private var channel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    private var applicationContext: Context? = null
    private var activityBinding: ActivityPluginBinding? = null

    /**
     * FIFO queue of paths buffered while the stream is not yet listening.
     *
     * A queue (rather than the previous single slot) preserves every URL
     * when two intents arrive in rapid succession before the Flutter
     * stream starts listening — e.g. two AirDrops during cold-start, or
     * a share that fires before `onAttachedToEngine` + `onListen`
     * complete. The previous single-slot implementation silently
     * overwrote the earlier path.
     *
     * Reference: code-review CR-20260419-008.
     */
    private val pendingPaths: ArrayDeque<String> = ArrayDeque()

    // MARK: - FlutterPlugin

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        channel = EventChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel?.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                eventSink = sink
                // Drain every buffered path in arrival order so a
                // cold-start multi-share delivers each file exactly once.
                while (pendingPaths.isNotEmpty()) {
                    sink.success(pendingPaths.removeFirst())
                }
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
        pendingPaths.clear()
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
            // Use the typed, class-loader-aware overload on API 33+
            // (Tiramisu). The single-arg form is deprecated there and
            // will silently return null on a future SDK version, which
            // would break ACTION_SEND warm-start delivery.
            Intent.ACTION_SEND ->
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(Intent.EXTRA_STREAM)
                }
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
            // Pre-check with the filesystem: file:// URIs always have
            // a length, so a file over the cap can be rejected before
            // any bytes are copied. Content URIs hit the cumulative
            // streaming guard in `copyCappedOrDelete` below.
            if (canonical.length() > MAX_FILE_BYTES) {
                deliverError("FILE_TOO_LARGE", "File exceeds $MAX_FILE_BYTES byte cap")
                return null
            }
            return try {
                val safeName = sanitizeFileName(canonical.name)
                val cacheDir = File(context.cacheDir, "file_open").also { it.mkdirs() }
                val dest = File(cacheDir, safeName)
                canonical.inputStream().use { input ->
                    if (!copyCappedOrDelete(input, dest)) {
                    deliverError(
                        "FILE_TOO_LARGE",
                        "File exceeds $MAX_FILE_BYTES byte cap",
                    )
                    return null
                }
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
                if (!copyCappedOrDelete(input, dest)) {
                    deliverError(
                        "FILE_TOO_LARGE",
                        "File exceeds $MAX_FILE_BYTES byte cap",
                    )
                    return null
                }
            }
            dest.absolutePath
        } catch (_: Exception) {
            null
        }
    }

    /**
     * Streams [input] into [dest] and aborts when the cumulative
     * byte count exceeds [MAX_FILE_BYTES]. Deletes any partial file
     * on abort so a cancelled copy does not leave a truncated
     * payload that the viewer would then try to open.
     *
     * Returns `true` when the copy completed within the cap,
     * `false` when it was aborted.
     */
    private fun copyCappedOrDelete(
        input: java.io.InputStream,
        dest: File,
    ): Boolean {
        val chunk = ByteArray(8 * 1024)
        var total = 0L
        FileOutputStream(dest).use { output ->
            while (true) {
                val n = input.read(chunk)
                if (n < 0) break
                total += n
                if (total > MAX_FILE_BYTES) {
                    output.flush()
                    dest.delete()
                    return false
                }
                output.write(chunk, 0, n)
            }
        }
        return true
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
            // Strip NUL and other C0 control characters. The OS-level
            // `File` constructor already rejects NUL on POSIX, but the
            // project's sanitize contract is "produce a name that never
            // yields a cache filename with surprises" — so scrub every
            // C0 byte regardless of current OS behaviour.
            // Reference: security-review SR-20260419-033 (L-5 carry).
            .replace(Regex("[\\x00-\\x1f]"), "_")
            .trim()
        if (stripped.isBlank()) return "opened_file.md"
        return stripped
    }

    private fun deliver(path: String) {
        val sink = eventSink
        if (sink != null) {
            sink.success(path)
        } else {
            pendingPaths.addLast(path)
        }
    }

    /**
     * Emits a typed error to the Dart stream so the UI can surface
     * a localised message (e.g. "File too large"). Dropped when no
     * listener is attached yet, matching the iOS side — `FlutterError`
     * does not survive the `ArrayDeque` buffer used for paths.
     *
     * Reference: code-review CR-20260419-034.
     */
    private fun deliverError(code: String, message: String) {
        eventSink?.error(code, message, null)
    }
}
