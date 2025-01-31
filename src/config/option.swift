import SwiftUI

protocol OptionViewProtocol: View {
  init(label: String, data: [String: Any], value: Any, onUpdate: @escaping (Any) -> Void)
}

struct OptionView: View {
  private let description: String
  private let data: [String: Any]
  private let onUpdate: (Any) -> Void
  private let optionViewType: any OptionViewProtocol.Type

  init(data: [String: Any], onUpdate: @escaping (Any) -> Void, expandGroup: Bool = false) {
    description = data["Description"] as! String
    self.data = data
    self.onUpdate = onUpdate
    optionViewType = toOptionViewType(data, expandGroup: expandGroup)
  }

  var body: some View {
    AnyView(
      optionViewType.init(label: description, data: data, value: data["Value"], onUpdate: onUpdate))
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
