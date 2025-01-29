import SwiftUI

struct BooleanView: OptionViewProtocol {
  let label: String
  let data: [String: Any]
  @Binding var value: Any
  @State private var isOn: Bool = false

  var body: some View {
    Toggle(isOn: $isOn) {
      Text(label)
    }.onChange(of: isOn) {
      value = isOn ? "True" : "False"
    }.onAppear {
      isOn = value as! String == "True"
    }
  }
}
