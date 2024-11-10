import SwiftUI

struct BooleanView: View {
  let description: String
  @ObservedObject private var viewModel: OptionViewModel<Bool>

  init(data: [String: Any], onUpdate: @escaping (String) -> Void) {
    description = data["Description"] as! String
    viewModel = OptionViewModel(
      value: data["Value"] as! String == "True",
      defaultValue: data["DefaultValue"] as! String == "True",
      onUpdate: { value in
        onUpdate(value ? "True" : "False")
      }
    )
  }

  var body: some View {
    Toggle(isOn: $viewModel.value) {
      Text(description)
    }.contextMenu {
      Button {
        viewModel.reset()
      } label: {
        Text("Reset")
      }
    }
  }
}
