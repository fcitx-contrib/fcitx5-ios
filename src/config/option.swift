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

extension View {
  func resettable<T>(_ viewModel: OptionViewModel<T>) -> some View {
    self.contextMenu {
      Button {
        viewModel.reset()
      } label: {
        Text("Reset")
      }
    }
  }
}

func toOptionView(_ data: [String: Any], onUpdate: @escaping (Encodable) -> Void) -> any View {
  switch data["Type"] as! String {
  case "Boolean":
    return BooleanView(data: data, onUpdate: onUpdate)
  case "Enum":
    return EnumView(data: data, onUpdate: onUpdate)
  case "Integer":
    return IntegerView(data: data, onUpdate: onUpdate)
  case "String":
    return StringView(data: data, onUpdate: onUpdate)
  case "External":
    return ExternalView(data: data)
  default:
    return UnknownView()
  }
}
