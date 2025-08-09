import AlertToast
import Fcitx
import FcitxCommon
import FcitxIpc
import NotifySwift
import SwiftUI
import SwiftUtil

private class ViewModel: ObservableObject {
  @Published var url: URL?
  @Published var inputMethods = [InputMethod]()

  func refresh() {
    inputMethods = deserialize([InputMethod].self, String(getInputMethods()))
  }

  func removeInputMethods(at offsets: IndexSet) {
    inputMethods.remove(atOffsets: offsets)
    save()
  }

  func orderInputMethods(at offsets: IndexSet, to destination: Int) {
    inputMethods.move(fromOffsets: offsets, toOffset: destination)
    save()
  }

  private func save() {
    setInputMethods(
      String(data: try! JSONEncoder().encode(inputMethods.map { $0.name }), encoding: .utf8)!)
    requestReload()
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
        Section(header: InputMethodsSectionHeaderView(enabledInputMethods: $viewModel.inputMethods))
        {
          let forEach = ForEach(viewModel.inputMethods, id: \.name) { inputMethod in
            ConfigLinkView(
              title: inputMethod.displayName, uri: "fcitx://config/inputmethod/\(inputMethod.name)")
          }
          if viewModel.inputMethods.count > 1 {
            forEach.onDelete { offsets in viewModel.removeInputMethods(at: offsets) }
              .onMove { indices, newOffset in
                viewModel.orderInputMethods(at: indices, to: newOffset)
              }
          } else {
            forEach
          }
        }
        Section {
          ConfigLinkView(
            title: NSLocalizedString("Global Config", comment: ""), uri: globalConfigUri)
          NavigationLink(
            destination: AddonConfigView()
          ) {
            Text("Addon Config")
          }
        }

        Section {
          NavigationLink(destination: AboutView()) {
            Text("About")
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
