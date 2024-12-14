import SwiftUI

struct ExternalView: OptionViewProtocol {
  let label: String
  let data: [String: Any]
  @Binding var value: Any

  var body: some View {
    if data["LaunchSubConfig"] as? String == "True" {
      NavigationLink(
        destination: ConfigView(
          title: label,
          uri: data["External"] as! String)
      ) {
        Text(label)
      }
    } else {
      Text(label)
    }
  }
}
