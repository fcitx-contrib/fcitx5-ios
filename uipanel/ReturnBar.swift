import SwiftUI

struct ReturnBarView: View {
  var body: some View {
    HStack {
      Button {
        virtualKeyboardView.setDisplayMode(.initial)
      } label: {
        Image(systemName: "arrow.backward")
          .frame(width: barHeight, height: barHeight)
      }.background(lightBackground)
      Spacer()
    }
  }
}
