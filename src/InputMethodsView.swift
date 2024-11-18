import AlertToast
import Fcitx
import FcitxCommon
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
  let allInputMethods = try! JSONDecoder().decode(
    [InputMethod].self, from: String(getAllInputMethods()).data(using: .utf8)!)
  let enabledInputMethods = try! JSONDecoder().decode(
    [InputMethod].self, from: String(getInputMethods()).data(using: .utf8)!
  ).map { $0.name }
  return allInputMethods.filter { !enabledInputMethods.contains($0.name) }
}

private class ViewModel: ObservableObject {
  @Published var inputMethods = availableInputMethods()
}

struct AddInputMethodsView: View {
  @Binding var enabledInputMethods: [InputMethod]
  @ObservedObject private var viewModel = ViewModel()

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
              viewModel.inputMethods.removeAll { $0.name == inputMethod.name }
              enabledInputMethods.append(inputMethod)
              setInputMethods(
                String(
                  data: try! JSONEncoder().encode(
                    enabledInputMethods.map { $0.name } + [inputMethod.name]),
                  encoding: .utf8)!)
              requestReload()
              message = "Added \(inputMethod.displayName)"
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
    .navigationTitle("Add input methods")
    .navigationBarTitleDisplayMode(.inline)
  }
}
