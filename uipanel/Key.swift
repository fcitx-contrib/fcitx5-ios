import SwiftUI

extension View {
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
    Button {
      virtualKeyboardView.resetLayerIfNotLocked()
      client.globe()
    } label: {
      VStack {
        Image(systemName: "globe")
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(height: height * 0.45)
      }.commonContentStyle(
        width: width, height: height, background: getNormalBackground(colorScheme),
        foreground: getNormalForeground(colorScheme))
    }.commonContainerStyle(width: width, height: height, shadow: getShadow(colorScheme))
      .contextMenu {
        ForEach(virtualKeyboardView.viewModel.inputMethods, id: \.name) { inputMethod in
          Button {
            virtualKeyboardView.resetLayerIfNotLocked()
            client.setCurrentInputMethod(inputMethod.name)
          } label: {
            Text(inputMethod.displayName)
          }
        }
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
