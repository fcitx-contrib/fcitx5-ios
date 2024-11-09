import AlertToast
import Fcitx
import FcitxCommon
import NotifySwift
import SwiftUI
import SwiftUtil

struct InputMethod: Codable {
  let name: String
  let displayName: String
  let languageCode: String
}

private class ViewModel: ObservableObject {
  @Published var url: URL?
  @Published var inputMethods = [InputMethod]()

  func refresh() {
    inputMethods = try! JSONDecoder().decode(
      [InputMethod].self, from: String(getInputMethods()).data(using: .utf8)!)
  }
}

struct ContentView: View {
  @ObservedObject private var viewModel = ViewModel()

  // AlertToast fields
  @State private var showLoadingToast = false
  @State private var showToast = false
  @State private var duration = 3.0
  @State private var message = ""
  @State private var icon = "info"

  func handleURL(_ url: URL) {
    viewModel.url = url
    setConfig(url.absoluteString, "{}")
  }

  var body: some View {
    NavigationView {
      List {
        Section(header: Text("Input Methods")) {
          ForEach(viewModel.inputMethods, id: \.name) { inputMethod in
            NavigationLink(destination: ConfigView(inputMethod: inputMethod)) {
              Text(inputMethod.displayName)
            }
          }
        }
      }
      .navigationTitle("Fcitx5")
    }
    .toast(isPresenting: $showToast, duration: duration) {
      AlertToast(
        displayMode: .alert,
        type: icon == "error"
          ? .error(Color.red) : icon == "success" ? .complete(Color.green) : .regular,
        subTitle: message,
        style: AlertToast.AlertStyle.style(
          subTitleFont: Font.system(size: 20)
        ))
    }
    // Need a separate one because .loading will disable auto disappear and changing type wont't affect.
    .toast(isPresenting: $showLoadingToast) {
      AlertToast(
        displayMode: .alert,
        type: .loading,
        subTitle: message,
        style: AlertToast.AlertStyle.style(
          subTitleFont: Font.system(size: 20)
        ))
    }
    .onAppear {
      // The stupid iOS doesn't show empty directory in Files.app.
      try? "".write(
        to: documents.appendingPathComponent("placeholder"), atomically: true, encoding: .utf8)
      setShowToastCallback({ icon, message, duration in
        DispatchQueue.main.async {
          self.duration = Double(duration) / 1000.0
          self.message = message
          self.icon = icon
          if icon == "running" {
            self.showLoadingToast = true
          } else {
            self.showLoadingToast = false
            self.showToast = true
          }
        }
      })
      viewModel.refresh()
    }
  }
}
