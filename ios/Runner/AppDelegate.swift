import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Register the native library-folders channel alongside the
    // generated plugins so the picker + security-scoped bookmark
    // bridge is available from Dart on the first frame. The
    // Flutter plugin registry does not expose a binary messenger
    // directly; we have to pull one off a per-plugin
    // `FlutterPluginRegistrar` for a stable identifier.
    if let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "LibraryFoldersChannel"
    ) {
      LibraryFoldersChannel.register(with: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "FileOpenChannel"
    ) {
      FileOpenChannel.register(with: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "DefaultHandlerChannel"
    ) {
      DefaultHandlerChannel.register(with: registrar.messenger())
    }
  }
}
