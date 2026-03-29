import SwiftUI

struct EntryView: OptionViewProtocol {
  let label: String
  let data: [String: Any]
  @Binding var value: Any

  private func getChild(_ children: [[String: Any]], _ i: Int) -> [String: Any]? {
    guard i >= 0 && i < children.count else { return nil }
    var child = children[i]
    child["Value"] = (value as? [String: Any])?[child["Option"] as? String ?? ""]
    child.removeValue(forKey: "DefaultValue")  // Disable single item reset on punctuation map.
    return child
  }

  var body: some View {
    let children = data["Children"] as? [[String: Any]] ?? []
    VStack {
      ForEach(children.indices, id: \.self) { i in
        if let child = getChild(children, i) {
          OptionView(
            data: child,
            value: Binding(
              get: { (value as? [String: Any])?[child["Option"] as? String ?? ""] as? Any ?? "" },
              set: { newValue in
                value = mergeChild(value, child["Option"] as? String ?? "", newValue)
              }
            ))
        }
      }
    }
  }
}
