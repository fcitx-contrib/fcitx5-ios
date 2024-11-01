import OSLog
import SwiftUI

let logger = Logger(subsystem: "org.fcitx.Fcitx5", category: "FcitxLog")

@main
struct Fcitx5App: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  // Dummy. Actual Scene in managed by SceneDelegate.
  var body: some Scene {
    WindowGroup {
      EmptyView()
    }
  }
}
