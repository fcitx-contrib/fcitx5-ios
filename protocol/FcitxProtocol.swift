import Foundation

public struct DocumentInfo: Sendable {
  public let processStartTime: Date?
  public let capturedAt: Date
  public let processIdentifier: Int32
  public let memoryFootprint: UInt64?
  public let availableMemory: UInt64
  public let currentDocumentIdentifier: String?
  public let keyboardType: String
  public let documentContextBeforeInput: String?
  public let selectedText: String?
  public let documentContextAfterInput: String?

  public init(
    processStartTime: Date?, capturedAt: Date, processIdentifier: Int32,
    memoryFootprint: UInt64?, availableMemory: UInt64, currentDocumentIdentifier: String?,
    keyboardType: String,
    documentContextBeforeInput: String?, selectedText: String?, documentContextAfterInput: String?
  ) {
    self.processStartTime = processStartTime
    self.capturedAt = capturedAt
    self.processIdentifier = processIdentifier
    self.memoryFootprint = memoryFootprint
    self.availableMemory = availableMemory
    self.currentDocumentIdentifier = currentDocumentIdentifier
    self.keyboardType = keyboardType
    self.documentContextBeforeInput = documentContextBeforeInput
    self.selectedText = selectedText
    self.documentContextAfterInput = documentContextAfterInput
  }
}

@MainActor
public protocol FcitxProtocol: AnyObject {
  func isCurrentDocument(_ program: String, _ documentIdentifier: String) -> Bool
  func isCurrentProgram(_ program: String) -> Bool
  func keyPressed(_ key: String, _ code: String, _ modifiers: UInt32)
  func forwardKey(_ key: String, _ code: String)
  func carriageReturn()
  func resetInput()
  func triggerUnicode()
  func triggerQuickPhrase()
  func commitString(_ string: String)
  func deleteSurroundingText(_ offset: Int, _ size: Int)
  func setPreedit(_ preedit: String, _ cursor: Int)
  func cut()
  func copy()
  func paste()
  func undo()
  func redo()
  func globe()
  func setCurrentInputMethod(_ inputMethod: String)
  func dismissKeyboard()
  func currentDocumentInfo() -> DocumentInfo
  func terminateExtension()
  func slideBackspace(_ step: Int)
  func syncConfig()
  func clipboardMonitoringEnabled() -> Bool
  func setClipboardMonitoring(_ enabled: Bool)
  func hasKeyboardFullAccess() -> Bool
}

extension FcitxProtocol {
  public func keyPressed(_ key: String, _ code: String) {
    keyPressed(key, code, 0)
  }
}
