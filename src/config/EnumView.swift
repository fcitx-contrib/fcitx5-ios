import SwiftUI
import SwiftUtil

struct EnumView: View {
  let description: String
  @ObservedObject private var viewModel: OptionViewModel<String>
  let options: [(String, String)]

  init(data: [String: Any], onUpdate: @escaping (String) -> Void) {
    description = data["Description"] as! String
    let original = data["Enum"] as! [String: String]
    let translation = data["EnumI18n"] as? [String: String] ?? original
    options = original.reduce(into: [(String, String)]()) { result, pair in
      result.append((pair.value, translation[pair.key] ?? pair.value))
    }
    viewModel = OptionViewModel(
      value: data["Value"] as! String,
      defaultValue: data["DefaultValue"] as! String,
      onUpdate: { value in
        onUpdate(value)
      }
    )
  }

  var body: some View {
    Picker(description, selection: $viewModel.value) {
      ForEach(options, id: \.0) { pair in
        Text(pair.1).tag(pair.0)
      }
    }.resettable(viewModel)
  }
}
