import SwiftUI

func getNormalBackground(_ colorScheme: ColorScheme) -> Color {
  return colorScheme == .dark ? darkNormalBackground : lightNormalBackground
}

func getFunctionBackground(_ colorScheme: ColorScheme) -> Color {
  return colorScheme == .dark ? darkFunctionBackground : lightFunctionBackground
}

func getNormalForeground(_ colorScheme: ColorScheme) -> Color {
  return colorScheme == .dark ? Color.white : Color.black
}

func getShadow(_ colorScheme: ColorScheme) -> Color {
  return colorScheme == .dark ? darkShadow : lightShadow
}

func adjustFontSize(_ text: String, _ fontSize: CGFloat, _ widthLimit: CGFloat) -> CGFloat {
  let textWidth = getTextWidth(text, fontSize)
  return textWidth <= widthLimit ? fontSize : fontSize * widthLimit / textWidth
}

struct KeyView: View {
  @Environment(\.colorScheme) var colorScheme
  let x: CGFloat
  let y: CGFloat
  let width: CGFloat
  let height: CGFloat

  let label: String
  let key: String
  let subLabel: [String: String]?
  let swipeUp: [String: Any]?
  let longPress: [String: Any]?

  var body: some View {
    Text(label)
      .font(.system(size: height * 0.5).weight(.light))
      .keyProperties(
        x: x, y: y, width: width, height: height,
        background: getNormalBackground(colorScheme),
        pressedBackground: getFunctionBackground(colorScheme),
        foreground: getNormalForeground(colorScheme),
        shadow: getShadow(colorScheme),
        action: GestureAction(
          onTap: {
            virtualKeyboardView.resetLayerIfNotLocked()
            client.keyPressed(key, "")
          },
          onLongPress: { highlight in
            if let actionsList =
              ((longPress?["cells"] as? [[String: Any]])?.map {
                $0["actions"] as? [[String: String]]
              } as? [[[String: String]]]), highlight >= 0, highlight < actionsList.count
            {
              executeActions(actionsList[highlight])
            }
          },
          onSwipe: { direction in
            if direction == .up, let swipeUp = swipeUp,
              let actions = swipeUp["actions"] as? [[String: String]]
            {
              executeActions(actions)
            }
          }
        ),
        topRight: subLabel?["topRight"] as? String,
        bubbleLabel: label,
        swipeUpLabel: swipeUp?["label"] as? String,
        longPressLabels: (longPress?["cells"] as? [[String: Any]])?.map { $0["label"] as? String }
          as? [String],
        longPressIndex: longPress?["index"] as? Int
      )
  }
}

struct SpaceView: View {
  @Environment(\.colorScheme) var colorScheme
  let x: CGFloat
  let y: CGFloat
  let width: CGFloat
  let height: CGFloat

  let label: String

  var body: some View {
    Text(label)
      .font(.system(size: height * 0.4))
      .keyProperties(
        x: x, y: y, width: width, height: height,
        background: getNormalBackground(colorScheme),
        pressedBackground: getFunctionBackground(colorScheme),
        foreground: getNormalForeground(colorScheme),
        shadow: getShadow(colorScheme),
        action: GestureAction(
          onTap: {
            virtualKeyboardView.resetLayerIfNotLocked()
            client.keyPressed(" ", "")
          },
          onSlide: { step in
            if step > 0 {
              for _ in 0..<step {
                client.keyPressed("", "ArrowRight")
              }
            } else {
              for _ in 0..<(-step) {
                client.keyPressed("", "ArrowLeft")
              }
            }
          }
        )
      )
  }
}

struct BackspaceView: View {
  @Environment(\.colorScheme) var colorScheme
  let x: CGFloat
  let y: CGFloat
  let width: CGFloat
  let height: CGFloat
  var hMargin: CGFloat? = nil
  var vMargin: CGFloat? = nil
  var radius: CGFloat? = nil

  @State private var deleteTimer: Timer? = nil

  func startDelete() {
    stopDelete()
    deleteTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { _ in
      virtualKeyboardView.resetLayerIfNotLocked()
      client.keyPressed("", "Backspace")
    }
  }

  func stopDelete() {
    deleteTimer?.invalidate()
    deleteTimer = nil
  }

  var body: some View {
    Image(systemName: "delete.left")
      .resizable()
      .aspectRatio(contentMode: .fit)
      .frame(height: height * 0.4)
      .keyProperties(
        x: x, y: y, width: width, height: height,
        hMargin: hMargin ?? columnGap,
        vMargin: vMargin ?? rowGap,
        radius: radius ?? keyCornerRadius,
        background: getFunctionBackground(colorScheme),
        pressedBackground: getNormalBackground(colorScheme),
        foreground: getNormalForeground(colorScheme),
        shadow: getShadow(colorScheme),
        action: GestureAction(
          onTap: {
            virtualKeyboardView.resetLayerIfNotLocked()
            client.keyPressed("", "Backspace")
          },
          onLongPress: { _ in
            startDelete()
          },
          onSlide: { step in
            virtualKeyboardView.slideBackspace(step)
          },
          onRelease: {
            stopDelete()
          }
        ),
        pressedView: Image(systemName: "delete.left.fill")
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(height: height * 0.4)
      )
      .onDisappear {
        stopDelete()
      }
  }
}

