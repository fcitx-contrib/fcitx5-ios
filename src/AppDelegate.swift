import Fcitx
import FcitxIpc
import SwiftUtil
import UIKit

let documentsSync = DocumentsSync(
  documents: documents, destination: appGroup,
  stateURL: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    .appendingPathComponent("documents-sync.json"))

@MainActor
let configurationSync = ConfigurationSync(onReload: { requestReload() })

@MainActor
func synchronizeForegroundConfiguration() {
  guard appGroupAvailable else { return }
  let operation = configurationSync.start {
    // Finish edits queued before the UI was paused, then keep edits paused through reload.
    waitForFcitx()
    let changed = try documentsSync.synchronize()
    if changed {
      reload()
      waitForFcitx()
    }
    return changed
  }
  Task {
    do { _ = try await operation.value } catch {
      FCITX_ERROR("Failed to synchronize foreground configuration: \(error)")
    }
  }
}

func syncDocumentsToAppGroup() -> Bool {
  guard appGroupAvailable else { return false }
  do {
    return try documentsSync.synchronize()
  } catch {
    FCITX_ERROR("Failed to sync Documents to App Group: \(error)")
    return false
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
    let appGroupChanged = syncDocumentsToAppGroup()
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
    // The main instance just loaded these files; an existing keyboard may still be stale.
    if appGroupChanged {
      requestReload()
    }
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
