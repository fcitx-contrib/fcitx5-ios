import OSLog
import SwiftUI

let logger = Logger(subsystem: "org.fcitx.Fcitx5", category: "FcitxLog")

@main
struct Fcitx5App: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  // Dummy. Actual Scene in managed by SceneDelegate. But onOpenURL is
  // always called on open from URL no matter app is running or not.
  var body: some Scene {
    WindowGroup {
      EmptyView().onOpenURL { url in
        SceneDelegate.contentView?.handleURL(url)
      }
    }
  }
}
