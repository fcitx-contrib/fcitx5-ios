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
  let value: Any
  let onUpdate: (Any) -> Void
  @State private var number: Int = 0

  var body: some View {
    let minValue = Int(data["IntMin"] as? String ?? "")
    let maxValue = Int(data["IntMax"] as? String ?? "")
    HStack {
      // Limit width of TextField and let Text expand, otherwise they take 1/3 each.
      Text(label).frame(maxWidth: .infinity, alignment: .leading)
      TextField("", value: $number, formatter: numberFormatter).multilineTextAlignment(.trailing)
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
    }.onChange(of: number) {
      onUpdate(String(number))
    }.onAppear {
      let v = value as! String
      number = v.isEmpty ? 0 : Int(v)!
    }.contextMenu {
      Button {
        let v = data["DefaultValue"] as! String
        number = v.isEmpty ? 0 : Int(v)!
      } label: {
        Text("Reset")
      }
    }
  }
}
