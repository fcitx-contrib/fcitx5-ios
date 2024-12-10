import SwiftUI

let numberFormatter: NumberFormatter = {
  let formatter = NumberFormatter()
  formatter.numberStyle = .decimal
  formatter.allowsFloats = false
  formatter.usesGroupingSeparator = false
  return formatter
}()

struct IntegerView: View {
  let description: String
  let minValue: Int?
  let maxValue: Int?
  @ObservedObject private var viewModel: OptionViewModel<Int>

  init(data: [String: Any], onUpdate: @escaping (String) -> Void) {
    description = data["Description"] as! String
    minValue = Int(data["IntMin"] as? String ?? "")
    maxValue = Int(data["IntMax"] as? String ?? "")
    viewModel = OptionViewModel(
      value: Int(data["Value"] as! String) ?? 0,
      defaultValue: Int(data["DefaultValue"] as! String) ?? 0,
      onUpdate: { value in
        onUpdate(String(value))
      }
    )
  }

  var body: some View {
    HStack {
      Text(description)
      TextField("", value: $viewModel.value, formatter: numberFormatter).resettable(
        viewModel
      ).multilineTextAlignment(.trailing)
      if let minValue = minValue, let maxValue = maxValue {
        Stepper(
          value: $viewModel.value,
          in: minValue...maxValue,
          step: 1
        ) {}
      } else {
        Stepper {
        } onIncrement: {
          viewModel.value += 1
        } onDecrement: {
          viewModel.value -= 1
        }
      }
    }
  }
}
