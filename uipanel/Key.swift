import SwiftUI
import SwiftUtil

struct GestureAction {
  var onTap: (() -> Void)? = nil
  var onLongPress: (() -> Void)? = nil
  var onSwipe: ((SwipeDirection) -> Void)? = nil
  var onSlide: ((Int) -> Void)? = nil
}

enum SwipeDirection {
  case up, down, left, right
}

struct KeyModifier: ViewModifier {
  let threshold: CGFloat = 30
  let stepSize: CGFloat = 15

  @State private var isPressed = false
  @State private var didTriggerLongPress = false
  @State private var didMoveFarEnough = false
  @State private var startLocation: CGPoint?
  @State private var lastLocation: CGFloat?
  @State private var slideActivated = false

  let width: CGFloat
  let height: CGFloat
  let background: Color
  let pressedBackground: Color
  let foreground: Color
  let pressedForeground: Color
  let shadow: Color
  let action: GestureAction
  let pressedView: (any View)?
  let topRight: String?

  func body(content: Content) -> some View {
    VStack {
      if isPressed, let pressedView = pressedView {
        AnyView(pressedView)
      } else {
        content
      }
    }.frame(width: width - columnGap, height: height - rowGap)
      .background(isPressed ? pressedBackground : background)
      .cornerRadius(keyCornerRadius)
      .foregroundColor(isPressed ? pressedForeground : foreground)
      .shadow(color: shadow, radius: 0, x: 0, y: 1)
      .condition(topRight != nil) {
        $0.overlay(
          // padding right so that / doesn't overflow
          Text(topRight ?? "").font(.system(size: height * 0.25)).padding(.trailing, 1),
          alignment: .topTrailing
        )
      }
      .frame(width: width, height: height)
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            if startLocation == nil {
              startLocation = value.startLocation
              lastLocation = value.startLocation.x
              isPressed = true
              didTriggerLongPress = false
              didMoveFarEnough = false

              // Schedule long press that can be interrupted by move.
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if isPressed && !didTriggerLongPress && !didMoveFarEnough {
                  didTriggerLongPress = true
                  action.onLongPress?()
                }
              }
            } else {
              let dx = value.location.x - (startLocation?.x ?? 0)
              let dy = value.location.y - (startLocation?.y ?? 0)

              if !didTriggerLongPress && !didMoveFarEnough {
                if abs(dx) > threshold || abs(dy) > threshold {
                  didMoveFarEnough = true
                }
              }
              // Process slide.
              if !slideActivated {
                if abs(dx) >= threshold, let start = startLocation {
                  slideActivated = true
                  lastLocation = start.x + (dx > 0 ? threshold : -threshold)
                }
              }
              if slideActivated {
                if let start = startLocation, let last = lastLocation {
                  let totalPast = Int(floor((last - start.x) / stepSize))
                  let totalNow = Int(floor((value.location.x - start.x) / stepSize))
                  let delta = totalNow - totalPast
                  if delta != 0 {
                    action.onSlide?(delta)
                  }
                  lastLocation = value.location.x
                }
              }
            }
          }
          .onEnded { value in
            isPressed = false
            defer {
              startLocation = nil
              lastLocation = nil
              slideActivated = false
            }

            let dx = value.location.x - (startLocation?.x ?? 0)
            let dy = value.location.y - (startLocation?.y ?? 0)

            if slideActivated {
              if let onSlide = action.onSlide {
                onSlide(0)
                return
              }
            }

            if didMoveFarEnough {
              if !didTriggerLongPress {
                if abs(dx) > abs(dy) {
                  action.onSwipe?(dx > 0 ? .right : .left)
                } else {
                  action.onSwipe?(dy > 0 ? .down : .up)
                }
              }
            } else {
              if !didTriggerLongPress {
                action.onTap?()
              }
            }
          }
      )
  }
}

extension View {
  @ViewBuilder
  func condition<Content: View>(
    _ isActive: Bool,
    transform: (Self) -> Content
  ) -> some View {
    if isActive {
      transform(self)
    } else {
      self
    }
  }

  func keyProperties(
    width: CGFloat, height: CGFloat, background: Color, pressedBackground: Color, foreground: Color,
    shadow: Color, action: GestureAction, pressedForeground: Color? = nil,
    pressedView: (any View)? = nil, topRight: String? = nil
  ) -> some View {
    self.modifier(
      KeyModifier(
        width: width, height: height, background: background, pressedBackground: pressedBackground,
        foreground: foreground, pressedForeground: pressedForeground ?? foreground,
        shadow: shadow, action: action, pressedView: pressedView, topRight: topRight
      )
    )
  }

  func commonContentStyle(width: CGFloat, height: CGFloat, background: Color, foreground: Color)
    -> some View
  {
    self.frame(width: width - columnGap, height: height - rowGap)
      .background(background)
      .cornerRadius(keyCornerRadius)
      .foregroundColor(foreground)
      .overlay(
        RoundedRectangle(cornerRadius: keyCornerRadius)
          .stroke(Color.clear, lineWidth: 0)
      )
  }

  func commonContainerStyle(width: CGFloat, height: CGFloat, shadow: Color) -> some View {
    self.shadow(color: shadow, radius: 0, x: 0, y: 1)
      .frame(width: width, height: height)
  }
}

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

