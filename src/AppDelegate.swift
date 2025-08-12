import Fcitx
import FcitxCommon
import FcitxIpc
import SwiftUtil
import UIKit

private func syncLocale(_ locale: String) {
  mkdirP(appGroupTmp.path)
  try? locale.write(
    to: appGroupTmp.appendingPathComponent("locale"), atomically: true, encoding: .utf8)
}

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    initProfile()
    let locale = getLocale()
    setLocale(locale)
    syncLocale(locale)
    startFcitx(
      appBundlePath,
      listKeyboards().map { keyboard in "\(appBundlePath)/PlugIns/\(keyboard).appex/share" }.joined(
        separator: ":"), appGroup.path)
    return true
  }

  func application(
    _ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
    options: UIScene.ConnectionOptions
  ) -> UISceneConfiguration {
    return UISceneConfiguration(
      name: "Default Configuration", sessionRole: connectingSceneSession.role)
  }

  func application(
    _ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>
  ) {
  }
}
