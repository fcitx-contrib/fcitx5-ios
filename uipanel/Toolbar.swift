import SwiftUI

struct UndoButton: View {
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.totalHeight) var totalHeight
  @ObservedObject var viewModel = vm

  var body: some View {
    Button {
      client.undo()
    } label: {
      Image(systemName: "arrow.uturn.backward")
        .foregroundColor(
          viewModel.canUndo ? getNormalForeground(colorScheme) : disabledForeground
        )
        .frame(width: getBarHeight(totalHeight), height: getBarHeight(totalHeight))
    }.disabled(!viewModel.canUndo)
  }
}

struct RedoButton: View {
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.totalHeight) var totalHeight
  @ObservedObject var viewModel = vm

  var body: some View {
    Button {
      client.redo()
    } label: {
      Image(systemName: "arrow.uturn.forward")
        .foregroundColor(
          viewModel.canRedo ? getNormalForeground(colorScheme) : disabledForeground
        )
        .frame(width: getBarHeight(totalHeight), height: getBarHeight(totalHeight))
    }.disabled(!viewModel.canRedo)
  }
}

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

struct DismissKeyboardButton: View {
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.totalHeight) var totalHeight

  var body: some View {
    let barHeight = getBarHeight(totalHeight)
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

struct ToolbarButtons: View {
  let width: CGFloat

  var body: some View {
    let itemWidth = width / 6
    HStack(spacing: 0) {
      UndoButton().frame(width: itemWidth)
      RedoButton().frame(width: itemWidth)
      EditorButton().frame(width: itemWidth)
      StatusAreaButton().frame(width: itemWidth)
      DismissKeyboardButton().frame(width: itemWidth)
    }.frame(width: itemWidth * 5)
  }
}

struct ToolbarView: View {
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.totalHeight) var totalHeight
  let width: CGFloat
  var showsBackButton = false

  var body: some View {
    HStack(spacing: 0) {
      if showsBackButton {
        Button {
          vm.popDisplayMode()
        } label: {
          Image(systemName: "arrow.backward")
            .foregroundColor(getNormalForeground(colorScheme))
            .frame(width: width / 6, height: getBarHeight(totalHeight))
        }
      } else {
        Spacer().frame(width: width / 6)
      }
      ToolbarButtons(width: width)
    }.frame(width: width)
  }
}
