import SwiftUI
import SwiftUtil

@main
struct Fcitx5App: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  @Environment(\.scenePhase) private var scenePhase

  // Dummy. Actual Scene in managed by SceneDelegate. But onOpenURL is
  // always called on open from URL no matter app is running or not.
  var body: some Scene {
    WindowGroup {
      EmptyView().onOpenURL { url in
        SceneDelegate.contentView?.handleURL(url)
      }.onChange(of: scenePhase) { newPhase in
        if newPhase == .active {
          logger.info("App is active")
          sync(
            documents.appendingPathComponent("rime"), appGroupData.appendingPathComponent("rime"))
        }
      }
    }
  }
}
