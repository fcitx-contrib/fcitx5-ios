import SwiftUI

struct BooleanView: OptionViewProtocol {
  let label: String
  let data: [String: Any]
  let value: Any
  let onUpdate: (Any) -> Void
  @State private var isOn: Bool = false

  var body: some View {
    Toggle(isOn: $isOn) {
      Text(label)
    }.onChange(of: isOn) {
      onUpdate(isOn ? "True" : "False")
    }.onAppear {
      isOn = value as! String == "True"
    }.contextMenu {
      Button {
        isOn = data["DefaultValue"] as! String == "True"
      } label: {
        Text("Reset")
      }
    }
  }
}
