@MainActor
var showToastCallback: ((String, String, Int32) -> Void)?

@MainActor
public func setShowToastCallback(_ callback: @escaping (String, String, Int32) -> Void) {
  showToastCallback = callback
}
