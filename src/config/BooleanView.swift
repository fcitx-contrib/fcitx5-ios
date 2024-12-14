import SwiftUI

struct BooleanView: OptionViewProtocol {
  let label: String
  let data: [String: Any]
  @Binding var value: Any

  var body: some View {
    Toggle(
      isOn: Binding<Bool>(
        get: { value as! String == "True" },
        set: { x in value = x ? "True" : "False" }
      )
    ) {
      Text(label)
    }
  }
}
