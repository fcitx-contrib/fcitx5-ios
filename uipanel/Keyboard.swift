import SwiftUI
import SwiftUtil

private func getFlexes(_ keys: [[String: Any]]) -> [CGFloat] {
  return keys.map({ key in
    if let flex = key["flex"] as? String,
      let value = Double(flex)
    {
      return CGFloat(value)
    }
    return 1
  })
}

struct KeyboardView: View {
  @Binding var spaceLabel: String
  @Binding var enterLabel: String
  @State private var rows: [[String: Any]] = []

  var body: some View {
    GeometryReader { geometry in
      let width = geometry.size.width
      let height = keyboardHeight / CGFloat(rows.count)
      VStack(spacing: 0) {
        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
          renderRow(row, width, height)
        }
      }
      .onAppear {
        setLayout()
      }
    }.frame(height: keyboardHeight)
  }

  func setLayout() {
    let layoutUrl = Bundle.main.bundleURL.appendingPathComponent("share/layout/qwerty.json")
    guard let content = readJSON(layoutUrl) as? [String: Any],
      let layers = content["layers"] as? [[String: Any]],
      let defaultLayer = layers.first,
      let rows = defaultLayer["rows"] as? [[String: Any]]
    else {
      return
    }
    self.rows = rows
  }

  func renderRow(_ row: [String: Any], _ width: CGFloat, _ height: CGFloat) -> some View {
    guard let keys = row["keys"] as? [[String: Any]] else {
      return AnyView(EmptyView())
    }
    let flexes = getFlexes(keys)
    let unit = width / flexes.reduce(0, +)
    return AnyView(
      HStack(spacing: 0) {
        ForEach(Array(keys.enumerated()), id: \.offset) { i, key in
          let keyWidth = flexes[i] * unit
          if let type = key["type"] as? String {
            switch type {
            case "key":
              if let label = key["label"] as? String,
                let k = key["key"] as? String
              {
                KeyView(label: label, key: k, width: keyWidth, height: height)
              }
            case "space":
              SpaceView(label: spaceLabel, width: keyWidth, height: height)
            case "backspace":
              BackspaceView(width: keyWidth, height: height)
            case "globe":
              GlobeView(width: keyWidth, height: height)
            case "enter":
              EnterView(label: enterLabel, width: keyWidth, height: height)
            default:
              VStack {}.frame(width: keyWidth, height: height)
            }
          }
        }
      }.frame(width: width, height: height))
  }
}
