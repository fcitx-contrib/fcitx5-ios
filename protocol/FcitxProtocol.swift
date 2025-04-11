public protocol FcitxProtocol {
  func keyPressed(_ key: String, _ code: String)
  func commitString(_ string: String)
  func setPreedit(_ preedit: String, _ cursor: Int)
  func cut()
  func copy()
  func paste()
  func globe()
}
