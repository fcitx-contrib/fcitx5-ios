import Fcitx
import FcitxIpc
import SwiftUtil
import UIKit

func syncDocumentsToAppGroup() {
  guard appGroupAvailable else { return }
  for directory in ["data", "config"] {
    let source = documents.appendingPathComponent(directory)
    guard FileManager.default.fileExists(atPath: source.path) else { continue }
    if !sync(source, appGroup.appendingPathComponent(directory)) {
      FCITX_ERROR("Failed to sync Documents/\(directory) to App Group")
    }
  }
}

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
    logPaths()
    // Import files before fcitx scans input methods and reads its configuration.
    syncDocumentsToAppGroup()
    initProfile()
    Task.detached {
      do { _ = try clipboardStore.entries() } catch {
        FCITX_ERROR("Failed to initialize clipboard: \(error)")
      }
    }
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
