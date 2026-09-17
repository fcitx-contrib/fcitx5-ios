import SwiftUI

struct EditorButton: View {
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.totalHeight) var totalHeight

  var body: some View {
    Button {
      vm.setDisplayMode(.edit)
    } label: {
      Image(systemName: "character.cursor.ibeam")
        .foregroundColor(getNormalForeground(colorScheme))
        .frame(width: getBarHeight(totalHeight), height: getBarHeight(totalHeight))
    }
  }
}

struct StatusAreaButton: View {
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.totalHeight) var totalHeight

  var body: some View {
    Button {
      vm.setDisplayMode(.statusArea)
    } label: {
      Image(systemName: "ellipsis")
        .foregroundColor(getNormalForeground(colorScheme))
        .frame(width: getBarHeight(totalHeight), height: getBarHeight(totalHeight))
    }
  }
}

struct ToolbarButtons: View {
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.totalHeight) var totalHeight

  let width: CGFloat

  var body: some View {
    let barHeight = getBarHeight(totalHeight)
    HStack(spacing: width / 6) {
      EditorButton()
      StatusAreaButton()
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

struct ToolbarView: View {
  let width: CGFloat

  var body: some View {
    HStack(spacing: 0) {
      Spacer()
      ToolbarButtons(width: width)
    }
  }
}
