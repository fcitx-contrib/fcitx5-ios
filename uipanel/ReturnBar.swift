import SwiftUI

struct ReturnBarView: View {
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.totalHeight) var totalHeight

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
    }
  }
}
