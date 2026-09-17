import SwiftUI

struct ReturnBarView: View {
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.totalHeight) var totalHeight
  let width: CGFloat
  var showsToolbarButtons = false
  var showsBackspace = false
  var isLocked: Binding<Bool>? = nil

  var body: some View {
    let barHeight = getBarHeight(totalHeight)
    HStack(spacing: 0) {
      Button {
        vm.popDisplayMode()
      } label: {
        Image(systemName: "arrow.backward")
          .foregroundColor(getNormalForeground(colorScheme))
          .frame(width: barHeight, height: barHeight)
      }
      if let isLocked {
        Button {
          isLocked.wrappedValue.toggle()
        } label: {
          Image(systemName: isLocked.wrappedValue ? "lock" : "lock.open")
            .foregroundColor(getNormalForeground(colorScheme))
            .frame(width: barHeight, height: barHeight)
        }
      }
      Spacer()
      if showsToolbarButtons {
        ToolbarButtons(width: width)
      }
      if showsBackspace {
        let backspaceWidth = width * 0.15
        BackspaceView(x: 0, y: 0, width: backspaceWidth, height: barHeight)
          .frame(width: backspaceWidth, height: barHeight)
      }
    }.frame(width: width, height: barHeight)
  }
}
