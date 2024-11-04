import AlertToast
import Fcitx
import NotifySwift
import SwiftUI

private class ViewModel: ObservableObject {
  @Published var url: URL?
}

struct ContentView: View {
  @Environment(\.scenePhase) private var scenePhase
  @ObservedObject private var viewModel = ViewModel()
  @State private var showToast = false
  @State private var duration = 3.0
  @State private var message = ""

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
    .toast(isPresenting: $showToast, duration: duration) {
      AlertToast(
        displayMode: .alert, type: .regular,
        subTitle: message,
        style: AlertToast.AlertStyle.style(
          subTitleFont: Font.system(size: 20)
        ))
    }
    .onAppear {
      // The stupid iOS doesn't show empty directory in Files.app.
      try? "".write(
        to: documents.appendingPathComponent("placeholder"), atomically: true, encoding: .utf8)
      setShowToastCallback({ message, duration in
        DispatchQueue.main.async {
          self.duration = Double(duration) / 1000.0
          self.message = message
          showToast = true
        }
      })
    }
    .onChange(of: scenePhase) { newPhase in
      if newPhase == .active {
        sync(documents.appendingPathComponent("rime"), appGroupData.appendingPathComponent("rime"))
      }
    }
  }
}
