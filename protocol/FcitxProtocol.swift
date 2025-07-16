public protocol FcitxProtocol {
  func keyPressed(_ key: String, _ code: String)
  func resetInput()
  func commitString(_ string: String)
  func setPreedit(_ preedit: String, _ cursor: Int)
  func cut()
  func copy()
  func paste()
  func globe()
  func setCurrentInputMethod(_ inputMethod: String)
}
