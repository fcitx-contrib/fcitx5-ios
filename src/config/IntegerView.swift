import SwiftUI
import SwiftUtil

private let numberFormatter: NumberFormatter = {
  let formatter = NumberFormatter()
  formatter.numberStyle = .decimal
  formatter.allowsFloats = false
  formatter.usesGroupingSeparator = false
  return formatter
}()

struct IntegerView: OptionViewProtocol {
  let label: String
  let data: [String: Any]
  @Binding var value: Any
  @Binding private var number: Int
  @FocusState private var isFocused: Bool

  init(label: String, data: [String: Any], value: Binding<Any>) {
    self.label = label
    self.data = data
    self._value = value
    var oldNumber = Int(value.wrappedValue as? String ?? "") ?? 0
    self._number = Binding(
      get: { Int(value.wrappedValue as? String ?? "") ?? 0 },
      set: {
        if oldNumber == $0 {
          return
        }
        oldNumber = $0
        value.wrappedValue = String($0)
      }
    )
  }

  var body: some View {
    let minValue = Int(data["IntMin"] as? String ?? "")
    let maxValue = Int(data["IntMax"] as? String ?? "")
    HStack {
      // Limit width of TextField and let Text expand, otherwise they take 1/3 each.
      Text(label).frame(maxWidth: .infinity, alignment: .leading)
      TextField("", value: $number, formatter: numberFormatter).multilineTextAlignment(.trailing)
        .focused($isFocused)
        .onChange(of: isFocused) { focused in
          if !focused, let minValue = minValue, let maxValue = maxValue {
            if number < minValue {
              number = minValue
            } else if number > maxValue {
              number = maxValue
            }
          }
        }
        .frame(width: 60)
      if let minValue = minValue, let maxValue = maxValue {
        Stepper(
          value: $number,
          in: minValue...maxValue,
          step: 1
        ) {}
      } else {
        Stepper {
        } onIncrement: {
          number += 1
        } onDecrement: {
          number -= 1
        }
      }
    }
    .resetContextMenu(data: data, value: $value)
  }
}
