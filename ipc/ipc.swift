import UIKit

public func openURL(_ urlString: String) {
  if let url = URL(string: urlString) {
    if UIApplication.shared.canOpenURL(url) {
      UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
  }
}
