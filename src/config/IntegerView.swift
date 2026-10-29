import SwiftUI
import SwiftUtil
import UIKit

private let numberFieldWidth: CGFloat = 60
private let minimumInputHeight: CGFloat = 44

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
    let lowerBound = minValue ?? Int.min
    let upperBound = maxValue ?? Int.max
    let option = data["Option"] as? String ?? ""
    let stepperId = "\(option)_stepper"
    HStack {
      HStack {
        // Keep the number compact while the label fills the available space.
        Text(label)
          .frame(maxWidth: .infinity, alignment: .leading)
          .accessibilityIdentifier(option + "_label")
        TextField("", value: $number, formatter: numberFormatter)
          .keyboardType(.numbersAndPunctuation)  // Use our own numpad.
          .submitLabel(.done)
          .multilineTextAlignment(.trailing)
          .focused($isFocused)
          .onChange(of: isFocused) { focused in
            if focused {
              DispatchQueue.main.async {
                guard isFocused else { return }
                UIApplication.shared.sendAction(
                  #selector(UIResponder.selectAll(_:)), to: nil, from: nil, for: nil)
              }
            } else {
              if let minValue, number < minValue {
                number = minValue
              } else if let maxValue, number > maxValue {
                number = maxValue
              }
            }
          }
          .frame(
            minWidth: numberFieldWidth, maxWidth: numberFieldWidth, minHeight: minimumInputHeight
          )
          .accessibilityIdentifier(option)
      }
      .frame(maxWidth: .infinity, minHeight: minimumInputHeight)
      .contentShape(Rectangle())
      .simultaneousGesture(
        TapGesture().onEnded {
          isFocused = true
        })
      // A range-based Stepper computes its total distance, which can overflow for
      // one-sided bounds such as -1...Int.max. Check each step without subtracting bounds.
      Stepper(
        onIncrement: number < upperBound
          ? { if number < upperBound { number += 1 } } : nil,
        onDecrement: number > lowerBound
          ? { if number > lowerBound { number -= 1 } } : nil
      ) {}
      .labelsHidden()
      .accessibilityValue(String(number))
      .accessibilityIdentifier(stepperId)
    }
    .resetContextMenu(data: data, value: $value)
  }
}
