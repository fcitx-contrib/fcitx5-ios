import SwiftUI

struct ClipboardView: View {
  let width: CGFloat

  var body: some View {
    VStack(spacing: 0) {
      ReturnBarView(width: width)
      Spacer()
    }
  }
}
