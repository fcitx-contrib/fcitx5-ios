import SwiftUI

struct GestureAction {
  var onTap: (() -> Void)? = nil
  var onLongPress: (() -> Void)? = nil
  var onSwipe: ((SwipeDirection) -> Void)? = nil
}

enum SwipeDirection {
  case up, down, left, right
}

struct KeyModifier: ViewModifier {
  @State private var isPressed = false
  @State private var didTriggerLongPress = false
  @State private var didMoveFarEnough = false
  @State private var startLocation: CGPoint?

  let width: CGFloat
  let height: CGFloat
  let background: Color
  let press: Color
  let foreground: Color
  let shadow: Color
  let action: GestureAction

  func body(content: Content) -> some View {
    content
      .frame(width: width - columnGap, height: height - rowGap)
      .background(isPressed ? press : background)
      .cornerRadius(keyCornerRadius)
      .foregroundColor(foreground)
      .overlay(
        RoundedRectangle(cornerRadius: keyCornerRadius)
          .stroke(Color.clear, lineWidth: 0)
      )
      .shadow(color: shadow, radius: 0, x: 0, y: 1)
      .frame(width: width, height: height)
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            if startLocation == nil {
              startLocation = value.startLocation
              isPressed = true
              didTriggerLongPress = false
              didMoveFarEnough = false

              DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if isPressed && !didTriggerLongPress && !didMoveFarEnough {
                  didTriggerLongPress = true
                  action.onLongPress?()
                }
              }
            } else if !didTriggerLongPress && !didMoveFarEnough {
              let dx = value.location.x - (startLocation?.x ?? 0)
              let dy = value.location.y - (startLocation?.y ?? 0)
              let threshold: CGFloat = 10

              if abs(dx) > threshold || abs(dy) > threshold {
                didMoveFarEnough = true
              }
            }
          }
          .onEnded { value in
            isPressed = false
            defer { startLocation = nil }

            let dx = value.location.x - (startLocation?.x ?? 0)
            let dy = value.location.y - (startLocation?.y ?? 0)
            let threshold: CGFloat = 30

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
  func keyProperties(
    width: CGFloat, height: CGFloat, background: Color, press: Color, foreground: Color,
    shadow: Color, action: GestureAction
  ) -> some View {
    self.modifier(
      KeyModifier(
        width: width, height: height, background: background, press: press, foreground: foreground,
        shadow: shadow, action: action))
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

struct KeyView: View {
  @Environment(\.colorScheme) var colorScheme
  let label: String
  let key: String
  let width: CGFloat
  let height: CGFloat

  var body: some View {
    Button {
      virtualKeyboardView.resetLayerIfNotLocked()
      client.keyPressed(key, "")
    } label: {
      Text(label)
        .font(.system(size: height * 0.5).weight(.light))
        .commonContentStyle(
          width: width, height: height, background: getNormalBackground(colorScheme),
          foreground: getNormalForeground(colorScheme))
    }.commonContainerStyle(width: width, height: height, shadow: getShadow(colorScheme))
  }
}

struct SpaceView: View {
  @Environment(\.colorScheme) var colorScheme
  let label: String
  let width: CGFloat
  let height: CGFloat

  var body: some View {
    Button {
      virtualKeyboardView.resetLayerIfNotLocked()
      client.keyPressed(" ", "")
    } label: {
      Text(label)
        .font(.system(size: height * 0.4))
        .commonContentStyle(
          width: width, height: height, background: getNormalBackground(colorScheme),
          foreground: getNormalForeground(colorScheme))
    }.commonContainerStyle(width: width, height: height, shadow: getShadow(colorScheme))
  }
}

struct BackspaceView: View {
  @Environment(\.colorScheme) var colorScheme
  let width: CGFloat
  let height: CGFloat

  var body: some View {
    Button {
      virtualKeyboardView.resetLayerIfNotLocked()
      client.keyPressed("", "Backspace")
    } label: {
      VStack {
        Image(systemName: "delete.left")
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(height: height * 0.4)
      }
      .commonContentStyle(
        width: width, height: height, background: getFunctionBackground(colorScheme),
        foreground: getNormalForeground(colorScheme))
    }.commonContainerStyle(width: width, height: height, shadow: getShadow(colorScheme))
  }
}

struct GlobeView: View {
  @Environment(\.colorScheme) var colorScheme
  let width: CGFloat
  let height: CGFloat

  var body: some View {
    GeometryReader { geometry in
      VStack {
        Image(systemName: "globe")
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(height: height * 0.45)
      }
      .keyProperties(
        width: width, height: height,
        background: getNormalBackground(colorScheme),
        press: getFunctionBackground(colorScheme),
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

  var body: some View {
    Button {
      virtualKeyboardView.resetLayerIfNotLocked()
      client.keyPressed("\r", "Enter")
    } label: {
      Text(label)
        .commonContentStyle(
          width: width, height: height, background: getFunctionBackground(colorScheme),
          foreground: getNormalForeground(colorScheme))
    }.commonContainerStyle(width: width, height: height, shadow: getShadow(colorScheme))
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
