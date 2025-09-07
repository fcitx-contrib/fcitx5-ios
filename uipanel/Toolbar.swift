import SwiftUI

struct ToolbarView: View {
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.totalHeight) var totalHeight

  let width: CGFloat

  var body: some View {
    let barHeight = getBarHeight(totalHeight)
    HStack(spacing: width / 6) {
      Spacer()
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
      Button {
        client.dismissKeyboard()
      } label: {
        Image(systemName: "chevron.down").resizable()
          .foregroundColor(getNormalForeground(colorScheme))
          .aspectRatio(contentMode: .fit).frame(width: barHeight * expandIconRatio)
          .frame(width: barHeight * expandButtonRatio, height: barHeight)
      }
    }
  }
}
