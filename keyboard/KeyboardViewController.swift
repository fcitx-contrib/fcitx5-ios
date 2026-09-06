import Fcitx
import FcitxProtocol
import KeyboardUI
import SwiftFrontend
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

@MainActor
class KeyboardViewController: UIInputViewController, FcitxProtocol {
  private struct DocumentState: Equatable {
    // Changing focus between TextFields on the same app screen may not call keyboard's viewWillAppear.
    // iOS issues a new documentIdentifier even when focus returns to a previously focused TextField.
    let identifier: String
    let contextBeforeInput: String?
    let selectedText: String?
    let contextAfterInput: String?
  }

  private struct SurroundingText {
    let text: String
    let cursor: UInt32
    let anchor: UInt32
  }

  private struct SurroundingTextPosition {
    let utf16Offset: Int
    let characterOffset: Int
  }

  private static let documentPollingInterval: TimeInterval = 0.2
  nonisolated(unsafe) private static var liveControllerCount = 0

  nonisolated(unsafe) var id: UInt64 = 0
  nonisolated(unsafe) private var countedAsLive = false
  var hostingController: UIHostingController<VirtualKeyboardView>!
  var removedBySlide = ""
  // Reject queued C++ callbacks after the controller stops accepting input. Its program and
  // documentIdentifier may remain unchanged between viewWillDisappear and deinit. This also stays
  // false for the config-sync document, where Fcitx must not modify the proxy.
  private var acceptsFcitxCommands = false
  private var documentState: DocumentState?
  private var documentPollingTimer: Timer?
  static let keyboard = Bundle.main.bundleURL.deletingPathExtension().lastPathComponent
  static private var clipboardText = ""
  static private var firstLoad = true

  private var program: String {
    String(id)
  }

  public func isCurrentDocument(_ program: String, _ documentIdentifier: String) -> Bool {
    acceptsFcitxCommands && self.program == program
      && currentDocumentIdentifier() == documentIdentifier
  }

  // UIKit may temporarily return nil while switching between text inputs, even though Swift
  // imports documentIdentifier as a non-optional UUID. Read it through Objective-C to avoid a
  // trap in UUID._unconditionallyBridgeFromObjectiveC during that transition.
  private func currentDocumentIdentifier() -> String {
    let selector = NSSelectorFromString("documentIdentifier")
    guard
      let proxy = textDocumentProxy as? NSObject,
      proxy.responds(to: selector),
      let identifier = proxy.perform(selector)?.takeUnretainedValue() as? NSUUID
    else {
      return ""
    }
    return identifier.uuidString
  }

  private func currentDocumentState() -> DocumentState {
    DocumentState(
      identifier: currentDocumentIdentifier(),
      contextBeforeInput: textDocumentProxy.documentContextBeforeInput,
      selectedText: textDocumentProxy.selectedText,
      contextAfterInput: textDocumentProxy.documentContextAfterInput)
  }

  private func surroundingTextForInputEvent() -> (SurroundingText, String, Bool) {
    let currentDocumentState = currentDocumentState()
    let shouldReset = currentDocumentState != documentState
    documentState = currentDocumentState
    if shouldReset {
      FCITX_INFO("Document state changed \(self.id)")
      updateTextIsEmpty()
    }

    let before = currentDocumentState.contextBeforeInput ?? ""
    let selected = currentDocumentState.selectedText ?? ""
    let anchor = UInt32(before.unicodeScalars.count)
    return (
      SurroundingText(
        text: before + selected + (currentDocumentState.contextAfterInput ?? ""),
        cursor: anchor + UInt32(selected.unicodeScalars.count),
        anchor: anchor),
      currentDocumentState.identifier,
      shouldReset
    )
  }

  private func position(in text: String, atUnicodeScalarOffset target: Int)
    -> SurroundingTextPosition?
  {
    guard target >= 0 else { return nil }
    if target == 0 {
      return SurroundingTextPosition(utf16Offset: 0, characterOffset: 0)
    }

    var unicodeScalarOffset = 0
    var utf16Offset = 0
    var characterOffset = 0
    for character in text {
      let character = String(character)
      unicodeScalarOffset += character.unicodeScalars.count
      utf16Offset += character.utf16.count
      characterOffset += 1
      if unicodeScalarOffset == target {
        return SurroundingTextPosition(
          utf16Offset: utf16Offset, characterOffset: characterOffset)
      }
      if unicodeScalarOffset > target {
        return nil
      }
    }
    return nil
  }

