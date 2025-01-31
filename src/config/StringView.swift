import SwiftUI

struct StringView: View, OptionViewProtocol {
  let label: String
  let data: [String: Any]
  let value: Any
  let onUpdate: (Any) -> Void
  @State private var oldText: String = ""
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
          if !isFocused && oldText != text {
            oldText = text
            onUpdate(text)
          }
        }
        // Leading for List item, trailing for String option.
        .multilineTextAlignment(label.isEmpty ? .leading : .trailing)
    }.onAppear {
      text = value as! String
      oldText = text
    }.contextMenu {
      // String (Key) inside List doesn't have default value.
      if let defaultValue = data["DefaultValue"] as? String {
        Button {
          text = defaultValue
          onUpdate(text)
        } label: {
          Text("Reset")
        }
      }
    }
  }
}
