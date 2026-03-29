import SwiftUI

extension View {
  @ViewBuilder
  func resetContextMenu(data: [String: Any], value: Binding<Any>) -> some View {
    if let defaultValue = data["DefaultValue"] as? String {
      self.contextMenu {
        Button {
          value.wrappedValue = defaultValue
        } label: {
          Text("Reset")
        }
      }
    } else {
      self
    }
  }
}

protocol OptionViewProtocol: View {
  init(label: String, data: [String: Any], value: Binding<Any>)
}

struct OptionView: View {
  private let label: String
  private let data: [String: Any]
  @Binding private var value: Any
  private let optionViewType: any OptionViewProtocol.Type

  init(data: [String: Any], value: Binding<Any>, expandGroup: Bool = false) {
    label = data["Description"] as! String
    self.data = data
    _value = value
    optionViewType = toOptionViewType(data, expandGroup: expandGroup)
  }

  var body: some View {
    AnyView(optionViewType.init(label: label, data: data, value: $value))
  }
}

func toOptionViewType(_ data: [String: Any], expandGroup: Bool = false)
  -> any OptionViewProtocol.Type
{
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
    if type.starts(with: "Entries") {
      return EntryView.self
    }
    if data["Children"] != nil {
      // Expand: global config, link: fuzzy pinyin.
      return expandGroup ? GroupView.self : GroupLinkView.self
    }
    return UnknownView.self
  }
}
