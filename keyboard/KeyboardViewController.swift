import Fcitx
import FcitxProtocol
import KeyboardUI
import SwiftUI
import SwiftUtil
import UIKit

class KeyboardViewController: UIInputViewController, FcitxProtocol {
  var id: UInt64!
  var hostingController: UIHostingController<VirtualKeyboardView>!

  override func updateViewConstraints() {
    super.updateViewConstraints()

    // Add custom view sizing constraints here
  }

  override func viewDidLoad() {
    id = UInt64(Int(bitPattern: Unmanaged.passUnretained(self).toOpaque()))
    logger.info("viewDidLoad \(self.id)")
    super.viewDidLoad()
    initProfile()
    startFcitx(Bundle.main.bundlePath, appGroup.path)

    hostingController = UIHostingController(rootView: virtualKeyboardView)
    addChild(hostingController)

    hostingController.view.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(hostingController.view)

    NSLayoutConstraint.activate([
      hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
      hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
    ])

    hostingController.didMove(toParent: self)
  }

  override func viewWillAppear(_ animated: Bool) {
    logger.info("viewWillAppear \(self.id)")
    super.viewWillAppear(animated)
    if removeFile(appGroupTmp.appendingPathComponent("reload")) {
      logger.info("Reload accepted")
      reload()
    }
    focusIn(self)
  }

  override func viewWillDisappear(_ animated: Bool) {
    logger.info("viewWillDisappear \(self.id)")
    super.viewWillDisappear(animated)
    focusOut()
  }

  deinit {
    logger.info("deinit \(self.id)")
    hostingController.willMove(toParent: nil)
    hostingController.view.removeFromSuperview()
    hostingController.removeFromParent()
    hostingController = nil
  }

  override func viewWillLayoutSubviews() {
    logger.info("viewWillLayoutSubviews \(self.id)")
    super.viewWillLayoutSubviews()
  }

  override func textWillChange(_ textInput: UITextInput?) {
    // The app is about to change the document's contents. Perform any preparation here.
  }

  override func textDidChange(_ textInput: UITextInput?) {
    // The app has just changed the document's contents, the document context has been updated.
  }

  public func keyPressed(_ key: String) {
    if !processKey(key) {
      textDocumentProxy.insertText(key)
    }
  }

  public func commitString(_ commit: String) {
    textDocumentProxy.insertText(commit)
  }

  public func setPreedit(_ preedit: String, _ cursor: Int) {
    let proxy = textDocumentProxy as! UITextDocumentProxy
    proxy.setMarkedText(preedit, selectedRange: NSRange(location: cursor, length: 0))
  }
}
