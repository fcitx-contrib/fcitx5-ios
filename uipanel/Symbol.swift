import SwiftUI

struct SymbolCategory: Identifiable {
  var id: String { key }
  let key: String
  let symbols: [String]
}

let builtinCategories: [SymbolCategory] = [
  SymbolCategory(
    key: "pinyin",
    symbols: [
      "ā", "á", "ǎ", "à",
      "ō", "ó", "ǒ", "ò",
      "ē", "é", "ě", "è",
      "ī", "í", "ǐ", "ì",
      "ū", "ú", "ǔ", "ù",
      "ü", "ǖ", "ǘ", "ǚ", "ǜ",
      "ń", "ň",
    ]),
  SymbolCategory(
    key: "greek",
    symbols: [
      "α", "β", "γ", "δ", "ε", "ζ", "η", "θ", "ι", "κ", "λ", "μ",
      "ν", "ξ", "ο", "π", "ρ", "σ", "τ", "υ", "φ", "χ", "ψ", "ω",
      "Α", "Β", "Γ", "Δ", "Ε", "Ζ", "Η", "Θ", "Ι", "Κ", "Λ", "Μ",
      "Ν", "Ξ", "Ο", "Π", "Ρ", "Σ", "Τ", "Υ", "Φ", "Χ", "Ψ", "Ω",
    ]),
]

struct SymbolButton: View {
  let symbol: String
  let action: () -> Void

  @GestureState private var isPressed = false
  @State private var dragExceededThreshold = false

  var body: some View {
    Text(symbol)
      .font(.system(size: 24))
      .frame(height: keyboardHeight / 5)
      .frame(maxWidth: .infinity)
      .background(isPressed ? functionBackground : Color.clear)
      // Use simultaneousGesture so that scrolling behavior is preserved.
      .simultaneousGesture(
        DragGesture(minimumDistance: 0)
          .updating($isPressed) { _, state, _ in
            state = true
          }
          .onChanged { value in
            let distance = hypot(value.translation.width, value.translation.height)
            dragExceededThreshold = distance > 10
          }
          .onEnded { _ in
            dragExceededThreshold = false
          }
      )
      .onTapGesture {
        if !dragExceededThreshold {
          action()
        }
      }
  }
}

struct SymbolView: View {
  let width: CGFloat

  @State private var selectedKey = builtinCategories.first!.key

  var body: some View {
    VStack(spacing: 0) {
      ReturnBarView()
      HStack(spacing: 0) {
        ScrollView {
          VStack(spacing: 0) {
            ForEach(builtinCategories) { category in
              Text(category.key)
                .font(.system(size: 24))
                .frame(height: keyboardHeight / 5)
                .frame(maxWidth: .infinity)
                .background(selectedKey == category.key ? functionBackground : Color.clear)
                .onTapGesture {
                  selectedKey = category.key
                }
            }
          }
        }.frame(width: width / 5)
        if let category = builtinCategories.first(where: { $0.key == selectedKey }) {
          ScrollViewReader { proxy in
            ScrollView {
              VStack(spacing: 0) {
                Color.clear.frame(height: 0).id("top")
                LazyVGrid(
                  columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 5), spacing: 0
                ) {
                  ForEach(category.symbols, id: \.self) { symbol in
                    SymbolButton(symbol: symbol) {
                      client.resetInput()
                      client.commitString(symbol)
                      virtualKeyboardView.popDisplayMode()
                    }
                  }
                }
              }.onChange(of: selectedKey) { _ in
                proxy.scrollTo("top", anchor: .top)
              }
            }.frame(width: width * 4 / 5)
          }
        }
      }
    }
  }
}
