import SwiftUI

struct Toolbar: View {
  var body: some View {
    HStack {
      Button {
      } label: {
        Image(systemName: "character.cursor.ibeam")
          .frame(width: barHeight, height: barHeight)
      }.background(lightBackground)
      Button {
      } label: {
        Image(systemName: "ellipsis")
          .frame(width: barHeight, height: barHeight)
      }.background(lightBackground)  // Clear background collapses tap area.
    }
  }
}
