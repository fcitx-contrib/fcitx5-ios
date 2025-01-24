import Fcitx
import FcitxProtocol
import SwiftUtil
import UIKit

class KeyboardViewController: UIInputViewController, FcitxProtocol {
  var mainStackView: UIStackView!
  var id: UInt64!

  override func updateViewConstraints() {
    super.updateViewConstraints()

    // Add custom view sizing constraints here
  }

  override func viewDidLoad() {
    id = UInt64(Int(bitPattern: Unmanaged.passUnretained(self).toOpaque()))
    logger.info("viewDidLoad \(self.id)")
    super.viewDidLoad()

    mainStackView = UIStackView()
    mainStackView.axis = .vertical
    mainStackView.alignment = .fill

    mainStackView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(mainStackView)

    // fill parent with no padding
    NSLayoutConstraint.activate([
      mainStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0),
      mainStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0),
      mainStackView.topAnchor.constraint(equalTo: view.topAnchor, constant: 0),
      mainStackView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0),
    ])

    initProfile()
    startFcitx(Bundle.main.bundlePath, appGroup.path)
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

  public func getView() -> UIStackView {
    return mainStackView
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
