import SwiftUI

let editKeyCornerRadius: CGFloat = 8
let editKeyGap: CGFloat = 8

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
          image: "arrowtriangle.left.fill", shrink: 15, normal: true,
          index: 0, width: width, height: height * 3
        ) {
          client.keyPressed("", "ArrowLeft")
        }
        button(
          image: "arrowtriangle.up.fill", shrink: 15, normal: true,
          index: 1, width: width, height: height * 1.5
        ) {
          client.keyPressed("", "ArrowUp")
        }
        button(
          image: "arrowtriangle.right.fill", shrink: 15, normal: true,
          index: 2, width: width, height: height * 3
        ) {
          client.keyPressed("", "ArrowRight")
        }
        button(
          image: "scissors", shrink: 10, normal: false,
          index: 3, width: width, height: height
        ) {
          client.cut()
        }
        button(
          image: "doc.on.doc", shrink: 10, normal: false,
          index: 7, width: width, height: height
        ) {
          client.copy()
        }
        button(
          image: "arrowtriangle.down.fill", shrink: 15, normal: true,
          index: 5, width: width, height: height * 1.5
        ) {
          client.keyPressed("", "ArrowDown")
        }
        button(
          image: "doc.on.clipboard", shrink: 10, normal: false,
          index: 11, width: width, height: height
        ) {
          client.paste()
        }
        button(
          image: "arrow.left.to.line", shrink: 15, normal: true,
          index: 12, width: width * 1.5, height: height
        ) {
          client.keyPressed("", "Home")
        }
        button(
          image: "arrow.right.to.line", shrink: 15, normal: true,
          index: 13, width: width * 1.5, height: height
        ) {
          client.keyPressed("", "End")
        }
        button(
          image: "delete.left", shrink: 10, normal: false,
          index: 15, width: width, height: height
        ) {}
      }
    }
  }

  private func position(_ index: Int, _ width: CGFloat, _ height: CGFloat) -> CGPoint {
    let row = index / 4
    let col = index % 4
    return CGPoint(x: CGFloat(col) * width, y: CGFloat(row) * height)
  }

  private func button(
    image: String, shrink: CGFloat, normal: Bool,
    index: Int, width: CGFloat, height: CGFloat, action: @escaping () -> Void
  ) -> some View {
    let background = normal ? getNormalBackground(colorScheme) : getFunctionBackground(colorScheme)
    let pressedBackground =
      normal ? getFunctionBackground(colorScheme) : getNormalBackground(colorScheme)
    let foreground = getNormalForeground(colorScheme)
    let p = position(index, width, height)
    let size = keyboardHeight / shrink
    let useWidth = image == "arrowtriangle.up.fill" || image == "arrowtriangle.down.fill"
    let symbol = Image(systemName: image)
      .resizable()
      .aspectRatio(contentMode: .fit)
      .condition(useWidth) {
        $0.frame(width: size)
      }
      .condition(!useWidth) {
        $0.frame(height: size)
      }
    if image == "delete.left" {
      return AnyView(
        BackspaceView(
          x: p.x, y: p.y, width: width, height: height, hMargin: editKeyGap, vMargin: editKeyGap,
          radius: editKeyCornerRadius))
    }
    return AnyView(
      symbol.keyProperties(
        x: p.x, y: p.y, width: width, height: height, hMargin: editKeyGap, vMargin: editKeyGap,
        radius: editKeyCornerRadius,
        background: background,
        pressedBackground: pressedBackground,
        foreground: foreground,
        shadow: getShadow(colorScheme),
        action: GestureAction(
          onTap: {
            action()
          }))
    )
  }
}
