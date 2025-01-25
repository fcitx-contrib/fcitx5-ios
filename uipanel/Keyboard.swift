import SwiftUI

struct KeyboardView: View {
  let keys: [[String]] = [
    ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
    ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
    ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
    ["`", "z", "x", "c", "v", "b", "n", "m"],
    [",", " ", "."],
  ]

  var body: some View {
    VStack(spacing: 8) {
      ForEach(keys, id: \.self) { row in
        HStack(spacing: 6) {
          ForEach(row, id: \.self) { key in
            KeyView(label: key)
          }
        }
      }
    }.frame(height: keyboardHeight)
  }
}
