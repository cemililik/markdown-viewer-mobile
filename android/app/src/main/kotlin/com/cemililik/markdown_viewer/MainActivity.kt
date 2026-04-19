package com.cemililik.markdown_viewer

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    // Register the native library-folders channel alongside the
    // Flutter-generated plugins so the Storage Access Framework
    // bridge is available from Dart on the first frame. The
    // channel is a real `FlutterPlugin` so we can hand it to the
    // engine's plugin registry, which also wires the `ActivityAware`
    // hooks the picker needs.
    flutterEngine.plugins.add(LibraryFoldersChannel())
    flutterEngine.plugins.add(FileOpenChannel())
    flutterEngine.plugins.add(DefaultHandlerChannel())

    // Screen-capture guard — the PAT entry field can toggle
    // `FLAG_SECURE` on the activity window so the OS blocks
    // screenshots / screen recordings / AirPlay mirroring while the
    // field is visible. Toggled from Dart on section expand/collapse
    // rather than always-on because FLAG_SECURE also blocks the
    // user's own screenshots of markdown content, which is a UX
    // regression for the rest of the app.
    //
    // Reference: security-review SR-20260419-022.
    MethodChannel(
      flutterEngine.dartExecutor.binaryMessenger,
      "com.cemililik.markdown_viewer/screen_capture_guard",
    ).setMethodCallHandler { call, result ->
      when (call.method) {
        "setSecure" -> {
          val enabled = (call.arguments as? Boolean) ?: false
          runOnUiThread {
            if (enabled) {
              window.setFlags(
                WindowManager.LayoutParams.FLAG_SECURE,
                WindowManager.LayoutParams.FLAG_SECURE,
              )
            } else {
              window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            }
          }
          result.success(null)
        }
        else -> result.notImplemented()
      }
    }
  }
}
