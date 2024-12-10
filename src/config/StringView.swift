import SwiftUI

struct StringView: View {
  let description: String
  @ObservedObject private var viewModel: OptionViewModel<String>

  init(data: [String: Any], onUpdate: @escaping (String) -> Void) {
    description = data["Description"] as! String
    viewModel = OptionViewModel(
      value: data["Value"] as! String,
      defaultValue: data["DefaultValue"] as! String,
      onUpdate: onUpdate
    )
  }

  var body: some View {
    HStack {
      Text(description)
      TextField("", text: $viewModel.value).resettable(viewModel)
    }
  }
}
