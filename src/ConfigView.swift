import Fcitx
import FcitxIpc
import SwiftUI

private func getConfig(_ uri: String) -> [String: Any] {
  let data = String(Fcitx.getConfig(uri)).data(using: .utf8)!
  return try! JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
}

private func setConfig(_ uri: String, _ option: String, _ value: Any) {
  let data = try! JSONSerialization.data(withJSONObject: [option: value])
  Fcitx.setConfig(uri, String(data: data, encoding: .utf8)!)
  requestReload()
}

private class ViewModel: ObservableObject {
  @Published var children = [[String: Any]]()
  @Published var error: String?

  func refresh(_ uri: String) {
    let dict = getConfig(uri)
    if let children = dict["Children"] as? [[String: Any]] {
      self.children = children
      self.error = nil
    } else {
      self.error = dict["ERROR"] as? String
    }
  }
}

struct ConfigView: View {
  let title: String
  let uri: String

  @ObservedObject private var viewModel = ViewModel()

  var body: some View {
    VStack {
      if let error = viewModel.error {
        Text(error)
      } else {
        List {
          ForEach(viewModel.children.indices, id: \.self) { index in
            let child = viewModel.children[index]
            OptionView(
              data: child,
              onUpdate: { value in
                setConfig(uri, child["Option"] as! String, value)
                // Don't call viewModel.refresh here because view may be in a temporary invalid state,
                // e.g. having removed key of punctuation map but not put anything yet.
              })
          }
        }
      }
    }
    .navigationTitle(title)
    .navigationBarTitleDisplayMode(.inline)
    .onAppear {
      viewModel.refresh(uri)
    }
  }
}
