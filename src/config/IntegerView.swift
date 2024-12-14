import SwiftUI
import SwiftUtil

private let numberFormatter: NumberFormatter = {
  let formatter = NumberFormatter()
  formatter.numberStyle = .decimal
  formatter.allowsFloats = false
  formatter.usesGroupingSeparator = false
  return formatter
}()

private func transform(_ binding: Binding<Any>) -> Binding<Int> {
  return Binding<Int>(
    get: {
      let value = binding.wrappedValue as! String
      return value.isEmpty ? 0 : Int(value)!
    },
    set: { value in binding.wrappedValue = String(value) }
  )
}

struct IntegerView: OptionViewProtocol {
  let label: String
  let data: [String: Any]
  @Binding var value: Any

  var body: some View {
    let intValue = transform($value)
    let minValue = Int(data["IntMin"] as? String ?? "")
    let maxValue = Int(data["IntMax"] as? String ?? "")
    HStack {
      Text(label)
      TextField("", value: intValue, formatter: numberFormatter).multilineTextAlignment(.trailing)
      if let minValue = minValue, let maxValue = maxValue {
        Stepper(
          value: intValue,
          in: minValue...maxValue,
          step: 1
        ) {}
      } else {
        Stepper {
        } onIncrement: {
          intValue.wrappedValue += 1
        } onDecrement: {
          intValue.wrappedValue -= 1
        }
      }
    }
  }
}
