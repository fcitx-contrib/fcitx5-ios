var showToastCallback: ((String, String, Int32) -> Void)?

public func setShowToastCallback(_ callback: @escaping (String, String, Int32) -> Void) {
  showToastCallback = callback
}
