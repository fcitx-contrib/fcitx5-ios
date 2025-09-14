import SwiftUI
import SwiftUtil

struct GestureAction {
  var onTap: (() -> Void)? = nil
  var onLongPress: ((Int) -> Void)? = nil
  var onSwipe: ((SwipeDirection) -> Void)? = nil
  var onSlide: ((Int) -> Void)? = nil
  var onRelease: (() -> Void)? = nil
}

enum SwipeDirection {
  case up, down, left, right
}

private func getSwipeDirection(_ dx: CGFloat, _ dy: CGFloat) -> SwipeDirection {
  if abs(dx) > abs(dy) {
    return dx > 0 ? .right : .left
  }
  return dy > 0 ? .down : .up
}

private func getNStep(_ start: CGFloat, _ end: CGFloat, _ step: CGFloat) -> Int {
  return (start < end ? 1 : -1) * Int(floor(abs(end - start) / step))
}

private func clearBubble() {
  virtualKeyboardView.setBubble(0, 0, 0, 0, .clear, .light, .clear, nil, [], 0, 0)
}

struct KeyModifier: ViewModifier {
  @Environment(\.colorScheme) var colorScheme

  let threshold: CGFloat = 30
  let stepSize: CGFloat = 15
  let moveSize: CGFloat = 30

  @State private var touchId = 0
  @State private var isPressed = false
  @State private var startLocation: CGPoint?
  @State private var lastLocation: CGFloat?
  @State private var didTriggerLongPress = false
  @State private var didMoveFarEnough = false
  @State private var didTriggerSwipe = false
  @State private var slideActivated = false
  @State private var bubbleHighlight = 0

  let x: CGFloat
  let y: CGFloat
  let width: CGFloat
  let height: CGFloat
  let hMargin: CGFloat
  let vMargin: CGFloat
  let radius: CGFloat
  let background: Color
  let pressedBackground: Color
  let foreground: Color
  let pressedForeground: Color
  let shadow: Color
  let action: GestureAction
  let pressedView: (any View)?
  let topRight: String?
  let bubbleLabel: String?
  let swipeUpLabel: String?
  let longPressLabels: [String]
  let longPressIndex: Int

