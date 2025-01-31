import Fcitx
import SwiftUI

private struct Addon: Codable, Identifiable {
  let name: String
  let id: String
  let comment: String
}

struct AddonConfigView: View {
  private let addons = try! JSONDecoder().decode(
    [Addon].self, from: String(getAddons()).data(using: .utf8)!)
  var body: some View {
    List {
      ForEach(addons) { addon in
        Section(footer: addon.comment.count > 0 ? Text(addon.comment) : nil) {
          ConfigLinkView(title: addon.name, uri: "fcitx://config/addon/\(addon.id)")
        }
      }
    }
  }
}
