import Fcitx
import FcitxCommon
import FcitxProtocol
import KeyboardUI
import SwiftUI
import SwiftUtil
import UIKit

private func redirectStderr() {
  let file = fopen("\(appGroup.path)/log.txt", "w")
  if let file = file {
    dup2(fileno(file), STDERR_FILENO)
    fclose(file)
  }
}

private func syncLocale() -> String {
  let localeFile = appGroupTmp.appendingPathComponent("locale")
  if let locale = try? String(contentsOf: localeFile, encoding: .utf8) {
    return locale
  }
  return getLocale()
}

class KeyboardViewController: UIInputViewController, FcitxProtocol {
  var id: UInt64!
  var hostingController: UIHostingController<VirtualKeyboardView>!
  var removedBySlide = ""

  private func updateTextIsEmpty() {
    let text =
      (textDocumentProxy.documentContextBeforeInput ?? "")
      + (textDocumentProxy.selectedText ?? "")
      + (textDocumentProxy.documentContextAfterInput ?? "")
    virtualKeyboardView.setTextIsEmpty(text.isEmpty)
  }

  override func updateViewConstraints() {
    super.updateViewConstraints()

    // Add custom view sizing constraints here
  }

  override func viewDidLoad() {
    id = UInt64(Int(bitPattern: Unmanaged.passUnretained(self).toOpaque()))
    logger.info("viewDidLoad \(self.id)")
    super.viewDidLoad()
    redirectStderr()
    initProfile()
    // TODO: (this is tested in simulator) when user changes app locale in Settings,
    // app and keyboards are killed, but only if app is started first can it sync
    // locale to keyboards. Need to find a way to update locale on viewWillAppear.
    setLocale(syncLocale())
    startFcitx(appBundlePath, "\(Bundle.main.bundlePath)/share", appGroup.path)

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
    virtualKeyboardView.setReturnKeyType(textDocumentProxy.returnKeyType)
    super.viewWillAppear(animated)
    let keyboard = Bundle.main.bundleURL.deletingPathExtension().lastPathComponent
    if removeFile(appGroupTmp.appendingPathComponent("\(keyboard).reload")) {
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
    updateTextIsEmpty()
  }

  public func keyPressed(_ key: String, _ code: String) {
    processKey(key, code)
  }

  public func forwardKey(_ key: String, _ code: String) {
    // documentContextBeforeInput could be all text or text in current line before cursor.
    // In the latter case, it will be '\n' if caret is at the beginning of a non-first line.
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
    case "ArrowLeft":
      textDocumentProxy.adjustTextPosition(byCharacterOffset: -1)
    case "ArrowRight":
      textDocumentProxy.adjustTextPosition(byCharacterOffset: 1)
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
    case "Backspace":
      textDocumentProxy.deleteBackward()
      updateTextIsEmpty()
    case "End":
      let textAfter = textDocumentProxy.documentContextAfterInput ?? ""
      textDocumentProxy.adjustTextPosition(byCharacterOffset: lengthOfFirstLine(textAfter))
    case "Enter":
      commitString("\n")  // \r doesn't work in Safari address bar.
    case "Home":
      let textBefore = textDocumentProxy.documentContextBeforeInput ?? ""
      textDocumentProxy.adjustTextPosition(byCharacterOffset: -lengthOfLastLine(textBefore))
    default:
      if !key.isEmpty {
        commitString(key)
      }
    }
  }

  public func resetInput() {
    Fcitx.resetInput()
  }

  public func commitString(_ commit: String) {
    textDocumentProxy.insertText(commit)
    updateTextIsEmpty()
  }

  public func setPreedit(_ preedit: String, _ caret: Int) {
    textDocumentProxy.setMarkedText(preedit, selectedRange: NSRange(location: caret, length: 0))
  }

  public func cut() {
    if let text = textDocumentProxy.selectedText {
      UIPasteboard.general.string = text
      textDocumentProxy.deleteBackward()
      updateTextIsEmpty()
    }
  }

  public func copy() {
    if let text = textDocumentProxy.selectedText {
      UIPasteboard.general.string = text
    }
  }

  public func paste() {
    if let text = UIPasteboard.general.string {
      commitString(text)
    }
  }

  public func globe() {
    Fcitx.toggle()
  }

  public func setCurrentInputMethod(_ inputMethod: String) {
    Fcitx.setCurrentInputMethod(inputMethod)
  }

  public func slideBackspace(_ step: Int) {
    if step == 0 {
      removedBySlide = ""
    } else if step < 0 {
      let textBefore = textDocumentProxy.documentContextBeforeInput ?? ""
      let newRemoval = String(textBefore.suffix(-step))
      removedBySlide = newRemoval + removedBySlide
      for _ in 0..<newRemoval.count {
        textDocumentProxy.deleteBackward()
      }
      updateTextIsEmpty()
    } else {
      let refillCount = min(step, removedBySlide.count)
      let index = removedBySlide.index(removedBySlide.startIndex, offsetBy: refillCount)
      let refill = String(removedBySlide[..<index])
      removedBySlide = String(removedBySlide[index...])
      commitString(refill)
    }
  }
}