  func body(content: Content) -> some View {
    VStack {
      if isPressed, let pressedView = pressedView {
        AnyView(pressedView)
      } else {
        content
      }
    }.frame(width: width - hMargin, height: height - vMargin)
      .background(isPressed ? pressedBackground : background)
      .cornerRadius(radius)
      .foregroundColor(isPressed ? pressedForeground : foreground)
      .overlay(
        ShadowView(width: width - hMargin, height: 1, radius: radius, color: shadow)
          .offset(y: (height - vMargin - radius + 1) / 2)
      )
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
            let bubbleX = x + width / 2
            let bubbleY = y + height / 2
            let bubbleWidth = width - hMargin
            let bubbleHeight = height - rowGap

            if !isPressed {  // touch start
              touchId = (touchId + 1) & 0xFFFF
              let currentTouchId = touchId
              isPressed = true
              startLocation = value.startLocation
              lastLocation = value.startLocation.x

              virtualKeyboardView.setBubble(
                bubbleX, bubbleY, bubbleWidth, bubbleHeight,
                background, colorScheme, shadow,
                bubbleLabel, [], 0, 0)

              // Schedule long press that can be interrupted by move.
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if touchId != currentTouchId {
                  // Called from a previous touch.
                  return
                }
                if isPressed && !didTriggerSwipe && !didTriggerLongPress && !didMoveFarEnough {
                  didTriggerLongPress = true
                  if longPressIndex >= 0 && longPressIndex < longPressLabels.count {
                    bubbleHighlight = longPressIndex
                    virtualKeyboardView.setBubble(
                      bubbleX, bubbleY, bubbleWidth, bubbleHeight,
                      background, colorScheme, shadow, nil, longPressLabels, longPressIndex,
                      bubbleHighlight)
                  } else {
                    clearBubble()
                    action.onLongPress?(0)
                  }
                }
              }
            } else {  // touch move
              let dx = value.location.x - (startLocation?.x ?? 0)
              let dy = value.location.y - (startLocation?.y ?? 0)

              if !didTriggerLongPress {
                if !didMoveFarEnough && (abs(dx) > threshold || abs(dy) > threshold) {
                  didMoveFarEnough = true
                  didTriggerSwipe = true
                }
                if didMoveFarEnough {
                  if getSwipeDirection(dx, dy) == .up {
                    virtualKeyboardView.setBubble(
                      bubbleX, bubbleY, bubbleWidth, bubbleHeight, background, colorScheme,
                      shadow, swipeUpLabel, [], 0, 0)
                  } else {
                    clearBubble()
                  }
                }
              }
              // Process slide and long press + move.
              if let onSlide = action.onSlide {
                if !slideActivated {
                  if abs(dx) >= threshold, let start = startLocation {
                    slideActivated = true
                    lastLocation = start.x + (dx > 0 ? threshold : -threshold)
                  }
                }
                if slideActivated {
                  if let start = startLocation, let last = lastLocation {
                    let totalPast = getNStep(start.x, last, stepSize)
                    let totalNow = getNStep(start.x, value.location.x, stepSize)
                    let delta = totalNow - totalPast
                    if delta != 0 {
                      onSlide(delta)
                    }
                    lastLocation = value.location.x
                  }
                }
              } else if didTriggerLongPress && longPressLabels.count > 1, let last = lastLocation {
                let delta = getNStep(last, value.location.x, moveSize)
                if delta != 0 {
                  bubbleHighlight = max(
                    0, min(bubbleHighlight + delta, longPressLabels.count - 1))
                  virtualKeyboardView.setBubble(
                    bubbleX, bubbleY, bubbleWidth, bubbleHeight,
                    background, colorScheme, shadow, nil, longPressLabels, longPressIndex,
                    bubbleHighlight)
                  lastLocation = (lastLocation ?? 0) + CGFloat(delta) * moveSize
                }
              }
            }
          }
          .onEnded { value in
            clearBubble()
            defer {
              action.onRelease?()
              isPressed = false
              startLocation = nil
              lastLocation = nil
              didTriggerLongPress = false
              didMoveFarEnough = false
              didTriggerSwipe = false
              slideActivated = false
              bubbleHighlight = 0
            }

            let dx = value.location.x - (startLocation?.x ?? 0)
            let dy = value.location.y - (startLocation?.y ?? 0)

            if slideActivated {
              if let onSlide = action.onSlide {
                onSlide(0)
                return
              }
            }

            if !didTriggerSwipe && didTriggerLongPress && bubbleHighlight >= 0
              && bubbleHighlight < longPressLabels.count
            {
              action.onLongPress?(bubbleHighlight)
              return
            }

            if didMoveFarEnough {
              if !didTriggerLongPress {
                action.onSwipe?(getSwipeDirection(dx, dy))
              }
            } else {
              if !didTriggerLongPress {
                action.onTap?()
              }
            }
          }
      ).position(x: x + width / 2, y: y + height / 2)
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
    x: CGFloat = 0, y: CGFloat = 0,
    width: CGFloat, height: CGFloat, hMargin: CGFloat = columnGap, vMargin: CGFloat = rowGap,
    radius: CGFloat = keyCornerRadius, background: Color, pressedBackground: Color,
    foreground: Color, shadow: Color, action: GestureAction, pressedForeground: Color? = nil,
    pressedView: (any View)? = nil, topRight: String? = nil, bubbleLabel: String? = nil,
    swipeUpLabel: String? = nil, longPressLabels: [String]? = nil, longPressIndex: Int? = nil
  ) -> some View {
    self.modifier(
      KeyModifier(
        x: x, y: y, width: width, height: height, hMargin: hMargin, vMargin: vMargin,
        radius: radius,
        background: background, pressedBackground: pressedBackground,
        foreground: foreground, pressedForeground: pressedForeground ?? foreground,
        shadow: shadow, action: action, pressedView: pressedView, topRight: topRight,
        bubbleLabel: bubbleLabel, swipeUpLabel: swipeUpLabel,
        longPressLabels: longPressLabels ?? [],
        longPressIndex: longPressIndex ?? 0
      )
    )
  }
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
