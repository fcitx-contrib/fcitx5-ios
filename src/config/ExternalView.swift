import SwiftUI

struct ExternalView: OptionViewProtocol {
  let label: String
  let data: [String: Any]
  let value: Any
  let onUpdate: (Any) -> Void

  var body: some View {
    if data["LaunchSubConfig"] as? String == "True" {
      ConfigLinkView(title: label, uri: data["External"] as! String)
    } else {
      Text(label)
    }
  }
}
