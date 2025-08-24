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

extension Array where Element == CGFloat {
  func partialSums() -> [CGFloat] {
    var result: [CGFloat] = [0]
    result.reserveCapacity(self.count)

    var running: CGFloat = 0
    for x in self.dropLast() {
      running += x
      result.append(running)
    }
    return result
  }
}

struct KeyboardView: View {
  let width: CGFloat
  let layer: String
  let lock: Bool
  let spaceLabel: String
  let enterLabel: String
  let textIsEmpty: Bool
  let enterHighlight: Bool
  let hasPreedit: Bool
  @State private var defaultRows = [[String: Any]]()
  @State private var shiftRows = [[String: Any]]()

  var body: some View {
    let rows = layer == "shift" ? shiftRows : defaultRows
    let height = keyboardHeight / CGFloat(rows.count)
    ZStack {
      ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
        renderRow(row, CGFloat(i) * height, width, height)
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

  func renderRow(_ row: [String: Any], _ y: CGFloat, _ width: CGFloat, _ height: CGFloat)
    -> some View
  {
    guard let keys = row["keys"] as? [[String: Any]] else {
      return AnyView(EmptyView())
    }
    let flexes = getFlexes(keys)
    let flexSums = flexes.partialSums()
    let unit = width / flexes.reduce(0, +)
    return AnyView(
      ForEach(Array(keys.enumerated()), id: \.offset) { i, key in
        let keyWidth = flexes[i] * unit
        let x = flexSums[i] * unit
        if let type = key["type"] as? String {
          switch type {
          case "key":
            if let label = key["label"] as? String,
              let k = key["key"] as? String
            {
              let subLabel = key["subLabel"] as? [String: String]
              let swipeUp = key["swipeUp"] as? [String: Any]
              KeyView(
                x: x, y: y, width: keyWidth, height: height,
                label: label, key: k, subLabel: subLabel, swipeUp: swipeUp)
            }
          case "space":
            SpaceView(x: x, y: y, width: keyWidth, height: height, label: spaceLabel)
          case "backspace":
            BackspaceView(x: x, y: y, width: keyWidth, height: height)
          case "globe":
            GlobeView(x: x, y: y, width: keyWidth, height: height)
          case "enter":
            EnterView(
              x: x, y: y, width: keyWidth, height: height,
              label: enterLabel, cr: hasPreedit,
              disable: textIsEmpty && enterHighlight, highlight: enterHighlight)
          case "shift":
            ShiftView(
              x: x, y: y, width: keyWidth, height: height,
              state: layer == "shift" ? (lock ? .capslock : .shift) : .normal)
          case "symbol":
            SymbolKeyView(x: x, y: y, width: keyWidth, height: height)
          default:
            EmptyView()
          }
        }
      }
    )
  }
}
