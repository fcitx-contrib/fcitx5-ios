import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?
  static var contentView: ContentView?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    if let windowScene = scene as? UIWindowScene {
      let window = UIWindow(windowScene: windowScene)
      SceneDelegate.contentView = ContentView()
      window.rootViewController = UIHostingController(rootView: SceneDelegate.contentView)
      self.window = window
      window.makeKeyAndVisible()
    }
  }

  // When app is already running, this function is called on open from URL.
  // Thus we don't use it any more.
  // func scene(_ scene: UIScene, openURLContexts urlContexts: Set<UIOpenURLContext>) {
  //   guard let url = urlContexts.first?.url else { return }
  //   SceneDelegate.contentView?.handleURL(url)
  // }
}
