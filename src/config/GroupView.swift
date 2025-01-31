import SwiftUI

struct GroupSubView: View {
  let data: [String: Any]
  let value: Any
  let onUpdate: (Any) -> Void

  var body: some View {
    let children = data["Children"] as! [[String: Any]]
    ForEach(children.indices, id: \.self) { i in
      OptionView(
        data: children[i],
        onUpdate: {
          var v = value as! [String: Any]
          v[children[i]["Option"] as! String] = $0
          onUpdate(v)
        })
    }
  }
}

struct GroupView: OptionViewProtocol {
  let label: String
  let data: [String: Any]
  let value: Any
  let onUpdate: (Any) -> Void

  var body: some View {
    Section(header: Text(label).textCase(nil)) {
      GroupSubView(data: data, value: value, onUpdate: onUpdate)
    }
  }
}

struct GroupLinkView: OptionViewProtocol {
  let label: String
  let data: [String: Any]
  let value: Any
  let onUpdate: (Any) -> Void

  var body: some View {
    NavigationLink(
      destination: List {
        GroupSubView(data: data, value: value, onUpdate: onUpdate)
      }.navigationTitle(label)
    ) {
      Text(label)
    }
  }
}
