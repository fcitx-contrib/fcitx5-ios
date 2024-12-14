import SwiftUI

class OptionViewModel: ObservableObject {
  @Published var value: Any {
    didSet {
      onUpdate(value)
    }
  }
  let defaultValue: Any
  let onUpdate: (Any) -> Void

  init(value: Any, defaultValue: Any, onUpdate: @escaping (Any) -> Void) {
    self.value = value
    self.defaultValue = defaultValue
    self.onUpdate = onUpdate
  }

  func reset() {
    value = defaultValue
  }
}

protocol OptionViewProtocol: View {
  init(label: String, data: [String: Any], value: Binding<Any>)
}

struct OptionView: View {
  private let description: String
  private let data: [String: Any]
  private let optionViewType: any OptionViewProtocol.Type
  @ObservedObject private var viewModel: OptionViewModel

  init(data: [String: Any], onUpdate: @escaping (Any) -> Void) {
    description = data["Description"] as! String
    self.data = data
    optionViewType = toOptionViewType(data)

    viewModel = OptionViewModel(
      value: data["Value"] ?? "",
      defaultValue: data["DefaultValue"] ?? "",
      onUpdate: onUpdate
    )
  }

  var body: some View {
    let view = AnyView(optionViewType.init(label: description, data: data, value: $viewModel.value))
    if optionViewType == ExternalView.self || optionViewType == UnknownView.self {
      view
    } else {
      view.resettable(viewModel)
    }
  }
}

extension View {
  func resettable(_ viewModel: OptionViewModel) -> some View {
    self.contextMenu {
      Button {
        viewModel.reset()
      } label: {
        Text("Reset")
      }
    }
  }
}

func toOptionViewType(_ data: [String: Any]) -> any OptionViewProtocol.Type {
  let type = data["Type"] as! String
  switch type {
  case "Boolean":
    return BooleanView.self
  case "Enum":
    return EnumView.self
  case "Integer":
    return IntegerView.self
  case "String", "Key":
    if data["IsEnum"] as? String == "True" {
      return EnumView.self
    }
    return StringView.self
  case "External":
    return ExternalView.self
  default:
    if type.starts(with: "List|") {
      return ListView.self
    }
    return UnknownView.self
  }
}
