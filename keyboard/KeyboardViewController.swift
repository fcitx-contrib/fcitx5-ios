import Fcitx
import OSLog
import UIKit

let logger = Logger(subsystem: "org.fcitx.Fcitx5", category: "FcitxLog")

class KeyboardViewController: UIInputViewController {

  @IBOutlet var nextKeyboardButton: UIButton!

  let keys: [[String]] = [
    ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
    ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
    ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
    ["z", "x", "c", "v", "b", "n", "m"],
    [" "],
  ]

  @objc private func keyPressed(_ sender: UIButton) {
    guard let title = sender.currentTitle else { return }
    if !processKey(title) {
      textDocumentProxy.insertText(title)
    }
  }

  private func createButton(title: String) -> UIButton {
    let button = UIButton(type: .system)
    button.setTitle(title, for: .normal)
    button.titleLabel?.font = UIFont.systemFont(ofSize: 24)
    button.backgroundColor = UIColor.gray.withAlphaComponent(0.2)
    button.layer.cornerRadius = 8
    button.addTarget(self, action: #selector(keyPressed(_:)), for: .touchUpInside)
    return button
  }

  private func setupKeyboardLayout() {
    // Create a vertical stack view for rows
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.distribution = .fillEqually
    stackView.alignment = .fill
    stackView.spacing = 5

    // Create buttons for each row and add them to the stack view
    for row in keys {
      let rowStackView = UIStackView()
      rowStackView.axis = .horizontal
      rowStackView.distribution = .fillEqually
      rowStackView.alignment = .fill
      rowStackView.spacing = 5

      for key in row {
        let button = createButton(title: key)
        rowStackView.addArrangedSubview(button)
      }
      stackView.addArrangedSubview(rowStackView)
    }

    // Add the stack view to the view controller's view
    stackView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(stackView)

    // Set up Auto Layout constraints for the stack view
    NSLayoutConstraint.activate([
      stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
      stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
      stackView.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
      stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10),
    ])
  }

  override func updateViewConstraints() {
    super.updateViewConstraints()

    // Add custom view sizing constraints here
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    startFcitx(Bundle.main.bundlePath)
    focusIn(self.textDocumentProxy)
    setupKeyboardLayout()

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

}
