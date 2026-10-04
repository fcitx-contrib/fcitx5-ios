import SwiftUI

struct ReturnBarView<TrailingContent: View>: View {
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.totalHeight) var totalHeight

  let width: CGFloat
  let title: String?
  let showsBackspace: Bool
  let isLocked: Binding<Bool>?
  let trailingContent: TrailingContent

  init(
    width: CGFloat, title: String? = nil, showsBackspace: Bool = false,
    isLocked: Binding<Bool>? = nil,
    @ViewBuilder trailingContent: () -> TrailingContent
  ) {
    self.width = width
    self.title = title
    self.showsBackspace = showsBackspace
    self.isLocked = isLocked
    self.trailingContent = trailingContent()
  }

  var body: some View {
    let barHeight = getBarHeight(totalHeight)
    HStack(spacing: 0) {
      Button {
        vm.popDisplayMode()
      } label: {
        Image(systemName: "arrow.backward")
          .foregroundColor(getNormalForeground(colorScheme))
          .frame(width: barHeight, height: barHeight)
      }
      if let isLocked {
        Button {
          isLocked.wrappedValue.toggle()
        } label: {
          Image(systemName: isLocked.wrappedValue ? "lock" : "lock.open")
            .foregroundColor(getNormalForeground(colorScheme))
            .frame(width: barHeight, height: barHeight)
        }
      }
      if let title {
        Text(title)
          .font(.headline)
          .foregroundColor(getNormalForeground(colorScheme))
          .lineLimit(1)
      }
      Spacer()
      if showsBackspace {
        let backspaceWidth = width * 0.15
        BackspaceView(x: 0, y: 0, width: backspaceWidth, height: barHeight)
          .frame(width: backspaceWidth, height: barHeight)
      }
      trailingContent
    }.frame(width: width, height: barHeight)
  }
}

extension ReturnBarView where TrailingContent == EmptyView {
  init(
    width: CGFloat, title: String? = nil, showsBackspace: Bool = false,
    isLocked: Binding<Bool>? = nil
  ) {
    self.init(
      width: width, title: title, showsBackspace: showsBackspace, isLocked: isLocked
    ) {
      EmptyView()
    }
  }
}
