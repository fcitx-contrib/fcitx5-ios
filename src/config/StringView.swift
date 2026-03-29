import SwiftUI

struct StringView: View, OptionViewProtocol {
  let label: String
  let data: [String: Any]
  @Binding var value: Any
  @State private var text: String
  @FocusState private var isFocused: Bool

  init(label: String, data: [String: Any], value: Binding<Any>) {
    self.label = label
    self.data = data
    self._value = value
    self._text = State(initialValue: value.wrappedValue as? String ?? "")
  }

  private func submit() {
    if ($value.wrappedValue as? String) != text {
      $value.wrappedValue = text
    }
  }

  var body: some View {
    HStack {
      if !label.isEmpty {
        Text(label)
      }
      TextField("", text: $text)
        .focused($isFocused)
        // Don't update real-time. It changes parent state so the whole view is re-rendered.
        // Don't use onSubmit. It requires Enter key to be pressed.
        .onChange(of: isFocused) { focused in
          if !focused {
            submit()
          }
        }
        .onChange(of: value as? String) {
          text = $0 ?? ""
        }
        // Leading for List item, trailing for String option.
        .multilineTextAlignment(label.isEmpty ? .leading : .trailing)
    }
    .resetContextMenu(data: data, value: $value)
  }
}
