import SwiftUI

struct ExternalView: View {
  let description: String
  let hasSubConfig: Bool
  let external: String

  init(data: [String: Any]) {
    description = data["Description"] as! String
    hasSubConfig = data["LaunchSubConfig"] as? String == "True"
    external = data["External"] as! String
  }

  var body: some View {
    if hasSubConfig {
      NavigationLink(
        destination: ConfigView(
          title: description,
          uri: external)
      ) {
        Text(description)
      }
    } else {
      Text(description)
    }
  }
}
