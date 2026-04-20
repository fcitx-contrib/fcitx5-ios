import SwiftUI
import SwiftUtil

struct ExternalView: OptionViewProtocol {
  let label: String
  let data: [String: Any]
  @Binding var value: Any

  var body: some View {
    let option = data["Option"] as? String
    switch option {
    case "UserDataDir":
      Button {
        let rimePath = documents.appendingPathComponent("data/rime").path
        mkdirP(rimePath)
        if let url = URL(string: "shareddocuments://\(rimePath)") {
          UIApplication.shared.open(url)
        }
      } label: {
        Text(label)
      }.foregroundStyle(.primary)
    default:
      if data["LaunchSubConfig"] as? String == "True" {
        ConfigLinkView(title: label, uri: data["External"] as! String)
      } else {
        Text(label)
      }
    }
  }
}
