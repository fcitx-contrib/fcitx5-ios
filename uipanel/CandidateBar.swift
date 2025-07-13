import SwiftUI

let auxPreeditRatio = 0.32  // Same with fcitx5-keyboard-web

private func preeditWithCaret(_ preedit: String, _ caret: Int) -> String {
  if preedit.isEmpty {
    return ""
  }
  var index = 0
  if caret > 0 {
    var utf8 = 0
    for char in preedit {
      index += 1
      utf8 += char.utf8.count
      if utf8 == caret {
        break
      }
    }
  }
  return String(preedit.prefix(index) + "‸" + preedit.suffix(preedit.count - index))
}

struct CandidateBarView: View {
  @Binding var auxUp: String
  @Binding var preedit: String
  @Binding var caret: Int
  @Binding var candidates: [String]
  @Binding var batch: Int

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if !auxUp.isEmpty || !preedit.isEmpty {
        Text(auxUp + preeditWithCaret(preedit, caret)).font(.system(size: 14)).frame(
          height: barHeight * auxPreeditRatio
        )
        .padding([.leading], 4)
      }
      ScrollViewReader { proxy in
        ScrollView(.horizontal) {
          HStack(spacing: 20) {
            ForEach(Array(candidates.enumerated()), id: \.offset) { index, candidate in
              CandidateView(text: candidate, index: index)
            }
            Spacer()
          }.frame(
            height: barHeight * (auxUp.isEmpty && preedit.isEmpty ? 1 : (1 - auxPreeditRatio)))
        }.scrollIndicators(.hidden)  // Hide scroll bar as native keyboard.
          .padding([.leading], 10)
          .onChange(of: batch) { _ in
            // Use batch instead of candidates because we don't want to reset on loading more.
            proxy.scrollTo(0)
          }
      }
    }
  }
}