  // Poll is needed because selectionDidChange is never called even for a standard TextField.
  private func startDocumentPolling() {
    documentState = currentDocumentState()
    guard documentPollingTimer == nil else { return }

    let timer = Timer(timeInterval: Self.documentPollingInterval, repeats: true) {
      [weak self] _ in
      MainActor.assumeIsolated {
        guard let self else { return }
        let currentDocumentState = self.currentDocumentState()
        defer { self.documentState = currentDocumentState }
        // Known issue: if 2 rows are identical, changing between with caret at same position won't call reset.
        guard currentDocumentState != self.documentState else { return }
        if currentDocumentState.identifier != self.documentState?.identifier {
          Fcitx.focusIn(self.program, currentDocumentState.identifier)
        } else {
          FCITX_INFO("Document state changed \(self.id)")
          self.resetInput()
        }
        self.updateTextIsEmpty()
      }
    }
    RunLoop.main.add(timer, forMode: .common)
    documentPollingTimer = timer
  }

  private func stopDocumentPolling() {
    documentPollingTimer?.invalidate()
    documentPollingTimer = nil
    documentState = nil
  }

  private func updateTextIsEmpty() {
    let text =
      (textDocumentProxy.documentContextBeforeInput ?? "")
      + (textDocumentProxy.selectedText ?? "")
      + (textDocumentProxy.documentContextAfterInput ?? "")
    vm.setTextIsEmpty(text.isEmpty)
  }

  override func updateViewConstraints() {
    super.updateViewConstraints()

    // Add custom view sizing constraints here
  }

  override func viewDidLoad() {
    id = UInt64(Int(bitPattern: Unmanaged.passUnretained(self).toOpaque()))
    countedAsLive = true
    Self.liveControllerCount += 1
    FCITX_INFO("viewDidLoad \(self.id) liveControllers=\(Self.liveControllerCount)")
    super.viewDidLoad()
    if KeyboardViewController.firstLoad {
      KeyboardViewController.firstLoad = false
      logPaths()
      redirectStderr()
      initProfile()
      // TODO: (this is tested in simulator) when user changes app locale in Settings,
      // app and keyboards are killed, but only if app is started first can it sync
      // locale to keyboards. Need to find a way to update locale on viewWillAppear.
      setLocale(syncLocale())
      startKeyboardFcitx(appBundlePath, "\(Bundle.main.bundlePath)/share", appGroup.path)
    }

    // Must recreate SwiftUI view, otherwise rotating may have old height which can't be updated.
    hostingController = UIHostingController(rootView: VirtualKeyboardView())
    hostingController.view.translatesAutoresizingMaskIntoConstraints = false

    // Spotlight shows that system keyboard has transparent background.
    hostingController.view.backgroundColor = .clear
    view.backgroundColor = .clear
  }

  override func viewWillAppear(_ animated: Bool) {
    FCITX_INFO("viewWillAppear \(self.id)")
    acceptsFcitxCommands = false
    SwiftFrontend.setClient(self)
    KeyboardUI.setClient(self)

    // If setting view in viewDidLoad instead, it will cause huge layout shift.
    addChild(hostingController)
    view.addSubview(hostingController.view)

    NSLayoutConstraint.activate([
      hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
      hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
    ])

    hostingController.didMove(toParent: self)

    vm.setReturnKeyType(textDocumentProxy.returnKeyType)
    super.viewWillAppear(animated)
    if appGroupAvailable {
      if removeFile(appGroupTmp.appendingPathComponent("\(Self.keyboard).reload")) {
        FCITX_INFO("Reload accepted")
        reload()
      }
    }
    if !appGroupAvailable,
      let textBefore = textDocumentProxy.documentContextBeforeInput,
      textBefore.hasPrefix(syncConfigMagicText)
    {
      // In sync config context.
      // Focusing this document makes FocusGroup drop any previously active context; focusing it
      // out below then leaves the group without an active context during config sync.
      Fcitx.focusIn(program, currentDocumentIdentifier())
      Fcitx.focusOut(program, currentDocumentIdentifier())
      textDocumentProxy.insertText(hasFullAccess ? syncConfigFullAccess : syncConfigNoFullAccess)
      if hasFullAccess {
        vm.keyboardDisplayName = getKeyboardDisplayName(Bundle.main.bundleURL)
        syncConfig()
      } else {
        vm.setDisplayMode(.syncPending)
      }
    } else {
      acceptsFcitxCommands = true
      vm.setDisplayMode(.initial)
      Fcitx.focusIn(program, currentDocumentIdentifier())
      self.resetInput()  // Avoid old context carried over.
    }
    startDocumentPolling()
  }

