import SwiftUI
import SwiftUtil

struct GroupSubView: View {
  let data: [String: Any]
  @Binding var value: Any

  var body: some View {
    let children = data["Children"] as! [[String: Any]]
    ForEach(children.indices, id: \.self) { i in
      let child = children[i]
      OptionView(
        data: child,
        value: Binding(
          get: { (value as? [String: Any])?[child["Option"] as? String ?? ""] ?? [:] },
          set: { value = mergeChild(value, child["Option"] as? String ?? "", $0) }
        ))
    }
  }
}

struct GroupView: OptionViewProtocol {
  let label: String
  let data: [String: Any]
  @Binding var value: Any

  var body: some View {
    Section(header: Text(label).textCase(nil)) {
      GroupSubView(data: data, value: $value)
    }
  }
}

struct GroupLinkView: OptionViewProtocol {
  let label: String
  let data: [String: Any]
  @Binding var value: Any

  var body: some View {
    NavigationLink(
      destination: List {
        GroupSubView(data: data, value: $value)
      }.navigationTitle(label)
        .toolbar {  // Fuzzy Pinyin
          ToolbarItem(placement: .navigationBarTrailing) {
            Button {
              value = extractValue(data, reset: true)
            } label: {
              Text("Reset")
            }
          }
        }
    ) {
      Text(label)
    }
  }
}
