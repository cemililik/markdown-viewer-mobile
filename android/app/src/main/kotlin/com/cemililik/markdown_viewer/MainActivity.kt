package com.cemililik.markdown_viewer

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

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
  }
}
