public func showTip(_ body: String, _ timeout: Int32) {
  guard let showToastCallback = showToastCallback else {
    return
  }
  showToastCallback(body, timeout)
}
