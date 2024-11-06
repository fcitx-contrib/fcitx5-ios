import SwiftUtil
import UIKit

public func openURL(_ urlString: String) {
  if let url = URL(string: urlString) {
    if UIApplication.shared.canOpenURL(url) {
      UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
  }
}

public func requestReload() {
  mkdirP(appGroupTmp.path)
  try? "".write(
    to: appGroupTmp.appendingPathComponent("reload"), atomically: true, encoding: .utf8)
  logger.info("Reload requested")
}
