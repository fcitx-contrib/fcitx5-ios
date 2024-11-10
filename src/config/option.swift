import SwiftUI

class OptionViewModel<T>: ObservableObject {
  @Published var value: T {
    didSet {
      onUpdate(value)
    }
  }
  let defaultValue: T
  let onUpdate: (T) -> Void

  init(value: T, defaultValue: T, onUpdate: @escaping (T) -> Void) {
    self.value = value
    self.defaultValue = defaultValue
    self.onUpdate = onUpdate
  }

  func reset() {
    value = defaultValue
  }
}

func toOptionView(_ data: [String: Any], onUpdate: @escaping (Encodable) -> Void) -> any View {
  switch data["Type"] as! String {
  case "Boolean":
    return BooleanView(data: data, onUpdate: onUpdate)
  default:
    return UnknownView()
  }
}
