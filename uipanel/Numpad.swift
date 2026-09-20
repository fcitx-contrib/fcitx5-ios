import SwiftUI

private let numpadRows = [
  ["+", "1", "2", "3", "="],
  ["-", "4", "5", "6", "@"],
  ["*", "7", "8", "9", "backspace"],
  ["/", ",", "0", "spaceAndPeriod", "enter"],
]

private let numpadDigitCodes = [
  "0": "Numpad0",
  "1": "Numpad1",
  "2": "Numpad2",
  "3": "Numpad3",
  "4": "Numpad4",
  "5": "Numpad5",
  "6": "Numpad6",
  "7": "Numpad7",
  "8": "Numpad8",
  "9": "Numpad9",
]

struct NumpadView: View {
  @Environment(\.totalHeight) var totalHeight
  @ObservedObject var viewModel = vm

  let width: CGFloat

  var body: some View {
    let keyboardHeight = getKeyboardHeight(totalHeight)
    let keyHeight = keyboardHeight / 4
    let sideColumnWidth = width * 0.15
    let middleColumnWidth = (width - 2 * sideColumnWidth) / 3
    let columnWidths = [
      sideColumnWidth, middleColumnWidth, middleColumnWidth, middleColumnWidth, sideColumnWidth,
    ]
    let columnXs = columnWidths.partialSums()

    VStack(spacing: 0) {
      ToolbarView(width: width, showsBackButton: true)
      ZStack {
        ForEach(Array(numpadRows.joined().enumerated()), id: \.offset) { index, key in
          let column = index % 5
          let x = columnXs[column]
          let y = CGFloat(index / 5) * keyHeight
          let keyWidth = columnWidths[column]
          if key == "backspace" {
            BackspaceView(x: x, y: y, width: keyWidth, height: keyHeight)
          } else if key == "enter" {
            EnterView(
              x: x, y: y, width: keyWidth, height: keyHeight,
              label: viewModel.enterLabel, cr: viewModel.hasPreedit,
              disable: viewModel.textIsEmpty && viewModel.enterHighlight,
              highlight: viewModel.enterHighlight)
          } else if key == "spaceAndPeriod" {
            let splitKeyWidth = keyWidth / 2
            SpaceView(
              x: x, y: y, width: splitKeyWidth, height: keyHeight,
              label: "", forward: true)
            KeyView(
              x: x + splitKeyWidth, y: y, width: splitKeyWidth, height: keyHeight,
              label: ".", key: ".", code: "", forward: true, subLabel: nil, swipeUp: nil,
              longPress: nil)
          } else {
            KeyView(
              x: x, y: y, width: keyWidth, height: keyHeight,
              label: key, key: key, code: numpadDigitCodes[key] ?? "", forward: true,
              subLabel: nil, swipeUp: nil, longPress: nil)
          }
        }
        if !viewModel.bubbleItems.isEmpty {
          BubbleView(
            x: viewModel.bubbleX,
            y: viewModel.bubbleY,
            width: viewModel.bubbleWidth,
            height: viewModel.bubbleHeight,
            keyboardWidth: width,
            background: viewModel.bubbleBackground,
            shadow: viewModel.bubbleShadow,
            label: viewModel.bubbleLabel,
            items: viewModel.bubbleItems,
            index: viewModel.bubbleIndex,
            highlight: viewModel.bubbleHighlight,
            fontSize: viewModel.bubbleFontSize)
        }
      }.frame(width: width, height: keyboardHeight)
    }
  }
}
