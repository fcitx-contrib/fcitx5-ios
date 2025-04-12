import SwiftUI

extension View {
  func commonContentStyle(width: CGFloat, height: CGFloat, background: Color) -> some View {
    self.frame(width: width - columnGap, height: height - rowGap)
      .background(background)
      .cornerRadius(keyCornerRadius)
      .foregroundColor(.black)
      .overlay(
        RoundedRectangle(cornerRadius: keyCornerRadius)
          .stroke(Color.clear, lineWidth: 0)
      )
  }

  func commonContainerStyle(width: CGFloat, height: CGFloat) -> some View {
    self.shadow(color: Color.gray, radius: 0, x: 0, y: 1)
      .frame(width: width, height: height)
  }
}

struct KeyView: View {
  let label: String
  let key: String
  let width: CGFloat
  let height: CGFloat

  var body: some View {
    Button {
      client.keyPressed(key, "")
    } label: {
      Text(label)
        .font(.system(size: height * 0.5).weight(.light))
        .commonContentStyle(width: width, height: height, background: normalBackground)
    }.commonContainerStyle(width: width, height: height)
  }
}

struct SpaceView: View {
  let label: String
  let width: CGFloat
  let height: CGFloat

  var body: some View {
    Button {
      client.keyPressed(" ", "")
    } label: {
      Text(label)
        .font(.system(size: height * 0.4))
        .commonContentStyle(width: width, height: height, background: normalBackground)
    }.commonContainerStyle(width: width, height: height)
  }
}

struct BackspaceView: View {
  let width: CGFloat
  let height: CGFloat

  var body: some View {
    Button {
      client.keyPressed("", "Backspace")
    } label: {
      VStack {
        Image(systemName: "delete.left")
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(height: height * 0.4)
      }
      .commonContentStyle(width: width, height: height, background: functionBackground)
    }.commonContainerStyle(width: width, height: height)
  }
}

struct GlobeView: View {
  let width: CGFloat
  let height: CGFloat

  var body: some View {
    Button {
      client.globe()
    } label: {
      VStack {
        Image(systemName: "globe")
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(height: height * 0.45)
      }.commonContentStyle(width: width, height: height, background: normalBackground)
    }.commonContainerStyle(width: width, height: height)
      .contextMenu {
        ForEach(virtualKeyboardView.viewModel.inputMethods, id: \.name) { inputMethod in
          Button {
            client.setCurrentInputMethod(inputMethod.name)
          } label: {
            Text(inputMethod.displayName)
          }
        }
      }
  }
}
