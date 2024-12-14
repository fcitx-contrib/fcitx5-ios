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
          set: { value = $0 }
        )
      )
      // Leading for List item, trailing for String option.
      .multilineTextAlignment(label.isEmpty ? .leading : .trailing)
    }
  }
}
