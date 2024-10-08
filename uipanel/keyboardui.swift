import FcitxProtocol
import OSLog
import UIKit

let logger = Logger(subsystem: "org.fcitx.Fcitx5", category: "FcitxLog")

private func setupMainLayout(_ client: FcitxProtocol) {
  let mainStackView = client.getView()

  let keyboardView = Keyboard(client)
  keyboardView.translatesAutoresizingMaskIntoConstraints = false
  mainStackView.addArrangedSubview(keyboardView)
}

public func showKeyboardAsync(_ clientPtr: UnsafeMutableRawPointer) {
  let client: AnyObject = Unmanaged.fromOpaque(clientPtr).takeUnretainedValue()
  guard let client = client as? FcitxProtocol else {
    return
  }
  DispatchQueue.main.async {
    setupMainLayout(client)
  }
}
