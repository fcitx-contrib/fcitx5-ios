var showToastCallback: ((String, Int32) -> Void)?

public func setShowToastCallback(_ callback: @escaping (String, Int32) -> Void) {
  showToastCallback = callback
}
