import SwiftUI

struct ToolbarView: View {
  @Environment(\.colorScheme) var colorScheme

  var body: some View {
    HStack {
      Button {
        virtualKeyboardView.setDisplayMode(.edit)
      } label: {
        Image(systemName: "character.cursor.ibeam")
          .foregroundColor(getNormalForeground(colorScheme))
          .frame(width: barHeight, height: barHeight)
      }
      Button {
        virtualKeyboardView.setDisplayMode(.statusArea)
      } label: {
        Image(systemName: "ellipsis")
          .foregroundColor(getNormalForeground(colorScheme))
          .frame(width: barHeight, height: barHeight)
      }
    }
  }
}
