import SwiftUI
import SwiftUtil

struct GestureAction {
  var onOrderedKeyPress: (() -> (() -> Void))? = nil
  var onPress: (() -> Void)? = nil
  var onTap: (() -> Void)? = nil
  var onDoubleTap: (() -> Void)? = nil
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

@MainActor
private func clearBubble() {
  vm.setBubble(0, 0, 0, 0, .clear, .light, .clear, nil, [], 0, 0)
}

struct KeyModifier: ViewModifier {
  @Environment(\.colorScheme) var colorScheme

  let threshold: CGFloat = 30
  let stepSize: CGFloat = 15
  let moveSize: CGFloat = 30

  @State private var touchId = 0
  @State private var lastTouchTime: Date?
  @State private var isPressed = false
  @State private var startLocation: CGPoint?
  @State private var lastLocation: CGFloat?
  @State private var didTriggerLongPress = false
  @State private var didMoveFarEnough = false
  @State private var slideActivated = false
  @State private var bubbleHighlight = 0
  @State private var orderedKeyPressId: Int?

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
  var bubbleX: CGFloat { x + width / 2 }
  var bubbleY: CGFloat { y + height / 2 }
  var bubbleWidth: CGFloat { width - hMargin }
  var bubbleHeight: CGFloat { height - rowGap }

  private func onTimer(_ currentTouchId: Int) {
    if touchId != currentTouchId {
      // Called from a previous touch.
      return
    }
    if isPressed && !didTriggerLongPress && !didMoveFarEnough {
      if let orderedKeyPressId {
        if vm.orderedKeyPressWasSent(orderedKeyPressId) {
          return
        }
        vm.removeOrderedKeyPress(orderedKeyPressId)
        self.orderedKeyPressId = nil
      }
      didTriggerLongPress = true
      if longPressIndex >= 0 && longPressIndex < longPressLabels.count {
        bubbleHighlight = longPressIndex
        vm.setBubble(
          bubbleX, bubbleY, bubbleWidth, bubbleHeight,
          background, colorScheme, shadow, nil, longPressLabels, longPressIndex,
          bubbleHighlight)
      } else {
        clearBubble()
        action.onLongPress?(0)
      }
    }
  }

  private func onTouchStart(_ location: CGPoint) {
    let touchTime = Date()
    touchId = (touchId + 1) & 0xFFFF
    let currentTouchId = touchId
    isPressed = true
    startLocation = location
    lastLocation = location.x

    vm.setBubble(
      bubbleX, bubbleY, bubbleWidth, bubbleHeight,
      background, colorScheme, shadow,
      bubbleLabel, [], 0, 0)

    vm.flushOrderedKeyPresses()
    if let t = lastTouchTime, let onDoubleTap = action.onDoubleTap,
      touchTime.timeIntervalSince(t) < 0.3
    {
      onDoubleTap()
      lastTouchTime = nil
    } else if let onOrderedKeyPress = action.onOrderedKeyPress {
      orderedKeyPressId = vm.beginOrderedKeyPress(onOrderedKeyPress())
      lastTouchTime = touchTime
    } else {
      action.onPress?()
      lastTouchTime = touchTime
    }

    // Schedule long press that can be interrupted by move.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
      onTimer(currentTouchId)
    }
  }

  private func onTouchMove(_ location: CGPoint) {
    // If action is already triggered by another key press, don't react with move.
    if let orderedKeyPressId,
      vm.orderedKeyPressWasSent(orderedKeyPressId)
    {
      return
    }

    let dx = location.x - (startLocation?.x ?? 0)
    let dy = location.y - (startLocation?.y ?? 0)

    if !didTriggerLongPress {
      if !didMoveFarEnough && (abs(dx) > threshold || abs(dy) > threshold) {
        didMoveFarEnough = true
        if let orderedKeyPressId {
          vm.removeOrderedKeyPress(orderedKeyPressId)
          self.orderedKeyPressId = nil
        }
      }
      if didMoveFarEnough {
        if getSwipeDirection(dx, dy) == .up {
          vm.setBubble(
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
          let totalNow = getNStep(start.x, location.x, stepSize)
          let delta = totalNow - totalPast
          if delta != 0 {
            onSlide(delta)
          }
          lastLocation = location.x
        }
      }
    } else if didTriggerLongPress && longPressLabels.count > 1, let last = lastLocation {
      let delta = getNStep(last, location.x, moveSize)
      if delta != 0 {
        bubbleHighlight = max(
          0, min(bubbleHighlight + delta, longPressLabels.count - 1))
        vm.setBubble(
          bubbleX, bubbleY, bubbleWidth, bubbleHeight,
          background, colorScheme, shadow, nil, longPressLabels, longPressIndex,
          bubbleHighlight)
        lastLocation = last + CGFloat(delta) * moveSize
      }
    }
  }

  private func onTouchEnd(_ location: CGPoint) {
    clearBubble()
    let currentOrderedKeyPressId = orderedKeyPressId
    let orderedKeyPressWasSent =
      currentOrderedKeyPressId.map { vm.orderedKeyPressWasSent($0) } ?? false
    defer {
      if let currentOrderedKeyPressId {
        vm.removeOrderedKeyPress(currentOrderedKeyPressId)
      }
      action.onRelease?()
      isPressed = false
      startLocation = nil
      lastLocation = nil
      didTriggerLongPress = false
      didMoveFarEnough = false
      slideActivated = false
      bubbleHighlight = 0
      orderedKeyPressId = nil
    }

    let dx = location.x - (startLocation?.x ?? 0)
    let dy = location.y - (startLocation?.y ?? 0)

    if orderedKeyPressWasSent {
      return
    }

    if slideActivated {
      if let onSlide = action.onSlide {
        onSlide(0)
        return
      }
    }

    if didTriggerLongPress && bubbleHighlight >= 0
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
        if let currentOrderedKeyPressId {
          vm.releaseOrderedKeyPress(currentOrderedKeyPressId)
          return
        }
        action.onTap?()
      }
    }
  }

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
            if !isPressed {
              onTouchStart(value.startLocation)
            } else {
              onTouchMove(value.location)
            }
          }
          .onEnded { value in
            onTouchEnd(value.location)
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

@MainActor
func executeActions(_ actions: [[String: String]]) {
  for action in actions {
    if let type = action["type"] {
      switch type {
      case "key":
        let key = action["key"] ?? ""
        let code = action["code"] ?? ""
        client.keyPressed(key, code)
      default:
        FCITX_ERROR("Unknown action type: \(type)")
      }
    }
  }
}
