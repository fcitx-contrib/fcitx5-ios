import SwiftUI

struct StringView: View, OptionViewProtocol {
  let label: String
  let data: [String: Any]
  @Binding var value: Any

  var body: some View {
    HStack {
      if !label.isEmpty {
        Text(label)
      }
      TextField(
        "",
        text: Binding<String>(
          get: { value as! String },
          set: { x in value = x }
        )
      ).multilineTextAlignment(.trailing)
    }
  }
}
