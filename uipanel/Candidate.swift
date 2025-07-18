import SwiftUI
import SwiftUtil
import UIPanel

struct CandidateAction: Codable, Identifiable {
  let id: Int32
  let text: String
}

struct CandidateView: View {
  let text: String
  let index: Int

  var body: some View {
    Text(text).font(.system(size: 20)).onTapGesture {
      selectCandidate(Int32(index))
    }.onContextMenu {
      let actions = deserialize([CandidateAction].self, String(getCandidateActions(Int32(index))))
      return actions.map { action in
        MenuItem(text: action.text, action: { activateCandidateAction(Int32(index), action.id) })
      }
    }
  }
}
