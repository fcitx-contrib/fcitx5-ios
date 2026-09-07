@MainActor
public protocol FcitxProtocol: AnyObject {
  func isCurrentDocument(_ program: String, _ documentIdentifier: String) -> Bool
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
  func globe()
  func setCurrentInputMethod(_ inputMethod: String)
  func dismissKeyboard()
  func slideBackspace(_ step: Int)
  func syncConfig()
}

extension FcitxProtocol {
  public func keyPressed(_ key: String, _ code: String) {
    keyPressed(key, code, 0)
  }
}
