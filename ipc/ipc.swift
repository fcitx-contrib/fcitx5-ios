import SwiftUtil
import UIKit

public func openURL(_ urlString: String) {
  if let url = URL(string: urlString) {
    if UIApplication.shared.canOpenURL(url) {
      UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
  }
}

public func listKeyboards() -> [String] {
  let pluginsURL = appBundleUrl.appendingPathComponent("PlugIns")
  var result = [String]()
  if let items = try? FileManager.default.contentsOfDirectory(
    at: pluginsURL,
    includingPropertiesForKeys: nil,
    options: [.skipsHiddenFiles])
  {
    for item in items where item.pathExtension == "appex" {
      result.append(item.deletingPathExtension().lastPathComponent)
    }
  }
  return result
}

public func requestReload() {
  mkdirP(appGroupTmp.path)
  for keyboard in listKeyboards() {
    try? "".write(
      to: appGroupTmp.appendingPathComponent("\(keyboard).reload"), atomically: true,
      encoding: .utf8)
  }
  logger.info("Reload requested")
}
