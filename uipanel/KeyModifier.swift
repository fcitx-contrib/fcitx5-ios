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
  vm.setBubble(0, 0, 0, 0, .clear, .light, .clear, nil, [], 0, 0, nil)
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
  let bubbleBackground: Color?
  let bubbleFontSize: CGFloat?
  let pressedBackground: Color
  let foreground: Color
  let pressedForeground: Color
  let shadow: Color
  let action: GestureAction
  let disable: Bool
  let pressedView: (any View)?
  let topRight: String?
  let bubbleLabel: String?
  let swipeUpLabel: String?
  let longPressItems: [BubbleItem]
  let longPressIndex: Int
  var bubbleX: CGFloat { x + width / 2 }
  var bubbleY: CGFloat { y + height / 2 }
  var bubbleWidth: CGFloat { width - hMargin }
  var bubbleHeight: CGFloat { height - rowGap }

  private func cancelOrderedKeyPress() {
    if let id = orderedKeyPressId {
      vm.removeOrderedKeyPress(id)
      orderedKeyPressId = nil
    }
  }

  private func processedByAnotherKeyPress() -> Bool {
    if let id = orderedKeyPressId, vm.orderedKeyPressWasSent(id) {
      return true
    }
    return false
  }

  private func isDoubleTap(_ touchTime: Date) -> Bool {
    if action.onDoubleTap != nil, let t = lastTouchTime,
      touchTime.timeIntervalSince(t) < 0.3
    {
      return true
    }
    return false
  }

  private func onTimer(_ currentTouchId: Int) {
    if touchId != currentTouchId {
      // Called from a previous touch.
      return
    }
    if processedByAnotherKeyPress() {
      return
    }
    if isPressed && !didTriggerLongPress && !didMoveFarEnough {
      cancelOrderedKeyPress()
      didTriggerLongPress = true
      if longPressIndex >= 0 && longPressIndex < longPressItems.count {
        bubbleHighlight = longPressIndex
        vm.setBubble(
          bubbleX, bubbleY, bubbleWidth, bubbleHeight,
          bubbleBackground ?? background, colorScheme, shadow, nil, longPressItems, longPressIndex,
          bubbleHighlight, bubbleFontSize)
      } else {
        clearBubble()
        action.onLongPress?(0)
      }
    }
  }

  private func onTouchStart(_ location: CGPoint) {
    if disable {
      return
    }
    let touchTime = Date()
    touchId = (touchId + 1) & 0xFFFF
    let currentTouchId = touchId
    isPressed = true
    startLocation = location
    lastLocation = location.x

    vm.setBubble(
      bubbleX, bubbleY, bubbleWidth, bubbleHeight,
      bubbleBackground ?? background, colorScheme, shadow,
      bubbleLabel, [], 0, 0, bubbleFontSize)

    vm.flushOrderedKeyPresses()
    if isDoubleTap(touchTime) {
      lastTouchTime = nil
      action.onDoubleTap?()
    } else {  // Single tap
      lastTouchTime = touchTime
      if let onOrderedKeyPress = action.onOrderedKeyPress {  // Normal keys
        orderedKeyPressId = vm.beginOrderedKeyPress(onOrderedKeyPress())
      } else {  // Shift
        action.onPress?()
      }
    }

    // Schedule long press that can be interrupted by move.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
      onTimer(currentTouchId)
    }
  }

  private func onTouchMove(_ location: CGPoint) {
    if disable {
      return
    }
    if processedByAnotherKeyPress() {
      return
    }

    let dx = location.x - (startLocation?.x ?? 0)
    let dy = location.y - (startLocation?.y ?? 0)

    if !didTriggerLongPress {
      if !didMoveFarEnough && (abs(dx) > threshold || abs(dy) > threshold) {
        didMoveFarEnough = true
        cancelOrderedKeyPress()
      }
      if didMoveFarEnough {
        if getSwipeDirection(dx, dy) == .up {
          vm.setBubble(
            bubbleX, bubbleY, bubbleWidth, bubbleHeight, bubbleBackground ?? background,
            colorScheme, shadow, swipeUpLabel, [], 0, 0, bubbleFontSize)
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
    } else if didTriggerLongPress && longPressItems.count > 1, let last = lastLocation {
      let delta = getNStep(last, location.x, moveSize)
      if delta != 0 {
        bubbleHighlight = max(
          0, min(bubbleHighlight + delta, longPressItems.count - 1))
        vm.setBubble(
          bubbleX, bubbleY, bubbleWidth, bubbleHeight,
          bubbleBackground ?? background, colorScheme, shadow, nil, longPressItems, longPressIndex,
          bubbleHighlight, bubbleFontSize)
        lastLocation = last + CGFloat(delta) * moveSize
      }
    }
  }

  private func onTouchEnd(_ location: CGPoint) {
    clearBubble()
    defer {
      cancelOrderedKeyPress()
      action.onRelease?()
      isPressed = false
      startLocation = nil
      lastLocation = nil
      didTriggerLongPress = false
      didMoveFarEnough = false
      slideActivated = false
      bubbleHighlight = 0
    }

    if disable {
      return
    }

    if processedByAnotherKeyPress() {
      return
    }

    let dx = location.x - (startLocation?.x ?? 0)
    let dy = location.y - (startLocation?.y ?? 0)

    if slideActivated {
      if let onSlide = action.onSlide {
        onSlide(0)
        return
      }
    }

    if didTriggerLongPress && bubbleHighlight >= 0
      && bubbleHighlight < longPressItems.count
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
        if let id = orderedKeyPressId {
          vm.releaseOrderedKeyPress(id)
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
    swipeUpLabel: String? = nil, longPressItems: [BubbleItem]? = nil, longPressIndex: Int? = nil,
    bubbleBackground: Color? = nil, bubbleFontSize: CGFloat? = nil, disable: Bool = false
  ) -> some View {
    self.modifier(
      KeyModifier(
        x: x, y: y, width: width, height: height, hMargin: hMargin, vMargin: vMargin,
        radius: radius,
        background: background, bubbleBackground: bubbleBackground,
        bubbleFontSize: bubbleFontSize, pressedBackground: pressedBackground,
        foreground: foreground, pressedForeground: pressedForeground ?? foreground,
        shadow: shadow, action: action, disable: disable, pressedView: pressedView,
        topRight: topRight,
        bubbleLabel: bubbleLabel, swipeUpLabel: swipeUpLabel,
        longPressItems: longPressItems ?? [],
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
