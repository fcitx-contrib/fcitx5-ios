import SwiftUI

struct EntryView: OptionViewProtocol {
  let label: String
  let data: [String: Any]
  let value: Any
  let onUpdate: (Any) -> Void

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
        OptionView(
          data: child,
          onUpdate: {
            var v = value as! [String: Any]
            v[child["Option"] as! String] = $0
            onUpdate(v)
          })
      }
    }
  }
}
