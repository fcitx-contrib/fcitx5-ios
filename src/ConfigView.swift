import SwiftUI

func mergeChild(_ value: Any, _ childKey: String, _ childValue: Any) -> [String: Any] {
  var obj = value as? [String: Any] ?? [:]
  obj[childKey] = childValue
  return obj
}

struct ConfigView: View {
  let title: String
  let uri: String

  @ObservedObject private var manager = ConfigManager()

  var body: some View {
    let isPunctuationMap = uri == "fcitx://config/addon/punctuation/punctuationmap/zh_CN"
    VStack {
      if let error = manager.error {
        Text(error)
      } else {
        let forEach = ForEach(Array(manager.children.enumerated()), id: \.offset) { _, child in
          let option = child["Option"] as! String
          OptionView(
            data: child,
            value: Binding(
              get: { (manager.value as? [String: Any])?[option] ?? "" },
              set: { newValue in
                setConfig(uri, option, newValue)
                manager.value = mergeChild(manager.value, option, newValue)
              }
            ),
            expandGroup: uri == globalConfigUri)
        }
        if isPunctuationMap {
          // Flatten punctuation map since it only has one child.
          forEach
        } else {
          List {
            forEach
          }
        }
      }
    }
    .navigationTitle(title)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      // Punctuation map already has List-level reset button, which can update List UI.
      if !isPunctuationMap {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Reset") {
            manager.reset()
          }
        }
      }
    }
    .onAppear {
      manager.uri = uri
    }
  }
}

struct ConfigLinkView: View {
  let title: String
  let uri: String

  var body: some View {
    NavigationLink(
      destination: ConfigView(title: title, uri: uri)
    ) {
      Text(title)
    }
  }
}
