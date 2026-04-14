import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

  // Called when the app is launched by tapping a .md file while the
  // process is not running. URLs arrive in connectionOptions before
  // the Flutter stream is ready, so FileOpenChannel buffers them.
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    for context in connectionOptions.urlContexts {
      FileOpenChannel.shared.deliver(url: context.url)
    }
  }

  // Called when the app is already running and the user opens a file.
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    super.scene(scene, openURLContexts: URLContexts)
    for context in URLContexts {
      FileOpenChannel.shared.deliver(url: context.url)
    }
  }
}
