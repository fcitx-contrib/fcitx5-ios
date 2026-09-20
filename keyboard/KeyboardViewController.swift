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
  private struct InputTraitsState: Equatable {
    let documentIdentifier: String
    let keyboardType: UIKeyboardType?
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

  nonisolated let uuid = UUID().uuidString
  nonisolated(unsafe) private var countedAsLive = false
  var hostingController: UIHostingController<VirtualKeyboardView>!
  var removedBySlide = ""
  // Reject queued C++ callbacks after the controller stops accepting input. Its program and
  // documentIdentifier may remain unchanged between viewWillDisappear and deinit. This also stays
  // false for the config-sync document, where Fcitx must not modify the proxy.
  private var acceptsFcitxCommands = false
  private var documentState: UndoRedoDocumentState?
  private var inputTraitsState: InputTraitsState?
  private var documentPollingTimer: Timer?
  private let undoRedoManager = UndoRedoManager()
  private var isChangingLines = false
  private var isSlidingBackspace = false
  private var hasMarkedText = false
  static let keyboard = Bundle.main.bundleURL.deletingPathExtension().lastPathComponent
  static private var clipboardText = ""
  static private var firstLoad = true

  private var program: String {
    uuid
  }

  public func isCurrentDocument(_ program: String, _ documentIdentifier: String) -> Bool {
    isCurrentProgram(program) && currentDocumentIdentifier() == documentIdentifier
  }

  public func isCurrentProgram(_ program: String) -> Bool {
    acceptsFcitxCommands && self.program == program
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

  private func currentDocumentState() -> UndoRedoDocumentState {
    UndoRedoDocumentState(
      identifier: currentDocumentIdentifier(),
      contextBeforeInput: textDocumentProxy.documentContextBeforeInput,
      selectedText: textDocumentProxy.selectedText,
      contextAfterInput: textDocumentProxy.documentContextAfterInput)
  }

  private func updateUndoRedoAvailability() {
    vm.setUndoRedo(undoRedoManager.canUndo, undoRedoManager.canRedo)
  }

  private func observeDocumentState(_ state: UndoRedoDocumentState) {
    undoRedoManager.update(to: state)
    documentState = state
    updateUndoRedoAvailability()
  }

  private func observeCurrentDocumentState() {
    observeDocumentState(currentDocumentState())
  }

  private func resetUndoRedoForCurrentDocument() {
    let state = currentDocumentState()
    undoRedoManager.reset(to: state)
    documentState = state
    updateUndoRedoAvailability()
  }

  private func surroundingTextForInputEvent() -> (SurroundingText, String, Bool) {
    let currentDocumentState = currentDocumentState()
    let shouldReset = currentDocumentState != documentState
    let documentChanged = currentDocumentState.identifier != documentState?.identifier
    if documentChanged {
      hasMarkedText = false
      undoRedoManager.reset(to: currentDocumentState)
      documentState = currentDocumentState
      updateUndoRedoAvailability()
    } else if hasMarkedText {
      documentState = currentDocumentState
    } else {
      observeDocumentState(currentDocumentState)
    }
    if documentChanged {
      vm.clearInputPanel()
    } else if shouldReset {
      FCITX_INFO("Document state changed \(self.uuid)")
    }
    if shouldReset {
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
    undoRedoManager.reset(to: documentState)
    updateUndoRedoAvailability()
    guard documentPollingTimer == nil else { return }

    let timer = Timer(timeInterval: Self.documentPollingInterval, repeats: true) {
      [weak self] _ in
      MainActor.assumeIsolated {
        guard let self else { return }
        let currentDocumentState = self.currentDocumentState()
        if currentDocumentState.identifier != self.documentState?.identifier {
          self.isChangingLines = false
          self.isSlidingBackspace = false
          self.hasMarkedText = false
          self.undoRedoManager.reset(to: currentDocumentState)
          self.documentState = currentDocumentState
          self.updateUndoRedoAvailability()
          vm.clearInputPanel()
          self.updateDisplayModeForInputTraits()
          Fcitx.focusIn(self.program, currentDocumentState.identifier)
          self.updateTextIsEmpty()
          return
        }
        if self.isChangingLines {
          self.undoRedoManager.reset(to: currentDocumentState)
          self.documentState = currentDocumentState
          self.updateUndoRedoAvailability()
          self.updateTextIsEmpty()
          return
        }
        if self.isSlidingBackspace {
          self.documentState = currentDocumentState
          self.updateTextIsEmpty()
          return
        }
        if self.hasMarkedText {
          self.documentState = currentDocumentState
          self.updateTextIsEmpty()
          return
        }
        defer { self.observeDocumentState(currentDocumentState) }
        // Known issue: if 2 rows are identical, changing between with caret at same position won't call reset.
        guard currentDocumentState != self.documentState else { return }
        FCITX_INFO("Document state changed \(self.uuid)")
        self.resetInput()
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
    undoRedoManager.reset()
    isChangingLines = false
    isSlidingBackspace = false
    hasMarkedText = false
    updateUndoRedoAvailability()
  }

  private func updateTextIsEmpty() {
    let text =
      (textDocumentProxy.documentContextBeforeInput ?? "")
      + (textDocumentProxy.selectedText ?? "")
      + (textDocumentProxy.documentContextAfterInput ?? "")
    vm.setTextIsEmpty(text.isEmpty)
  }

  private func updateDisplayModeForInputTraits() {
    guard acceptsFcitxCommands else { return }
    let state = InputTraitsState(
      documentIdentifier: currentDocumentIdentifier(),
      keyboardType: textDocumentProxy.keyboardType)
    guard state != inputTraitsState else { return }
    inputTraitsState = state
    // System forces builtin numpad for .numberPad, .decimalPad, .asciiCapableNumberPad.
    vm.setDisplayMode(
      state.keyboardType == .numbersAndPunctuation ? .numpad : .initial, resetReturnMode: true)
  }

  override func updateViewConstraints() {
    super.updateViewConstraints()

    // Add custom view sizing constraints here
  }

  override func viewDidLoad() {
    countedAsLive = true
    Self.liveControllerCount += 1
    FCITX_INFO("viewDidLoad \(self.uuid) liveControllers=\(Self.liveControllerCount)")
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
    FCITX_INFO("viewWillAppear \(self.uuid)")
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
      vm.clearInputPanel()
      updateDisplayModeForInputTraits()
      Fcitx.focusIn(program, currentDocumentIdentifier())
      self.resetInput()  // Avoid old context carried over.
    }
    startDocumentPolling()
  }

  override func viewWillDisappear(_ animated: Bool) {
    FCITX_INFO("viewWillDisappear \(self.uuid)")
    super.viewWillDisappear(animated)
    acceptsFcitxCommands = false
    inputTraitsState = nil
    Fcitx.focusOut(program, currentDocumentIdentifier())
    stopDocumentPolling()
    hostingController.willMove(toParent: nil)
    hostingController.view.removeFromSuperview()
    hostingController.removeFromParent()
  }

  deinit {
    if countedAsLive {
      Fcitx.destroyInputContext(uuid)
      Self.liveControllerCount -= 1
      FCITX_INFO("deinit \(self.uuid) liveControllers=\(Self.liveControllerCount)")
    }
  }

  override func viewWillLayoutSubviews() {
    FCITX_INFO("viewWillLayoutSubviews \(self.uuid)")
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
      let contextAfterInput = textDocumentProxy.documentContextAfterInput ?? ""
      guard contextAfterInput.contains("\n") else { return }
      isChangingLines = true
      resetUndoRedoForCurrentDocument()
      let offset = lastLine(textDocumentProxy.documentContextBeforeInput ?? "").count
      let step = firstLine(contextAfterInput).utf16.count
      textDocumentProxy.adjustTextPosition(byCharacterOffset: step)
      DispatchQueue.main.async {
        guard self.currentDocumentIdentifier() == documentIdentifier else {
          self.isChangingLines = false
          self.resetUndoRedoForCurrentDocument()
          return
        }
        // Move to the start of next line if exists.
        self.textDocumentProxy.adjustTextPosition(byCharacterOffset: 1)
        // Must have a delay, otherwise nextLineLength is always 0.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          guard self.currentDocumentIdentifier() == documentIdentifier else {
            self.isChangingLines = false
            self.resetUndoRedoForCurrentDocument()
            return
          }
          let textAfter = self.textDocumentProxy.documentContextAfterInput ?? ""
          let column = min(offset, firstLine(textAfter).count)
          self.textDocumentProxy.adjustTextPosition(
            byCharacterOffset: textAfter.prefix(column).utf16.count)
          self.isChangingLines = false
          self.resetUndoRedoForCurrentDocument()
        }
      }
    case "ArrowLeft":
      let textBefore = textDocumentProxy.documentContextBeforeInput ?? ""
      let changesLine = textBefore.hasSuffix("\n")
      textDocumentProxy.adjustTextPosition(
        byCharacterOffset: -max(1, textBefore.suffix(1).utf16.count))
      if changesLine {
        resetUndoRedoForCurrentDocument()
      }
    case "ArrowRight":
      let textAfter = textDocumentProxy.documentContextAfterInput ?? ""
      let changesLine = textAfter.hasPrefix("\n")
      textDocumentProxy.adjustTextPosition(
        byCharacterOffset: max(1, textAfter.prefix(1).utf16.count))
      if changesLine {
        resetUndoRedoForCurrentDocument()
      }
    case "ArrowUp":
      let contextBeforeInput = textDocumentProxy.documentContextBeforeInput ?? ""
      guard contextBeforeInput.contains("\n") else { return }
      isChangingLines = true
      resetUndoRedoForCurrentDocument()
      let textBefore = lastLine(contextBeforeInput)
      let offset = textBefore.count
      textDocumentProxy.adjustTextPosition(byCharacterOffset: -textBefore.utf16.count)
      DispatchQueue.main.async {
        guard self.currentDocumentIdentifier() == documentIdentifier else {
          self.isChangingLines = false
          self.resetUndoRedoForCurrentDocument()
          return
        }
        // Move to the end of previous line if exists.
        self.textDocumentProxy.adjustTextPosition(byCharacterOffset: -1)
        // Must have a delay, otherwise previousLineLength may always be 0.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          guard self.currentDocumentIdentifier() == documentIdentifier else {
            self.isChangingLines = false
            self.resetUndoRedoForCurrentDocument()
            return
          }
          let textBefore = lastLine(self.textDocumentProxy.documentContextBeforeInput ?? "")
          if textBefore.count > offset {
            self.textDocumentProxy.adjustTextPosition(
              byCharacterOffset:
                -textBefore.suffix(textBefore.count - offset).utf16.count)
          }
          self.isChangingLines = false
          self.resetUndoRedoForCurrentDocument()
        }
      }
    case "Backspace":
      observeCurrentDocumentState()
      textDocumentProxy.deleteBackward()
      observeCurrentDocumentState()
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
    if !hasMarkedText {
      observeCurrentDocumentState()
    }
    textDocumentProxy.insertText(commit)
    hasMarkedText = false
    observeCurrentDocumentState()
    updateTextIsEmpty()
  }

  public func deleteSurroundingText(_ offset: Int, _ size: Int) {
    guard size > 0 else { return }

    if !hasMarkedText {
      observeCurrentDocumentState()
    }
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
    if hasMarkedText {
      documentState = currentDocumentState()
    } else {
      observeCurrentDocumentState()
    }
    updateTextIsEmpty()
  }

  public func carriageReturn() {
    commitString("\r")
  }

  public func setPreedit(_ preedit: String, _ caret: Int) {
    if !preedit.isEmpty && !hasMarkedText {
      observeCurrentDocumentState()
      hasMarkedText = true
    }
    textDocumentProxy.setMarkedText(preedit, selectedRange: NSRange(location: caret, length: 0))
    documentState = currentDocumentState()
    if preedit.isEmpty {
      hasMarkedText = false
      observeCurrentDocumentState()
    }
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
      observeCurrentDocumentState()
      writeToClipboard(text)
      textDocumentProxy.deleteBackward()
      observeCurrentDocumentState()
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

  private func applyUndoRedoReplacement(_ replacement: UndoRedoReplacement)
    -> UndoRedoDocumentState?
  {
    let state = currentDocumentState()
    guard let line = state.lineForUndoRedo,
      replacement.range.lowerBound >= 0,
      replacement.range.upperBound <= line.text.count,
      replacement.finalCaret >= 0,
      replacement.finalCaret <= replacement.expectedText.count
    else {
      return nil
    }

    let selectedRange = line.selectionStart..<line.selectionEnd
    if !line.selectedText.isEmpty {
      guard selectedRange == replacement.range else { return nil }
      if replacement.text.isEmpty {
        textDocumentProxy.deleteBackward()
      } else {
        textDocumentProxy.insertText(replacement.text)
      }
    } else {
      let targetEnd = replacement.range.upperBound
      textDocumentProxy.adjustTextPosition(
        byCharacterOffset: utf16Offset(in: line.text, from: line.selectionStart, to: targetEnd))
      for _ in replacement.range {
        textDocumentProxy.deleteBackward()
      }
      if !replacement.text.isEmpty {
        textDocumentProxy.insertText(replacement.text)
      }
    }

    let naturalCaret = replacement.range.lowerBound + replacement.text.count
    textDocumentProxy.adjustTextPosition(
      byCharacterOffset: utf16Offset(
        in: replacement.expectedText, from: naturalCaret, to: replacement.finalCaret))
    return currentDocumentState()
  }

  private func utf16Offset(in text: String, from start: Int, to end: Int) -> Int {
    let startIndex = text.index(text.startIndex, offsetBy: start)
    let endIndex = text.index(text.startIndex, offsetBy: end)
    if start <= end {
      return text[startIndex..<endIndex].utf16.count
    }
    return -text[endIndex..<startIndex].utf16.count
  }

  public func undo() {
    resetInput()
    let state = currentDocumentState()
    undoRedoManager.undo(from: state) { replacement in
      self.applyUndoRedoReplacement(replacement)
    }
    documentState = currentDocumentState()
    updateUndoRedoAvailability()
    updateTextIsEmpty()
  }

  public func redo() {
    resetInput()
    let state = currentDocumentState()
    undoRedoManager.redo(from: state) { replacement in
      self.applyUndoRedoReplacement(replacement)
    }
    documentState = currentDocumentState()
    updateUndoRedoAvailability()
    updateTextIsEmpty()
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
      if isSlidingBackspace {
        isSlidingBackspace = false
        observeCurrentDocumentState()
        updateTextIsEmpty()
      }
    } else if step < 0 {
      if !isSlidingBackspace {
        observeCurrentDocumentState()
        isSlidingBackspace = true
      }
      let textBefore = textDocumentProxy.documentContextBeforeInput ?? ""
      let newRemoval = String(textBefore.suffix(-step))
      removedBySlide = newRemoval + removedBySlide
      for _ in 0..<newRemoval.count {
        textDocumentProxy.deleteBackward()
      }
      documentState = currentDocumentState()
      updateTextIsEmpty()
    } else {
      if !isSlidingBackspace {
        observeCurrentDocumentState()
        isSlidingBackspace = true
      }
      let refillCount = min(step, removedBySlide.count)
      let index = removedBySlide.index(removedBySlide.startIndex, offsetBy: refillCount)
      let refill = String(removedBySlide[..<index])
      removedBySlide = String(removedBySlide[index...])
      textDocumentProxy.insertText(refill)
      documentState = currentDocumentState()
      updateTextIsEmpty()
    }
  }

  public func syncConfig() {
    vm.setDisplayMode(.syncRunning)
    Task { await doSyncConfig(Self.keyboard) }
  }
}
