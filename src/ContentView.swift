import Fcitx
import SwiftUI

private class ViewModel: ObservableObject {
  @Published var url: URL?
}

struct ContentView: View {
  @Environment(\.scenePhase) private var scenePhase
  @ObservedObject private var viewModel = ViewModel()

  func handleURL(_ url: URL) {
    viewModel.url = url
    setConfig(url.absoluteString, "{}")
  }

  var body: some View {
    VStack {
      Image(systemName: "globe")
        .imageScale(.large)
        .foregroundStyle(.tint)
      if let url = viewModel.url {
        Text("\(url)")
      }
    }
    .padding()
    .onAppear {
      // The stupid iOS doesn't show empty directory in Files.app.
      try? "".write(
        to: documents.appendingPathComponent("placeholder"), atomically: true, encoding: .utf8)
    }
    .onChange(of: scenePhase) { newPhase in
      if newPhase == .active {
        sync(documents.appendingPathComponent("rime"), appGroupData.appendingPathComponent("rime"))
      }
    }
  }
}
