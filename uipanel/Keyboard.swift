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
  let width: CGFloat
  let layer: String
  let lock: Bool
  let spaceLabel: String
  let enterLabel: String
  @State private var defaultRows = [[String: Any]]()
  @State private var shiftRows = [[String: Any]]()

  var body: some View {
    let rows = layer == "shift" ? shiftRows : defaultRows
    let height = keyboardHeight / CGFloat(rows.count)
    VStack(spacing: 0) {
      ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
        renderRow(row, width, height)
      }
    }
    .frame(height: keyboardHeight)
    .onAppear {
      setLayout()
    }
  }

  func setLayout() {
    let layoutUrl = appBundleUrl.appendingPathComponent("share/layout/qwerty.json")
    guard let content = readJSON(layoutUrl) as? [String: Any],
      let layers = content["layers"] as? [[String: Any]],
      let defaultLayer = layers.filter({ $0["id"] as? String == "default" }).first,
      let defaultRows = defaultLayer["rows"] as? [[String: Any]]
    else {
      return
    }
    self.defaultRows = defaultRows
    if let shiftLayer = layers.filter({ $0["id"] as? String == "shift" }).first,
      let shiftRows = shiftLayer["rows"] as? [[String: Any]]
    {
      self.shiftRows = shiftRows
    }
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
                let subLabel = key["subLabel"] as? [String: String]
                let swipeUp = key["swipeUp"] as? [String: Any]
                KeyView(
                  label: label, key: k, subLabel: subLabel, swipeUp: swipeUp, width: keyWidth,
                  height: height)
              }
            case "space":
              SpaceView(label: spaceLabel, width: keyWidth, height: height)
            case "backspace":
              BackspaceView(width: keyWidth, height: height)
            case "globe":
              GlobeView(width: keyWidth, height: height)
            case "enter":
              EnterView(label: enterLabel, width: keyWidth, height: height)
            case "shift":
              ShiftView(
                state: layer == "shift" ? (lock ? .capslock : .shift) : .normal, width: keyWidth,
                height: height)
            case "symbol":
              SymbolKeyView(width: keyWidth, height: height)
            default:
              VStack {}.frame(width: keyWidth, height: height)
            }
          }
        }
      }.frame(width: width, height: height))
  }
}
