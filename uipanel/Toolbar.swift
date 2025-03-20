import SwiftUI

struct ToolbarView: View {
  var body: some View {
    HStack {
      Button {
        virtualKeyboardView.setDisplayMode(.edit)
      } label: {
        Image(systemName: "character.cursor.ibeam")
          .frame(width: barHeight, height: barHeight)
      }.background(lightBackground)
      Button {
        virtualKeyboardView.setDisplayMode(.statusArea)
      } label: {
        Image(systemName: "ellipsis")
          .frame(width: barHeight, height: barHeight)
      }.background(lightBackground)  // Clear background collapses tap area.
    }
  }
}