  override func viewWillDisappear(_ animated: Bool) {
    FCITX_INFO("viewWillDisappear \(self.id)")
    super.viewWillDisappear(animated)
    acceptsFcitxCommands = false
    Fcitx.focusOut(program, currentDocumentIdentifier())
    stopDocumentPolling()
    hostingController.willMove(toParent: nil)
    hostingController.view.removeFromSuperview()
    hostingController.removeFromParent()
  }

  deinit {
    if countedAsLive {
      Fcitx.destroyInputContext(String(id))
      Self.liveControllerCount -= 1
      FCITX_INFO("deinit \(self.id) liveControllers=\(Self.liveControllerCount)")
    }
  }

  override func viewWillLayoutSubviews() {
    FCITX_INFO("viewWillLayoutSubviews \(self.id)")
    super.viewWillLayoutSubviews()
  }

  override func textWillChange(_ textInput: UITextInput?) {
    // The app is about to change the document's contents. Perform any preparation here.
  }

  override func textDidChange(_ textInput: UITextInput?) {
    // The app has just changed the document's contents, the document context has been updated.
    updateTextIsEmpty()
  }

  public func keyPressed(_ key: String, _ code: String, _ modifiers: UInt32 = 0) {
    let (surroundingText, documentIdentifier, shouldReset) = surroundingTextForInputEvent()
    Fcitx.processKey(
      program, documentIdentifier, key, code, modifiers, surroundingText.text,
      surroundingText.cursor,
      surroundingText.anchor, shouldReset)
  }

