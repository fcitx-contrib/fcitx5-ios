import SwiftUtil
import UIKit

public func openURL(_ urlString: String) {
  if let url = URL(string: urlString) {
    if UIApplication.shared.canOpenURL(url) {
      UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
  }
}

public struct KeyboardInfo {
  public let id: String
  public let displayName: String
}

public func listKeyboards() -> [String] {
  listKeyboardInfo().map { $0.id }
}

public func listKeyboardInfo() -> [KeyboardInfo] {
  let pluginsURL = appBundleUrl.appendingPathComponent("PlugIns")
  var result = [KeyboardInfo]()
  if let items = try? FileManager.default.contentsOfDirectory(
    at: pluginsURL,
    includingPropertiesForKeys: nil,
    options: [.skipsHiddenFiles])
  {
    for item in items where item.pathExtension == "appex" {
      let id = item.deletingPathExtension().lastPathComponent
      let displayName = getKeyboardDisplayName(item)
      result.append(KeyboardInfo(id: id, displayName: displayName))
    }
  }
  return result.sorted { $0.id < $1.id }
}

public func requestReload() {
  if !appGroupAvailable {
    return
  }
  mkdirP(appGroupTmp.path)
  for keyboard in listKeyboards() {
    try? "".write(
      to: appGroupTmp.appendingPathComponent("\(keyboard).reload"), atomically: true,
      encoding: .utf8)
  }
  FCITX_INFO("Reload requested")
}