struct GlobeView: View {
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.totalHeight) var totalHeight

  let x: CGFloat
  let y: CGFloat
  let width: CGFloat
  let height: CGFloat

  var body: some View {
    Image(systemName: "globe")
      .resizable()
      .aspectRatio(contentMode: .fit)
      .frame(height: height * 0.45)
      .keyProperties(
        x: x, y: y, width: width, height: height,
        background: getNormalBackground(colorScheme),
        pressedBackground: getFunctionBackground(colorScheme),
        foreground: getNormalForeground(colorScheme),
        shadow: getShadow(colorScheme),
        action: GestureAction(
          onTap: {
            virtualKeyboardView.resetLayerIfNotLocked()
            client.globe()
          },
          onLongPress: { _ in
            let items = virtualKeyboardView.viewModel.inputMethods.map { inputMethod in
              MenuItem(
                text: inputMethod.displayName,
                action: {
                  virtualKeyboardView.resetLayerIfNotLocked()
                  client.setCurrentInputMethod(inputMethod.name)
                })
            }
            if !items.isEmpty {
              let frame = CGRect(
                x: x, y: y + getBarHeight(totalHeight), width: width, height: height)
              virtualKeyboardView.showContextMenu(frame, items)
            }
          }
        )
      )
  }
}

struct EnterView: View {
  @Environment(\.colorScheme) var colorScheme
  let x: CGFloat
  let y: CGFloat
  let width: CGFloat
  let height: CGFloat

  let label: String
  let cr: Bool
  let disable: Bool
  let highlight: Bool

  var body: some View {
    VStack {
      if cr {
        Image(systemName: "return")
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(height: height * 0.4)
      } else {
        Text(label).font(
          .system(size: adjustFontSize(label, height * 0.32, (width - columnGap) * 0.95)))
      }
    }
    .keyProperties(
      x: x, y: y, width: width, height: height,
      background: !cr && !disable && highlight
        ? highlightBackground : getFunctionBackground(colorScheme),
      pressedBackground: !cr && disable
        ? getFunctionBackground(colorScheme) : getNormalBackground(colorScheme),
      foreground: !cr && disable
        ? disabledForeground
        : (!cr && highlight ? highlightForeground : getNormalForeground(colorScheme)),
      shadow: getShadow(colorScheme),
      action: GestureAction(
        onTap: {
          // When !cr && disable, still allow key press, because text empty detection is not reliable.
          // e.g. In WeChat when the first line is empty and caret is there and the second line is not empty,
          // it says text is empty but should be sendable.
          virtualKeyboardView.resetLayerIfNotLocked()
          client.keyPressed("\r", "Enter")
        }
      ),
      pressedForeground: !cr && !disable && highlight ? getNormalForeground(colorScheme) : nil
    )
  }
}

enum ShiftState {
  case normal
  case shift
  case capslock
}

struct ShiftView: View {
  @Environment(\.colorScheme) var colorScheme
  let x: CGFloat
  let y: CGFloat
  let width: CGFloat
  let height: CGFloat

  let state: ShiftState

  var body: some View {
    Image(
      systemName: state == .normal ? "shift" : state == .shift ? "shift.fill" : "capslock.fill"
    )
    .resizable()
    .aspectRatio(contentMode: .fit)
    .frame(height: height * 0.4)
    .keyProperties(
      x: x, y: y, width: width, height: height,
      background: getFunctionBackground(colorScheme),
      pressedBackground: getNormalBackground(colorScheme),
      foreground: getNormalForeground(colorScheme),
      shadow: getShadow(colorScheme),
      action: GestureAction(
        onPress: {
          virtualKeyboardView.setLayer(
            state == .normal ? "shift" : "default"
          )
        },
        onDoubleTap: {
          virtualKeyboardView.setLayer("shift", lock: true)
        }
      )
    )
  }
}

struct SymbolKeyView: View {
  @Environment(\.colorScheme) var colorScheme
  let x: CGFloat
  let y: CGFloat
  let width: CGFloat
  let height: CGFloat

  var body: some View {
    Text("#+=")
      .keyProperties(
        x: x, y: y, width: width, height: height,
        background: getFunctionBackground(colorScheme),
        pressedBackground: getNormalBackground(colorScheme),
        foreground: getNormalForeground(colorScheme),
        shadow: getShadow(colorScheme),
        action: GestureAction(
          onTap: {
            virtualKeyboardView.setDisplayMode(.symbol)
          }
        )
      )
  }
}
