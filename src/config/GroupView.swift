import SwiftUI

struct GroupSubView: OptionViewProtocol {
  let label: String
  let data: [String: Any]
  @Binding var value: Any

  var body: some View {
    let children = data["Children"] as! [[String: Any]]
    List {
      ForEach(children.indices, id: \.self) { i in
        OptionView(
          data: children[i],
          onUpdate: {
            var v = value as! [String: Any]
            v[children[i]["Option"] as! String] = $0
            value = v
          })
      }
    }
    .navigationTitle(label)
  }
}

struct GroupView: OptionViewProtocol {
  let label: String
  let data: [String: Any]
  @Binding var value: Any

  var body: some View {
    NavigationLink(
      destination: GroupSubView(label: label, data: data, value: $value)
    ) {
      Text(label)
    }
  }
}
