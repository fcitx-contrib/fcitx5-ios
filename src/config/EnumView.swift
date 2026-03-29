import SwiftUI

private func dataToOptions(_ data: [String: Any]) -> [(String, String)] {
  let original = data["Enum"] as? [String: String] ?? [:]
  let translations = data["EnumI18n"] as? [String: String] ?? original
  var res = [(String, String)]()
  for i in 0..<original.count {
    let key = String(i)
    if let value = original[key], let translation = translations[key] {
      res.append((value, translation))
    }
  }
  return res
}

struct EnumView: OptionViewProtocol {
  let label: String
  let data: [String: Any]
  @Binding var value: Any

  var body: some View {
    Picker(
      label,
      selection: Binding(
        get: { value as? String ?? "" },
        set: {
          if $0 != value as? String {
            value = $0
          }
        }
      )
    ) {
      ForEach(dataToOptions(data), id: \.0) { pair in
        Text(pair.1).tag(pair.0)
      }
    }
    .resetContextMenu(data: data, value: $value)
  }
}
