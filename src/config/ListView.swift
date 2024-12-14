import SwiftUI

private func deserialize(_ value: Any) -> [Any] {
  guard let value = value as? [String: Any] else {
    return []
  }
  return (0..<value.count).compactMap { i in value[String(i)] }
}

private func serialize(_ value: [Any]) -> [String: Any] {
  return value.enumerated().reduce(into: [String: Any]()) { result, pair in
    result[String(pair.offset)] = pair.element
  }
}

private struct ListSectionHeader: View {
  @Binding var value: Any

  var body: some View {
    HStack {
      Spacer()
      Button {
        var list = deserialize(value)
        list.append("")
        value = serialize(list)
      } label: {
        Image(systemName: "plus")
      }
    }
  }
}

struct ListSubView: OptionViewProtocol {
  let label: String
  let data: [String: Any]
  @Binding var value: Any

  var body: some View {
    let type = data["Type"] as! String
    let optionViewType = toOptionViewType(["Type": String(type.suffix(type.count - "List|".count))])
    var list = deserialize(value)
    List {
      Section(header: ListSectionHeader(value: $value)) {
        ForEach(list.indices, id: \.self) { i in
          AnyView(
            optionViewType.init(
              label: "", data: data,  // List|Entries need this.
              value: Binding<Any>(
                get: { list[i] },
                set: {
                  list[i] = $0
                  value = serialize(list)
                }
              )))
        }
        .onDelete { offsets in
          list.remove(atOffsets: offsets)
          value = serialize(list)
        }
        .onMove { indices, newOffset in
          list.move(fromOffsets: indices, toOffset: newOffset)
          value = serialize(list)
        }
      }
    }.navigationTitle(label)
  }
}

struct ListView: OptionViewProtocol {
  let label: String
  let data: [String: Any]
  @Binding var value: Any

  var body: some View {
    NavigationLink(
      destination: ListSubView(label: label, data: data, value: $value)
    ) {
      Text(label)
    }
  }
}