func executeActions(_ actions: [[String: String]]) {
  for action in actions {
    if let type = action["type"] {
      switch type {
      case "key":
        let key = action["key"] ?? ""
        let code = action["code"] ?? ""
        client.keyPressed(key, code)
      default:
        logger.error("Unknown action type: \(type)")
      }
    }
  }
}

struct KeyView: View {
  @Environment(\.colorScheme) var colorScheme
  let label: String
  let key: String
  let subLabel: [String: String]?
  let swipeUp: [String: Any]?
  let width: CGFloat
  let height: CGFloat

  var body: some View {
    Text(label)
      .font(.system(size: height * 0.5).weight(.light))
      .keyProperties(
        width: width, height: height,
        background: getNormalBackground(colorScheme),
        pressedBackground: getFunctionBackground(colorScheme),
        foreground: getNormalForeground(colorScheme),
        shadow: getShadow(colorScheme),
        action: GestureAction(
          onTap: {
            virtualKeyboardView.resetLayerIfNotLocked()
            client.keyPressed(key, "")
          },
          onSwipe: { direction in
            if direction == .up, let swipeUp = swipeUp,
              let actions = swipeUp["actions"] as? [[String: String]]
            {
              executeActions(actions)
            }
          }
        ),
        topRight: subLabel?["topRight"] as? String
      )
  }
}

struct SpaceView: View {
  @Environment(\.colorScheme) var colorScheme
  let label: String
  let width: CGFloat
  let height: CGFloat

  var body: some View {
    Text(label)
      .font(.system(size: height * 0.4))
      .keyProperties(
        width: width, height: height,
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
              for i in 0..<step {
                client.keyPressed("", "ArrowRight")
              }
            } else {
              for i in 0..<(-step) {
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
  let width: CGFloat
  let height: CGFloat

  var body: some View {
    Image(systemName: "delete.left")
      .resizable()
      .aspectRatio(contentMode: .fit)
      .frame(height: height * 0.4)
      .keyProperties(
        width: width, height: height,
        background: getFunctionBackground(colorScheme),
        pressedBackground: getNormalBackground(colorScheme),
        foreground: getNormalForeground(colorScheme),
        shadow: getShadow(colorScheme),
        action: GestureAction(
          onTap: {
            virtualKeyboardView.resetLayerIfNotLocked()
            client.keyPressed("", "Backspace")
          },
          onSlide: { step in
            virtualKeyboardView.slideBackspace(step)
          }
        ),
        pressedView: Image(systemName: "delete.left.fill")
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(height: height * 0.4)
      )
  }
}

struct GlobeView: View {
  @Environment(\.colorScheme) var colorScheme
  let width: CGFloat
  let height: CGFloat

  var body: some View {
    GeometryReader { geometry in
      Image(systemName: "globe")
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(height: height * 0.45)
        .keyProperties(
          width: width, height: height,
          background: getNormalBackground(colorScheme),
          pressedBackground: getFunctionBackground(colorScheme),
          foreground: getNormalForeground(colorScheme),
          shadow: getShadow(colorScheme),
          action: GestureAction(
            onTap: {
              virtualKeyboardView.resetLayerIfNotLocked()
              client.globe()
            },
            onLongPress: {
              let items = virtualKeyboardView.viewModel.inputMethods.map { inputMethod in
                MenuItem(
                  text: inputMethod.displayName,
                  action: {
                    virtualKeyboardView.resetLayerIfNotLocked()
                    client.setCurrentInputMethod(inputMethod.name)
                  })
              }
              if !items.isEmpty {
                let frame = geometry.frame(in: .global)
                virtualKeyboardView.showContextMenu(frame, items)
              }
            }
          )
        )
    }
  }
}

struct EnterView: View {
  @Environment(\.colorScheme) var colorScheme
  let label: String
  let width: CGFloat
  let height: CGFloat
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
        Text(label)
      }
    }
    .keyProperties(
      width: width, height: height,
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
  let state: ShiftState
  let width: CGFloat
  let height: CGFloat

  var body: some View {
    Button {
      virtualKeyboardView.setLayer(
        state == .normal ? "shift" : "default"
      )
    } label: {
      VStack {
        Image(
          systemName: state == .normal ? "shift" : state == .shift ? "shift.fill" : "capslock.fill"
        )
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(height: height * 0.4)
      }.commonContentStyle(
        width: width, height: height, background: getFunctionBackground(colorScheme),
        foreground: getNormalForeground(colorScheme))
    }.commonContainerStyle(width: width, height: height, shadow: getShadow(colorScheme))
  }
}

struct SymbolKeyView: View {
  @Environment(\.colorScheme) var colorScheme
  let width: CGFloat
  let height: CGFloat

  var body: some View {
    Button {
      virtualKeyboardView.setDisplayMode(.symbol)
    } label: {
      Text("#+=")
        .commonContentStyle(
          width: width, height: height, background: getFunctionBackground(colorScheme),
          foreground: getNormalForeground(colorScheme))
    }.commonContainerStyle(width: width, height: height, shadow: getShadow(colorScheme))
  }
}
