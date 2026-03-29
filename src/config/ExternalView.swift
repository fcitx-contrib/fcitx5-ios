import SwiftUI

struct ExternalView: OptionViewProtocol {
  let label: String
  let data: [String: Any]
  @Binding var value: Any

  var body: some View {
    if data["LaunchSubConfig"] as? String == "True" {
      ConfigLinkView(title: label, uri: data["External"] as! String)
    } else {
      Text(label)
    }
  }
}
