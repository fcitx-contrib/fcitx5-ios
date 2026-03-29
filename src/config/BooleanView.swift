import SwiftUI

struct BooleanView: OptionViewProtocol {
  let label: String
  let data: [String: Any]
  @Binding var value: Any

  var body: some View {
    Toggle(
      label,
      isOn: Binding(
        get: { value as? String == "True" },
        set: { value = $0 ? "True" : "False" }
      )
    )
    .resetContextMenu(data: data, value: $value)
  }
}
