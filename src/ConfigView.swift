import Fcitx
import SwiftUI

private class ViewModel: ObservableObject {
  @Published var json: String = "{}"

  func refresh(_ uri: String) {
    json = String(getConfig(uri))
  }
}

struct ConfigView: View {
  let title: String
  let uri: String

  @ObservedObject private var viewModel = ViewModel()

  var body: some View {
    VStack {
      Text(viewModel.json)
    }
    .navigationTitle(title)
    .navigationBarTitleDisplayMode(.inline)
    .onAppear {
      viewModel.refresh(uri)
    }
  }
}
