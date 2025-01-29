import SwiftUI

private func dataToOptions(_ data: [String: Any]) -> [(String, String)] {
  let original = data["Enum"] as! [String: String]
  let translation = data["EnumI18n"] as? [String: String] ?? original
  return original.reduce(into: [(String, String)]()) { result, pair in
    result.append((pair.value, translation[pair.key] ?? pair.value))
  }
}

struct EnumView: OptionViewProtocol {
  let label: String
  let data: [String: Any]
  @Binding var value: Any
  @State private var selection: String = ""

  var body: some View {
    Picker(label, selection: $selection) {
      ForEach(dataToOptions(data), id: \.0) { pair in
        Text(pair.1).tag(pair.0)
      }
    }.onChange(of: selection) {
      // Avoid rerender, which is dead loop for spell addon.
      if value as! String != selection {
        value = selection
      }
    }
    .onAppear {
      selection = value as! String
    }
  }
}
