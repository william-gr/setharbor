import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    if let url = connectionOptions.urlContexts.first?.url { PlatformBridge.shared.receive(url) }
    if let url = connectionOptions.userActivities.first?.webpageURL { PlatformBridge.shared.receive(url) }
    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    if let url = URLContexts.first?.url { PlatformBridge.shared.receive(url) }
  }
  override func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    if let url = userActivity.webpageURL { PlatformBridge.shared.receive(url) }
  }
}
