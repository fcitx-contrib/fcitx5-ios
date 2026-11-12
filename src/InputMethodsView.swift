import AlertToast
import Combine
import Fcitx
import FcitxIpc
import SwiftUI
import SwiftUtil

struct InputMethodsSectionHeaderView: View {
  @Binding var enabledInputMethods: [InputMethod]

  var body: some View {
    HStack {
      Text("Input Methods").textCase(nil)
      Spacer()
      NavigationLink(destination: AddInputMethodsView(enabledInputMethods: $enabledInputMethods)) {
        Image(systemName: "plus")
      }
    }
  }
}

func availableInputMethods() -> [InputMethod] {
  let allInputMethods = deserialize([InputMethod].self, String(getAllInputMethods()))
  let enabledInputMethods = deserialize([InputMethod].self, String(getInputMethods())).map {
    $0.name
  }
  return allInputMethods.filter { !enabledInputMethods.contains($0.name) }
}

@MainActor
private class ViewModel: ObservableObject {
  @Published var inputMethods = [InputMethod]()
  private var refreshSubscription: AnyCancellable?

  init() {
    refresh()
    refreshSubscription = configurationSync.didFinish.sink { [weak self] in self?.loadFromRuntime()
    }
  }

  func refresh() {
    guard !configurationSync.isSynchronizing else { return }
    loadFromRuntime()
  }

  private func loadFromRuntime() {
    inputMethods = availableInputMethods()
  }
}

struct AddInputMethodsView: View {
  @Binding var enabledInputMethods: [InputMethod]
  @StateObject private var viewModel = ViewModel()
  @ObservedObject private var syncState = configurationSync

  // AlertToast fields
  @State private var showToast = false
  @State private var message = ""

  var body: some View {
    VStack {
      if viewModel.inputMethods.isEmpty {
        Spacer()
        Text("No input methods available")
        Spacer()
      } else {
        List {
          ForEach(viewModel.inputMethods, id: \.name) { inputMethod in
            Button {
              guard !configurationSync.isSynchronizing else { return }
              // Use the current runtime profile rather than a possibly older view binding.
              enabledInputMethods = deserialize([InputMethod].self, String(getInputMethods()))
              guard !enabledInputMethods.contains(where: { $0.name == inputMethod.name }) else {
                viewModel.refresh()
                return
              }
              viewModel.inputMethods.removeAll { $0.name == inputMethod.name }
              enabledInputMethods.append(inputMethod)
              setInputMethods(
                String(
                  data: try! JSONEncoder().encode(enabledInputMethods.map { $0.name }),
                  encoding: .utf8)!)
              requestReload()
              message = String(
                format: NSLocalizedString("Added %@", comment: ""), inputMethod.displayName)
              showToast = true
            } label: {
              Text(inputMethod.displayName)
            }
          }
        }
      }
    }
    .toast(isPresenting: $showToast) {
      AlertToast(
        displayMode: .banner(.pop),
        type: .complete(Color.green),
        title: message,
        style: AlertToast.AlertStyle.style(
          titleFont: Font.system(size: 16)
        )
      )
    }
    .navigationTitle(NSLocalizedString("Add input methods", comment: ""))
    .navigationBarTitleDisplayMode(.inline)
    .disabled(syncState.isSynchronizing)
    .onAppear {
      viewModel.refresh()
    }
  }
}
