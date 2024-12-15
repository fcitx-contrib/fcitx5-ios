import SwiftUI

struct StringView: View, OptionViewProtocol {
  let label: String
  let data: [String: Any]
  @Binding var value: Any
  @State private var text: String = ""
  @FocusState private var isFocused: Bool

  var body: some View {
    HStack {
      if !label.isEmpty {
        Text(label)
      }
      TextField("", text: $text)
        .focused($isFocused)
        // Don't update real-time. It changes parent state so the whole view is re-rendered.
        // Don't use onSubmit. It requires Enter key to be pressed.
        .onChange(of: isFocused) {
          // Avoid unnecessary write.
          if !isFocused && value as! String != text {
            value = text
          }
        }
        // Leading for List item, trailing for String option.
        .multilineTextAlignment(label.isEmpty ? .leading : .trailing)
    }.onAppear {
      text = value as! String
    }
  }
}
