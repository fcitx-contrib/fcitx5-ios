public protocol FcitxProtocol {
  func keyPressed(_ key: String)
  func commitString(_ string: String)
  func setPreedit(_ preedit: String, _ cursor: Int)
}
