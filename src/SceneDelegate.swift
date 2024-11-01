import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?
  var contentView: ContentView?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    if let windowScene = scene as? UIWindowScene {
      let window = UIWindow(windowScene: windowScene)
      contentView = ContentView()
      window.rootViewController = UIHostingController(rootView: contentView)
      self.window = window
      window.makeKeyAndVisible()
    }
  }

  func scene(_ scene: UIScene, openURLContexts urlContexts: Set<UIOpenURLContext>) {
    guard let url = urlContexts.first?.url else { return }
    contentView?.handleURL(url)
  }
}
