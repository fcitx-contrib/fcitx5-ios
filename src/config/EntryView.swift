import SwiftUI

struct EntryView: OptionViewProtocol {
  let label: String
  let data: [String: Any]
  @Binding var value: Any

  private func getChild(_ children: [[String: Any]], _ i: Int) -> [String: Any] {
    var child = children[i]
    child["Value"] = (value as! [String: Any])[child["Option"] as! String]
    return child
  }

  var body: some View {
    let children = data["Children"] as! [[String: Any]]
    VStack {
      ForEach(children.indices, id: \.self) { i in
        let child = getChild(children, i)
        let optionViewType = toOptionViewType(child)
        AnyView(
          optionViewType.init(
            label: child["Description"] as! String,
            data: child,
            value: Binding<Any>(
              get: { child["Value"] },
              set: {
                var v = value as! [String: Any]
                v[child["Option"] as! String] = $0
                value = v
              }
            )))
      }
    }
  }
}
