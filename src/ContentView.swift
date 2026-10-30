import AlertToast
import Fcitx
import FcitxIpc
import NotifySwift
import SwiftUI
import SwiftUtil

private class ViewModel: ObservableObject {
  @Published var url: URL?
  @Published var inputMethods = [InputMethod]()
  @Published var clipboardShare: ClipboardShareRequest?
  @Published var clipboardEdit: ClipboardEditRequest?

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

private struct ClipboardEditSheetView: View {
  // Observe requests inside the sheet; its presentation closure can retain the first item.
  @ObservedObject var viewModel: ViewModel
  let onSaved: () -> Void

  var body: some View {
    if let request = viewModel.clipboardEdit {
      NavigationStack {
        ClipboardEditView(request: request, onSaved: onSaved)
      }
    }
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
  @State private var showClipboardSync = false

  func handleURL(_ url: URL) {
    if url.host == "clipboard", url.path == "/edit" {
      viewModel.clipboardEdit = ClipboardEditRequest(url: url)
      return
    }
    if url.host == "clipboard", url.path == "/share" {
      viewModel.clipboardShare = ClipboardShareRequest(url: url)
      return
    }
    viewModel.url = url
    setConfig(url.absoluteString, "{}")
  }

  var body: some View {
    NavigationStack {
      List {
        Section(header: InputMethodsSectionHeaderView(enabledInputMethods: $viewModel.inputMethods))
        {
          let forEach = ForEach(viewModel.inputMethods, id: \.name) { inputMethod in
            ConfigLinkView(
              title: inputMethod.displayName, uri: "fcitx://config/inputmethod/\(inputMethod.name)"
            )
            .accessibilityIdentifier(inputMethod.name)
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
            title: NSLocalizedString("Global Config", comment: ""), uri: globalConfigUri
          )
          .accessibilityIdentifier("Global Config")
          NavigationLink(
            destination: AddonConfigView()
          ) {
            Text("Addon Config")
          }
          .accessibilityIdentifier("Addon Config")
        }

        Section {
          ConfigLinkView(
            title: NSLocalizedString("Clipboard", comment: ""),
            uri: "fcitx://config/addon/iosfrontend/Clipboard"
          )
          .accessibilityIdentifier("Clipboard")
          NavigationLink(destination: DataManagerView()) {
            Text("Data Manager")
          }
          .accessibilityIdentifier("Data Manager")
          NavigationLink(destination: AboutView()) {
            Text("About")
          }
        }
      }
      .navigationTitle(NSLocalizedString("Fcitx5", comment: ""))
      .navigationDestination(isPresented: $showClipboardSync) {
        SyncConfigView()
      }
      .overlay(alignment: .bottomTrailing) {
        HStack(spacing: 8) {
          Button {
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
          } label: {
            Text("Full Access")
              .padding(.horizontal, 12)
              .padding(.vertical, 8)
              .background(Color.blue)
              .foregroundColor(.white)
              .cornerRadius(8)
          }
          NavigationLink(destination: SyncConfigView()) {
            Text("Sync config")
              .padding(.horizontal, 12)
              .padding(.vertical, 8)
              .background(Color.blue)
              .foregroundColor(.white)
              .cornerRadius(8)
          }
        }
        .padding()
      }
    }
    .sheet(item: $viewModel.clipboardShare) { request in
      ActivityView(activityItems: [request.text]) { _ in
        viewModel.clipboardShare = nil
      }
    }
    .sheet(item: $viewModel.clipboardEdit) { _ in
      ClipboardEditSheetView(viewModel: viewModel) {
        viewModel.clipboardEdit = nil
        showClipboardSync = !appGroupAvailable
      }
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
        self.duration = Double(duration) / 1000.0
        self.message = message
        self.icon = icon
        if icon == "running" {
          self.showLoadingToast = true
        } else {
          self.showLoadingToast = false
          self.showToast = true
        }
      })
      viewModel.refresh()
    }
  }
}
