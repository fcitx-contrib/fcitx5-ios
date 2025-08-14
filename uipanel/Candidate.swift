import SwiftUI
import SwiftUtil
import UIPanel

struct CandidateAction: Codable, Identifiable {
  let id: Int32
  let text: String
}

func getHighlightBackground(_ colorScheme: ColorScheme) -> Color {
  return colorScheme == .dark ? darkHighlightBackground : lightHighlightBackground
}

struct CandidateView: View {
  @Environment(\.colorScheme) var colorScheme
  let text: String
  let index: Int
  let highlighted: Int

  var body: some View {
    Text(text).font(.system(size: candidateFontSize))
      .padding([.leading, .trailing], candidateHorizontalPadding)
      .padding([.top, .bottom], candidateVerticalPadding)
      .background(index == highlighted ? getHighlightBackground(colorScheme) : .clear)
      .cornerRadius(keyCornerRadius)
      .onTapGesture {
        selectCandidate(Int32(index))
      }.onContextMenu {
        let actions = deserialize([CandidateAction].self, String(getCandidateActions(Int32(index))))
        return actions.map { action in
          MenuItem(text: action.text, action: { activateCandidateAction(Int32(index), action.id) })
        }
      }
  }
}
