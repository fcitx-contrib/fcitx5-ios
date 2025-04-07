import Fcitx
import SwiftUI
import SwiftUtil

private struct Addon: Codable, Identifiable {
  let name: String
  let id: String
  let comment: String
}

struct AddonConfigView: View {
  private let addons = deserialize([Addon].self, String(getAddons()))
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
