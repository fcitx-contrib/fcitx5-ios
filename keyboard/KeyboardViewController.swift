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
    virtualKeyboardView.setDisplayMode(.initial)
    focusIn(self)
  }

  override func viewWillDisappear(_ animated: Bool) {
    logger.info("viewWillDisappear \(self.id)")
    super.viewWillDisappear(animated)
    focusOut(self)
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

  public func keyPressed(_ key: String, _ code: String) {
    // documentContextBeforeInput could be all text or text in current line before cursor.
    // In the latter case, it will be '\n' if cursor is at the beginning of a non-first line.
    if !processKey(key, code) {
      switch code {
      case "ArrowDown":
        let offset = lengthOfLastLine(textDocumentProxy.documentContextBeforeInput ?? "")
        let step = lengthOfFirstLine(textDocumentProxy.documentContextAfterInput ?? "")
        textDocumentProxy.adjustTextPosition(byCharacterOffset: step)
        DispatchQueue.main.async {
          // Move to the start of next line if exists.
          self.textDocumentProxy.adjustTextPosition(byCharacterOffset: 1)
          // Must have a delay, otherwise nextLineLength is always 0.
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let nextLineLength = lengthOfFirstLine(
              self.textDocumentProxy.documentContextAfterInput ?? "")
            self.textDocumentProxy.adjustTextPosition(
              byCharacterOffset: min(offset, nextLineLength))
          }
        }
        break
      case "ArrowLeft":
        textDocumentProxy.adjustTextPosition(byCharacterOffset: -1)
        break
      case "ArrowRight":
        textDocumentProxy.adjustTextPosition(byCharacterOffset: 1)
        break
      case "ArrowUp":
        let offset = lengthOfLastLine(textDocumentProxy.documentContextBeforeInput ?? "")
        textDocumentProxy.adjustTextPosition(byCharacterOffset: -offset)
        DispatchQueue.main.async {
          // Move to the end of previous line if exists.
          self.textDocumentProxy.adjustTextPosition(byCharacterOffset: -1)
          // Must have a delay, otherwise previousLineLength may always be 0.
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let previousLineLength = lengthOfLastLine(
              self.textDocumentProxy.documentContextBeforeInput ?? "")
            if previousLineLength > offset {
              self.textDocumentProxy.adjustTextPosition(
                byCharacterOffset: -(previousLineLength - offset))
            }
          }
        }
        break
      case "Backspace":
        textDocumentProxy.deleteBackward()
        break
      case "End":
        let textAfter = textDocumentProxy.documentContextAfterInput ?? ""
        textDocumentProxy.adjustTextPosition(byCharacterOffset: lengthOfFirstLine(textAfter))
        break
      case "Home":
        let textBefore = textDocumentProxy.documentContextBeforeInput ?? ""
        textDocumentProxy.adjustTextPosition(byCharacterOffset: -lengthOfLastLine(textBefore))
        break
      default:
        if !key.isEmpty {
          textDocumentProxy.insertText(key)
        }
      }
    }
  }

  public func commitString(_ commit: String) {
    textDocumentProxy.insertText(commit)
  }

  public func setPreedit(_ preedit: String, _ cursor: Int) {
    let proxy = textDocumentProxy as! UITextDocumentProxy
    proxy.setMarkedText(preedit, selectedRange: NSRange(location: cursor, length: 0))
  }

  public func cut() {
    if let text = textDocumentProxy.selectedText {
      UIPasteboard.general.string = text
      textDocumentProxy.deleteBackward()
    }
  }

  public func copy() {
    if let text = textDocumentProxy.selectedText {
      UIPasteboard.general.string = text
    }
  }

  public func paste() {
    if let text = UIPasteboard.general.string {
      textDocumentProxy.insertText(text)
    }
  }

  public func globe() {
    Fcitx.toggle()
  }
}
