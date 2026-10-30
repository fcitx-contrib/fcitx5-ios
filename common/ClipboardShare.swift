import Foundation

/// Carry the selected text itself because the main app may use a different clipboard database.
public struct ClipboardShareRequest: Identifiable {
  public let id = UUID()
  public let text: String

  public init(text: String) {
    self.text = text
  }

  public init?(url: URL) {
    guard url.scheme == "fcitx", url.host == "clipboard", url.path == "/share",
      let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
      let text = components.queryItems?.first(where: { $0.name == "text" })?.value
    else { return nil }
    self.text = text
  }

  public var url: URL {
    var components = URLComponents()
    components.scheme = "fcitx"
    components.host = "clipboard"
    components.path = "/share"
    components.queryItems = [URLQueryItem(name: "text", value: text)]
    return components.url!
  }
}
