import SwiftUI

struct EditView: View {
  @Environment(\.colorScheme) var colorScheme
  let totalWidth: CGFloat

  var body: some View {
    let height = keyboardHeight / 4
    let width = totalWidth / 4
    VStack(spacing: 0) {
      ReturnBarView()

      ZStack {
        button(
          image: "arrowtriangle.left.fill", shrink: 15,
          background: getNormalBackground(colorScheme),
          foreground: getNormalForeground(colorScheme),
          shadow: getShadow(colorScheme),
          index: 0, width: width, height: height * 3
        ) {
          client.keyPressed("", "ArrowLeft")
        }
        button(
          image: "arrowtriangle.up.fill", shrink: 15,
          background: getNormalBackground(colorScheme),
          foreground: getNormalForeground(colorScheme),
          shadow: getShadow(colorScheme),
          index: 1, width: width, height: height * 1.5
        ) {
          client.keyPressed("", "ArrowUp")
        }
        button(
          image: "arrowtriangle.right.fill", shrink: 15,
          background: getNormalBackground(colorScheme),
          foreground: getNormalForeground(colorScheme),
          shadow: getShadow(colorScheme),
          index: 2, width: width, height: height * 3
        ) {
          client.keyPressed("", "ArrowRight")
        }
        button(
          image: "scissors", shrink: 10,
          background: getFunctionBackground(colorScheme),
          foreground: getNormalForeground(colorScheme),
          shadow: getShadow(colorScheme),
          index: 3, width: width, height: height
        ) {
          client.cut()
        }
        button(
          image: "doc.on.doc", shrink: 10,
          background: getFunctionBackground(colorScheme),
          foreground: getNormalForeground(colorScheme),
          shadow: getShadow(colorScheme),
          index: 7, width: width, height: height
        ) {
          client.copy()
        }
        button(
          image: "arrowtriangle.down.fill", shrink: 15,
          background: getNormalBackground(colorScheme),
          foreground: getNormalForeground(colorScheme),
          shadow: getShadow(colorScheme),
          index: 5, width: width, height: height * 1.5
        ) {
          client.keyPressed("", "ArrowDown")
        }
        button(
          image: "doc.on.clipboard", shrink: 10,
          background: getFunctionBackground(colorScheme),
          foreground: getNormalForeground(colorScheme),
          shadow: getShadow(colorScheme),
          index: 11, width: width, height: height
        ) {
          client.paste()
        }
        button(
          image: "arrow.left.to.line", shrink: 15,
          background: getNormalBackground(colorScheme),
          foreground: getNormalForeground(colorScheme),
          shadow: getShadow(colorScheme),
          index: 12, width: width * 1.5, height: height
        ) {
          client.keyPressed("", "Home")
        }
        button(
          image: "arrow.right.to.line", shrink: 15,
          background: getNormalBackground(colorScheme),
          foreground: getNormalForeground(colorScheme),
          shadow: getShadow(colorScheme),
          index: 13, width: width * 1.5, height: height
        ) {
          client.keyPressed("", "End")
        }
        button(
          image: "delete.left", shrink: 10,
          background: getFunctionBackground(colorScheme),
          foreground: getNormalForeground(colorScheme),
          shadow: getShadow(colorScheme),
          index: 15, width: width, height: height
        ) {
          client.keyPressed("", "Backspace")
        }
      }
    }
  }

  private func position(_ index: Int, _ width: CGFloat, _ height: CGFloat) -> CGPoint {
    let row = index / 4
    let col = index % 4
    return CGPoint(x: (CGFloat(col) + 0.5) * width, y: (CGFloat(row) + 0.5) * height)
  }

  private func button(
    image: String, shrink: CGFloat, background: Color, foreground: Color, shadow: Color,
    index: Int, width: CGFloat, height: CGFloat, action: @escaping () -> Void
  ) -> some View {
    let w = width - 8
    let h = height - 8
    let r: CGFloat = 8
    return Button {
      action()
    } label: {
      VStack {
        let symbol = Image(systemName: image)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .foregroundColor(foreground)
        let size = keyboardHeight / shrink
        if image == "arrowtriangle.up.fill" || image == "arrowtriangle.down.fill" {
          symbol.frame(width: size)
        } else {
          symbol.frame(height: size)
        }
      }.frame(width: w, height: h)
        .background(background)
        .foregroundColor(.black)
        .cornerRadius(r)
    }.buttonStyle(PlainButtonStyle())
      .shadow(color: shadow, radius: 0, x: 0, y: 1)
      .frame(width: w, height: h)
      .overlay(
        RoundedRectangle(cornerRadius: r)
          .stroke(Color.clear, lineWidth: 1)
      ).position(position(index, width, height))
  }
}
