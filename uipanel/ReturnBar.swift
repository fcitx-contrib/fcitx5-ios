import SwiftUI

struct ReturnBarView: View {
  @Environment(\.colorScheme) var colorScheme

  var body: some View {
    HStack {
      Button {
        virtualKeyboardView.popDisplayMode()
      } label: {
        Image(systemName: "arrow.backward")
          .foregroundColor(getNormalForeground(colorScheme))
          .frame(width: barHeight, height: barHeight)
      }
      Spacer()
    }
  }
}
