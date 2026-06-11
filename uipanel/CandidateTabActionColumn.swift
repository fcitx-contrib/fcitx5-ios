import SwiftUI
import UIPanel

struct CandidateTabActionItemView: View {
  @Environment(\.colorScheme) var colorScheme
  let action: CandidateAction
  let width: CGFloat
  let actionHeight: CGFloat
  let paddingBottom: CGFloat

  @State private var isPressed = false

  var body: some View {
    VStack(spacing: 0) {
      ZStack {
        // Use a hidden placeholder to maintain consistent height matching CandidateView regardless font size.
        Text(" ").font(.system(size: candidateFontSize))
          .padding([.top, .bottom], candidateVerticalPadding)
          .hidden()

        Text(action.text)
          .font(.system(size: candidateFontSize))
          .lineLimit(1)
          .minimumScaleFactor(0.5)  // Fit zhuang.
      }
      .frame(width: width * 0.9)
      .background(
        action.checked == true || isPressed ? getHighlightBackground(colorScheme) : .clear
      )
      .cornerRadius(keyCornerRadius)
      .frame(width: width, height: actionHeight)
      .contentShape(Rectangle())
      .onTapGesture {
        activateCandidateTabAction(action.id)
      }
      .onLongPressGesture(
        minimumDuration: .infinity,
        pressing: { pressing in
          isPressed = pressing
        }, perform: {})

      if paddingBottom > 0 {
        Spacer().frame(height: paddingBottom)
      }
    }
  }
}

struct CandidateTabActionColumnView: View {
  @Environment(\.colorScheme) var colorScheme

  let actions: [CandidateAction]
  let width: CGFloat
  let actionHeight: CGFloat
  let paddingBottom: CGFloat
  let height: CGFloat

  private var scrollableActions: [CandidateAction] {
    actions.prefix(while: { !$0.separator }).map { $0 }
  }

  private var pinnedActions: [CandidateAction] {
    if let firstSeparatorIndex = actions.firstIndex(where: { $0.separator }) {
      return actions.suffix(from: firstSeparatorIndex + 1).filter { !$0.separator }
    }
    return []
  }

  var body: some View {
    VStack(spacing: 0) {
      ScrollView(.vertical) {
        LazyVStack(spacing: 0) {
          ForEach(scrollableActions) { action in
            CandidateTabActionItemView(
              action: action, width: width, actionHeight: actionHeight,
              paddingBottom: paddingBottom)
          }
        }
      }

      VStack(spacing: 0) {
        ForEach(pinnedActions) { action in
          CandidateTabActionItemView(
            action: action, width: width, actionHeight: actionHeight,
            paddingBottom: paddingBottom)
        }
      }
    }
    .frame(width: width, height: height)
  }
}
