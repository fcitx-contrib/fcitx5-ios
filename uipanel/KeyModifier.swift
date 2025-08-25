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

private func getSwipeDirection(_ dx: CGFloat, _ dy: CGFloat) -> SwipeDirection {
  if abs(dx) > abs(dy) {
    return dx > 0 ? .right : .left
  }
  return dy > 0 ? .down : .up
}

private func clearBubble() {
  virtualKeyboardView.setBubble(0, 0, 0, 0, .clear, .clear, nil)
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

  let x: CGFloat
  let y: CGFloat
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
  let bubbleLabel: String?
  let swipeUpLabel: String?

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
            let bubbleX = x + width / 2
            let bubbleY = y + height / 2
            let bubbleWidth = width - columnGap
            let bubbleHeight = height - rowGap

            if startLocation == nil {
              startLocation = value.startLocation
              lastLocation = value.startLocation.x
              isPressed = true
              didTriggerLongPress = false
              didMoveFarEnough = false
              virtualKeyboardView.setBubble(
                bubbleX, bubbleY, bubbleWidth, bubbleHeight, background, shadow, bubbleLabel)

              // Schedule long press that can be interrupted by move.
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if isPressed && !didTriggerLongPress && !didMoveFarEnough {
                  didTriggerLongPress = true
                  clearBubble()
                  action.onLongPress?()
                }
              }
            } else {
              let dx = value.location.x - (startLocation?.x ?? 0)
              let dy = value.location.y - (startLocation?.y ?? 0)

              if !didTriggerLongPress {
                if !didMoveFarEnough && (abs(dx) > threshold || abs(dy) > threshold) {
                  didMoveFarEnough = true
                }
                if getSwipeDirection(dx, dy) == .up {
                  virtualKeyboardView.setBubble(
                    bubbleX, bubbleY, bubbleWidth, bubbleHeight, background, shadow, swipeUpLabel)
                } else {
                  clearBubble()
                }
              }
              // Process slide.
              if let onSlide = action.onSlide {
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
                      onSlide(delta)
                    }
                    lastLocation = value.location.x
                  }
                }
              }
            }
          }
          .onEnded { value in
            isPressed = false
            clearBubble()
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
    width: CGFloat, height: CGFloat, background: Color, pressedBackground: Color, foreground: Color,
    shadow: Color, action: GestureAction, pressedForeground: Color? = nil,
    pressedView: (any View)? = nil, topRight: String? = nil, bubbleLabel: String? = nil,
    swipeUpLabel: String? = nil
  ) -> some View {
    self.modifier(
      KeyModifier(
        x: x, y: y, width: width, height: height, background: background,
        pressedBackground: pressedBackground,
        foreground: foreground, pressedForeground: pressedForeground ?? foreground,
        shadow: shadow, action: action, pressedView: pressedView, topRight: topRight,
        bubbleLabel: bubbleLabel, swipeUpLabel: swipeUpLabel
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
