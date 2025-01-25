import SwiftUI

struct CandidateBarView: View {
  @Binding var candidates: [String]

  var body: some View {
    ScrollView(.horizontal) {
      HStack(spacing: 20) {
        ForEach(Array(candidates.enumerated()), id: \.offset) { index, candidate in
          CandidateView(text: candidate, index: index)
        }
        Spacer()
      }.frame(height: barHeight)
    }.scrollIndicators(.hidden)  // Hide scroll bar as native keyboard.
      .padding([.leading], 10)
  }
}
