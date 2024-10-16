import Fcitx
import FcitxProtocol
import OSLog
import UIKit

let logger = Logger(subsystem: "org.fcitx.Fcitx5", category: "FcitxLog")

class KeyboardViewController: UIInputViewController, FcitxProtocol {

  @IBOutlet var nextKeyboardButton: UIButton!

  var mainStackView: UIStackView!

  override func updateViewConstraints() {
    super.updateViewConstraints()

    // Add custom view sizing constraints here
  }

  override func viewDidLoad() {
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

    startFcitx(Bundle.main.bundlePath)

    // Perform custom UI setup here
    self.nextKeyboardButton = UIButton(type: .system)

    self.nextKeyboardButton.setTitle(
      NSLocalizedString("Next Keyboard", comment: "Title for 'Next Keyboard' button"), for: [])
    self.nextKeyboardButton.sizeToFit()
    self.nextKeyboardButton.translatesAutoresizingMaskIntoConstraints = false

    self.nextKeyboardButton.addTarget(
      self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)

    self.view.addSubview(self.nextKeyboardButton)

    self.nextKeyboardButton.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
    self.nextKeyboardButton.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    focusIn(self)
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    focusOut()
  }

  override func viewWillLayoutSubviews() {
    self.nextKeyboardButton.isHidden = !self.needsInputModeSwitchKey
    super.viewWillLayoutSubviews()
  }

  override func textWillChange(_ textInput: UITextInput?) {
    // The app is about to change the document's contents. Perform any preparation here.
  }

  override func textDidChange(_ textInput: UITextInput?) {
    // The app has just changed the document's contents, the document context has been updated.

    var textColor: UIColor
    let proxy = self.textDocumentProxy
    if proxy.keyboardAppearance == UIKeyboardAppearance.dark {
      textColor = UIColor.white
    } else {
      textColor = UIColor.black
    }
    self.nextKeyboardButton.setTitleColor(textColor, for: [])
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
}
