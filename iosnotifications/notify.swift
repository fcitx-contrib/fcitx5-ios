public func showTip(_ icon: String, _ body: String, _ timeout: Int32) {
  Task { @MainActor in
    guard let showToastCallback = showToastCallback else {
      return
    }
    showToastCallback(icon, body, timeout)
  }
}
