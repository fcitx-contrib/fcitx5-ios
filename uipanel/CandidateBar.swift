import SwiftUI
import UIPanel

let auxPreeditRatio = 0.32  // Same with fcitx5-keyboard-web
let candidateCountInRow = 10
let candidateCountInScreen = 36
let expandIconRatio = 0.3
let expandButtonRatio = 0.8
let expandDividerRatio = 0.6
let expandDividerColor = Color(
  .sRGB, red: 179 / 255.0, green: 180 / 255.0, blue: 186 / 255.0, opacity: 1)

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
  @Environment(\.colorScheme) var colorScheme
  let width: CGFloat
  let auxUp: String
  let preedit: String
  let caret: Int
  let candidates: [String]
  let highlighted: Int
  let rowItemCount: [Int]
  let batch: Int
  let scrollEnd: Bool
  @Binding var expanded: Bool
  @Binding var pendingScroll: Int
  @State private var visibleRows = Set<Int>()

  private func loadMoreCandidates(_ start: Int, _ count: Int) {
    if pendingScroll < start {
      pendingScroll = start
      scroll(Int32(start), Int32(count))
    }
  }

  var body: some View {
    ScrollViewReader { proxy in
      HStack(spacing: 0) {
        let barHeightExcludePreedit =
          barHeight * (auxUp.isEmpty && preedit.isEmpty ? 1 : (1 - auxPreeditRatio))

        VStack(alignment: .leading, spacing: 0) {
          if !auxUp.isEmpty || !preedit.isEmpty {
            Text(auxUp + preeditWithCaret(preedit, caret)).font(.system(size: preeditFontSize))
              .frame(
                height: barHeight * auxPreeditRatio
              )
              .padding([.leading], 4)
          }

          if expanded {
            ScrollView(.vertical) {
              LazyVStack(spacing: 0) {
                ForEach(rowItemCount.indices, id: \.self) { row in
                  HStack(spacing: 0) {
                    ForEach(0..<rowItemCount[row], id: \.self) { col in
                      let index = rowItemCount.prefix(row).reduce(0, +) + col
                      if index < candidates.count {
                        CandidateView(
                          text: candidates[index], index: index, highlighted: highlighted
                        )
                        .frame(minWidth: width / 8).frame(
                          height: (barHeightExcludePreedit + keyboardHeight) / 6
                        )
                      }
                    }
                  }.onAppear {
                    visibleRows.insert(row)
                    if !scrollEnd && row == rowItemCount.count - 5 {
                      loadMoreCandidates(candidates.count, candidateCountInScreen)
                    }
                  }.onDisappear {
                    visibleRows.remove(row)
                  }
                }
              }
            }.frame(width: width * 4 / 5, height: barHeightExcludePreedit + keyboardHeight)
              .scrollIndicators(.hidden)  // Hide scroll bar as native keyboard.
              .onChange(of: batch) { _ in
                proxy.scrollTo(0, anchor: .leading)
              }
          } else {
            ScrollView(.horizontal) {
              // Use LazyHStack so that onAppear is triggered only when candidate is scrolled into view.
              LazyHStack(spacing: candidateGap) {
                ForEach(Array(candidates.enumerated()), id: \.offset) { index, candidate in
                  CandidateView(
                    text: candidate, index: index, highlighted: highlighted
                  ).onAppear {
                    if !scrollEnd && index == candidates.count - candidateCountInRow {
                      loadMoreCandidates(candidates.count, candidateCountInRow)
                    }
                  }
                }
                Spacer()
              }.frame(
                height: barHeightExcludePreedit)
            }.scrollIndicators(.hidden)  // Hide scroll bar as native keyboard.
              .padding([.leading], columnGap / 2)
              .onChange(of: batch) { _ in
                // Use batch instead of candidates because we don't want to reset on loading more.
                proxy.scrollTo(0, anchor: .leading)
              }
          }
        }

        let expandButton = VStack {
          Image(systemName: expanded ? "chevron.up" : "chevron.down").resizable()
            .aspectRatio(contentMode: .fit).frame(width: barHeight * expandIconRatio)
        }.frame(width: barHeight * expandButtonRatio, height: barHeight).onTapGesture {
          expanded.toggle()
        }

        if expanded {
          VStack(alignment: .trailing, spacing: 0) {  // trailing for collapse button
            expandButton

            let keyHeight = keyboardHeight / 4
            let keyWidth = width / 5

            Button {
              withAnimation {
                proxy.scrollTo(((visibleRows.min() ?? 0) - 1) / 5 * 5, anchor: .top)
              }
            } label: {
              VStack {
                Image(systemName: "arrow.up")
                  .resizable()
                  .aspectRatio(contentMode: .fit)
                  .frame(height: keyHeight * 0.4)
              }
              .commonContentStyle(
                width: keyWidth, height: keyHeight, background: getFunctionBackground(colorScheme),
                foreground: getNormalForeground(colorScheme))
            }.commonContainerStyle(
              width: keyWidth, height: keyHeight, shadow: getShadow(colorScheme))

            Button {
              withAnimation {
                proxy.scrollTo(((visibleRows.min() ?? 0) + 1) / 5 * 5 + 5, anchor: .top)
              }
            } label: {
              VStack {
                Image(systemName: "arrow.down")
                  .resizable()
                  .aspectRatio(contentMode: .fit)
                  .frame(height: keyHeight * 0.4)
              }
              .commonContentStyle(
                width: keyWidth, height: keyHeight, background: getFunctionBackground(colorScheme),
                foreground: getNormalForeground(colorScheme))
            }.commonContainerStyle(
              width: keyWidth, height: keyHeight, shadow: getShadow(colorScheme))

            BackspaceView(width: keyWidth, height: keyHeight)

            EnterView(
              label: NSLocalizedString("return", comment: ""), width: keyWidth, height: keyHeight)
          }
        } else {
          Rectangle().frame(width: 1, height: barHeight * expandDividerRatio).foregroundColor(
            expandDividerColor)
          expandButton
        }
      }
    }
  }
}
