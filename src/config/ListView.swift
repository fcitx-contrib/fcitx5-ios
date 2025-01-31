import SwiftUI

private struct ListItem: Identifiable {
  let id = UUID()
  var value: Any
}

private func deserialize(_ value: Any) -> [ListItem] {
  guard let value = value as? [String: Any] else {
    return []
  }
  return (0..<value.count).compactMap { i in ListItem(value: value[String(i)]!) }
}

private func serialize(_ value: [ListItem]) -> [String: Any] {
  return value.enumerated().reduce(into: [String: Any]()) { result, pair in
    result[String(pair.offset)] = pair.element.value
  }
}

struct ListSubView: OptionViewProtocol {
  let label: String
  let data: [String: Any]
  let value: Any
  let onUpdate: (Any) -> Void
  @State private var list = [ListItem]()

  var body: some View {
    let type = data["Type"] as! String
    let optionViewType = toOptionViewType(["Type": String(type.suffix(type.count - "List|".count))])
    ScrollViewReader { proxy in
      List {
        Section {
          ForEach(Array(zip(list.indices, list)), id: \.1.id) { i, item in
            AnyView(
              optionViewType.init(
                label: "", data: data,  // List|Entries need this.
                value: item.value,
                onUpdate: {
                  list[i] = ListItem(value: $0)
                  onUpdate(serialize(list))
                })
            ).id(item.id)  // For scrolling.
          }
          .onDelete { offsets in
            list.remove(atOffsets: offsets)
            onUpdate(serialize(list))
          }
          .onMove { indices, newOffset in
            list.move(fromOffsets: indices, toOffset: newOffset)
            onUpdate(serialize(list))
          }
        } header: {
          HStack {
            Spacer()
            Button {
              if let children = data["Children"] as? [[String: Any]] {
                list.append(
                  ListItem(
                    value:
                      children.reduce(into: [:]) { result, child in
                        result[child["Option"] as! String] = child["DefaultValue"] ?? ""
                      }))
              } else {
                list.append(ListItem(value: ""))
              }
              onUpdate(serialize(list))
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                  proxy.scrollTo(list.last?.id)
                }
              }
            } label: {
              Image(systemName: "plus")
            }
          }
        }
      }
    }.navigationTitle(label)
      .onAppear {
        list = deserialize(value)
      }.contextMenu {
        Button {
          list = deserialize(data["DefaultValue"])
          onUpdate(data["DefaultValue"])
        } label: {
          Text("Reset")
        }
      }
  }
}

struct ListView: OptionViewProtocol {
  let label: String
  let data: [String: Any]
  let value: Any
  let onUpdate: (Any) -> Void

  var body: some View {
    NavigationLink(
      destination: ListSubView(label: label, data: data, value: value, onUpdate: onUpdate)
    ) {
      Text(label)
    }
  }
}