  public func forwardKey(_ key: String, _ code: String) {
    let documentIdentifier = currentDocumentIdentifier()
    // documentContextBeforeInput could be all text or text in current line before cursor.
    // In the latter case, it will be '\n' if caret is at the beginning of a non-first line.
    switch code {
    case "ArrowDown":
      let offset = lastLine(textDocumentProxy.documentContextBeforeInput ?? "").count
      let step = firstLine(textDocumentProxy.documentContextAfterInput ?? "").utf16.count
      textDocumentProxy.adjustTextPosition(byCharacterOffset: step)
      DispatchQueue.main.async {
        guard self.currentDocumentIdentifier() == documentIdentifier else { return }
        // Move to the start of next line if exists.
        self.textDocumentProxy.adjustTextPosition(byCharacterOffset: 1)
        // Must have a delay, otherwise nextLineLength is always 0.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          guard self.currentDocumentIdentifier() == documentIdentifier else { return }
          let textAfter = self.textDocumentProxy.documentContextAfterInput ?? ""
          let column = min(offset, firstLine(textAfter).count)
          self.textDocumentProxy.adjustTextPosition(
            byCharacterOffset: textAfter.prefix(column).utf16.count)
        }
      }
    case "ArrowLeft":
      let textBefore = textDocumentProxy.documentContextBeforeInput ?? ""
      textDocumentProxy.adjustTextPosition(
        byCharacterOffset: -max(1, textBefore.suffix(1).utf16.count))
    case "ArrowRight":
      let textAfter = textDocumentProxy.documentContextAfterInput ?? ""
      textDocumentProxy.adjustTextPosition(
        byCharacterOffset: max(1, textAfter.prefix(1).utf16.count))
    case "ArrowUp":
      let textBefore = lastLine(textDocumentProxy.documentContextBeforeInput ?? "")
      let offset = textBefore.count
      textDocumentProxy.adjustTextPosition(byCharacterOffset: -textBefore.utf16.count)
      DispatchQueue.main.async {
        guard self.currentDocumentIdentifier() == documentIdentifier else { return }
        // Move to the end of previous line if exists.
        self.textDocumentProxy.adjustTextPosition(byCharacterOffset: -1)
        // Must have a delay, otherwise previousLineLength may always be 0.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          guard self.currentDocumentIdentifier() == documentIdentifier else { return }
          let textBefore = lastLine(self.textDocumentProxy.documentContextBeforeInput ?? "")
          if textBefore.count > offset {
            self.textDocumentProxy.adjustTextPosition(
              byCharacterOffset:
                -textBefore.suffix(textBefore.count - offset).utf16.count)
          }
        }
      }
    case "Backspace":
      textDocumentProxy.deleteBackward()
      updateTextIsEmpty()
    case "End":
      let textAfter = textDocumentProxy.documentContextAfterInput ?? ""
      textDocumentProxy.adjustTextPosition(byCharacterOffset: firstLine(textAfter).utf16.count)
    case "Enter":
      commitString("\n")  // \r doesn't work in Safari address bar.
    case "Home":
      let textBefore = textDocumentProxy.documentContextBeforeInput ?? ""
      textDocumentProxy.adjustTextPosition(byCharacterOffset: -lastLine(textBefore).utf16.count)
    default:
      if !key.isEmpty {
        commitString(key)
      }
    }
  }

  public func resetInput() {
    Fcitx.resetInput(program, currentDocumentIdentifier())
  }

  public func triggerUnicode() {
    Fcitx.triggerUnicode(program, currentDocumentIdentifier())
  }

  public func triggerQuickPhrase() {
    Fcitx.triggerQuickPhrase(program, currentDocumentIdentifier())
  }

  public func commitString(_ commit: String) {
    textDocumentProxy.insertText(commit)
    documentState = currentDocumentState()
    updateTextIsEmpty()
  }

  public func deleteSurroundingText(_ offset: Int, _ size: Int) {
    guard size > 0 else { return }

    let state = currentDocumentState()
    let before = state.contextBeforeInput ?? ""
    let selected = state.selectedText ?? ""
    let text = before + selected + (state.contextAfterInput ?? "")
    let anchor = before.unicodeScalars.count
    let cursor = anchor + selected.unicodeScalars.count
    let start = cursor + offset
    let end = start + size
    guard
      start >= 0,
      end > start,
      let startPosition = position(in: text, atUnicodeScalarOffset: start),
      let endPosition = position(in: text, atUnicodeScalarOffset: end),
      let cursorPosition = position(in: text, atUnicodeScalarOffset: cursor),
      let anchorPosition = position(in: text, atUnicodeScalarOffset: anchor)
    else {
      return
    }

    var deletionCount = endPosition.characterOffset - startPosition.characterOffset
    if selected.isEmpty {
      textDocumentProxy.adjustTextPosition(
        byCharacterOffset: endPosition.utf16Offset - cursorPosition.utf16Offset)
    } else {
      // UITextDocumentProxy can't set an arbitrary selection. We can still delete a range that
      // contains the current selection by deleting the selection first, then its two sides.
      guard start <= anchor, end >= cursor else { return }
      textDocumentProxy.deleteBackward()
      deletionCount -= cursorPosition.characterOffset - anchorPosition.characterOffset
      textDocumentProxy.adjustTextPosition(
        byCharacterOffset: endPosition.utf16Offset - cursorPosition.utf16Offset)
    }

    for _ in 0..<deletionCount {
      textDocumentProxy.deleteBackward()
    }
    documentState = currentDocumentState()
    updateTextIsEmpty()
  }

  public func carriageReturn() {
    commitString("\r")
  }

  public func setPreedit(_ preedit: String, _ caret: Int) {
    textDocumentProxy.setMarkedText(preedit, selectedRange: NSRange(location: caret, length: 0))
  }

  private func writeToClipboard(_ text: String) {
    if hasFullAccess {
      // On real device, this fails silently if full access is not granted. Simulator works which is misleading.
      UIPasteboard.general.string = text
    }
    KeyboardViewController.clipboardText = text
  }

  public func cut() {
    if let text = textDocumentProxy.selectedText {
      writeToClipboard(text)
      textDocumentProxy.deleteBackward()
      updateTextIsEmpty()
    }
  }

  public func copy() {
    if let text = textDocumentProxy.selectedText {
      writeToClipboard(text)
    }
  }

  public func paste() {
    if let text = UIPasteboard.general.string {
      commitString(text)
      // No need to store it, as when user turns off full access, system restarts keyboard.
    } else if !KeyboardViewController.clipboardText.isEmpty {
      commitString(KeyboardViewController.clipboardText)
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

  public func syncConfig() {
    vm.setDisplayMode(.syncRunning)
    Task { await doSyncConfig(Self.keyboard) }
  }
}
