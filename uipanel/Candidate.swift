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
    }.contextMenu {
      let actions = deserialize([CandidateAction].self, String(getCandidateActions(Int32(index))))
      ForEach(actions) { action in
        Button {
          activateCandidateAction(Int32(index), action.id)
        } label: {
          Text(action.text)
        }
      }
    }
  }
}
