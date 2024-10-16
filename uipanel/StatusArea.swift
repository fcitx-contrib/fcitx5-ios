import SwiftUI

struct StatusArea: View {
  var body: some View {
    VStack {
      HStack {
        Button {
          toggleStatusArea(false)
        } label: {
          Image(systemName: "arrow.backward")
        }.frame(width: barHeight, height: barHeight)
        Spacer()
      }
      Spacer()
    }
  }
}
