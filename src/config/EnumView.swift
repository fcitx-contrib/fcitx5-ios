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

  var body: some View {
    Picker(
      label,
      selection: Binding<String>(
        get: { value as! String },
        set: { x in value = x }
      )
    ) {
      ForEach(dataToOptions(data), id: \.0) { pair in
        Text(pair.1).tag(pair.0)
      }
    }
  }
}
