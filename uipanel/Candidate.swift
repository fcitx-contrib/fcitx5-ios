import SwiftUI
import UIPanel

struct CandidateView: View {
  let text: String
  let index: Int

  var body: some View {
    Text(text).font(.system(size: 20)).onTapGesture {
      selectCandidate(Int32(index))
    }
  }
}
