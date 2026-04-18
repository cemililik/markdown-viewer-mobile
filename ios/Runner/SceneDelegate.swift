import Flutter
import UIKit

/// Scene delegate that splits incoming URL contexts into two tracks:
///
/// - **File URLs** (the markdown documents this app was written to
///   open) — handed to `FileOpenChannel` and deliberately NOT
///   forwarded to `super`. Forwarding a `file://` URL to
///   `FlutterSceneDelegate` causes the engine to push the URL as a
///   route, and `go_router` then shows a "Page Not Found" error
///   because it has no route matching
///   `file:///private/var/.../*.md` (observed on iPhone AirDrop →
///   Open In → MarkdownViewer).
///
/// - **Non-file URLs** (custom schemes, universal links — none used
///   today but the branch stays future-proof) — forwarded to super
///   unchanged so the engine can process them normally.
class SceneDelegate: FlutterSceneDelegate {

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    // Scene lifecycle must reach super regardless. The URL handling
    // below is a side-effect only — `FileOpenChannel` buffers the
    // paths until the Dart EventChannel starts listening.
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    for context in connectionOptions.urlContexts where context.url.isFileURL {
      FileOpenChannel.shared.deliver(url: context.url)
    }
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    var nonFileContexts: Set<UIOpenURLContext> = []
    for context in URLContexts {
      if context.url.isFileURL {
        FileOpenChannel.shared.deliver(url: context.url)
      } else {
        nonFileContexts.insert(context)
      }
    }
    if !nonFileContexts.isEmpty {
      super.scene(scene, openURLContexts: nonFileContexts)
    }
  }
}
