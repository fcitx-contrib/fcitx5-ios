import SwiftUI

struct ReturnBarView: View {
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.totalHeight) var totalHeight
  let width: CGFloat
  var showsBackspace = false

  var body: some View {
    let barHeight = getBarHeight(totalHeight)
    HStack {
      Button {
        vm.popDisplayMode()
      } label: {
        Image(systemName: "arrow.backward")
          .foregroundColor(getNormalForeground(colorScheme))
          .frame(width: barHeight, height: barHeight)
      }
      Spacer()
      if showsBackspace {
        let backspaceWidth = width * 0.15
        BackspaceView(x: 0, y: 0, width: backspaceWidth, height: barHeight)
          .frame(width: backspaceWidth, height: barHeight)
      }
    }.frame(width: width, height: barHeight)
  }
}
