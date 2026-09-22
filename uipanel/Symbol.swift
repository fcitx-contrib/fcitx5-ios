import Foundation
import SwiftUI
import SwiftUtil

struct SymbolCategory: Identifiable {
  var id: String { key }
  let key: String
  let name: String
  let symbols: [String]
  let symbolWidths: [String: SymbolWidth]
}

enum SymbolWidth {
  case halfWidth
  case fullWidth

  var badgeImageName: String {
    switch self {
    case .halfWidth:
      return "moon.fill"
    case .fullWidth:
      return "moonphase.full.moon"
    }
  }
}

private struct SymbolCategoryFile: Decodable {
  let name: [String: String]
  let symbols: [String]
  let halfWidth: [String]?
  let fullWidth: [String]?
}

let builtinCategoryKeys = [
  "chinese_punctuation",
  "english_punctuation",
  "common",
  "math",
  "unit",
  "currency",
  "sequence",
  "superscript_subscript",
  "arrow",
  "shape",
  "special",
  "radical",
  "pinyin",
  "bopomofo",
  "phonetic",
  "greek",
  "latin",
  "cyrillic",
  "hiragana",
  "katakana",
]

let builtinCategories: [SymbolCategory] = {
  let locale = getLocale()
  let language = locale.split(whereSeparator: { $0 == "_" || $0 == "-" }).first.map(String.init)
  return builtinCategoryKeys.compactMap { key in
    let url = appBundleUrl.appendingPathComponent("share/symbol/\(key).json")
    do {
      let file = try JSONDecoder().decode(SymbolCategoryFile.self, from: Data(contentsOf: url))
      let name = file.name[locale] ?? language.flatMap { file.name[$0] } ?? file.name["en"] ?? key
      var symbolWidths: [String: SymbolWidth] = [:]
      for symbol in file.halfWidth ?? [] {
        symbolWidths[symbol] = .halfWidth
      }
      for symbol in file.fullWidth ?? [] {
        symbolWidths[symbol] = .fullWidth
      }
      return SymbolCategory(
        key: key, name: name, symbols: file.symbols, symbolWidths: symbolWidths)
    } catch {
      FCITX_ERROR("Failed to load symbol category \(key): \(error)")
      return nil
    }
  }
}()

struct SymbolButton: View {
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.totalHeight) var totalHeight

  let symbol: String
  let symbolWidth: SymbolWidth?
  let action: () -> Void

  @State private var isPressed = false

  var body: some View {
    Text(symbol)
      .font(.system(size: 24))
      .frame(height: getKeyboardHeight(totalHeight) / 5)
      .frame(maxWidth: .infinity)
      .background(isPressed ? getFunctionBackground(colorScheme) : Color.clear)
      .overlay(alignment: .topTrailing) {
        if let symbolWidth {
          Image(systemName: symbolWidth.badgeImageName)
            .font(.system(size: 7))
            .foregroundStyle(.secondary)
            .padding(4)
            .accessibilityHidden(true)
        }
      }
      .contentShape(Rectangle())
      .onTapGesture {
        action()
      }
      .onLongPressGesture(
        minimumDuration: .infinity,
        pressing: { pressing in
          isPressed = pressing
        }, perform: {})
  }
}

struct SymbolView: View {
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.totalHeight) var totalHeight
  @ObservedObject private var viewModel = vm
  let width: CGFloat

  @State private var selectedKey = builtinCategories.first?.key ?? ""

  var body: some View {
    VStack(spacing: 0) {
      ReturnBarView(width: width, showsBackspace: true, isLocked: $viewModel.symbolLocked)
      HStack(spacing: 0) {
        ScrollView {
          VStack(spacing: 0) {
            ForEach(builtinCategories) { category in
              Text(category.name)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, 2)
                .frame(height: getKeyboardHeight(totalHeight) / 5)
                .frame(maxWidth: .infinity)
                .background(
                  selectedKey == category.key ? getFunctionBackground(colorScheme) : Color.clear
                )
                .onTapGesture {
                  selectedKey = category.key
                }
            }
          }
        }.frame(width: width / 5)
        Divider().frame(width: 1)
        if let category = builtinCategories.first(where: { $0.key == selectedKey }) {
          ScrollViewReader { proxy in
            ScrollView {
              VStack(spacing: 0) {
                Color.clear.frame(height: 0).id("top")
                LazyVGrid(
                  columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 5), spacing: 0
                ) {
                  ForEach(category.symbols, id: \.self) { symbol in
                    SymbolButton(symbol: symbol, symbolWidth: category.symbolWidths[symbol]) {
                      client.resetInput()
                      client.commitString(symbol)
                      if !viewModel.symbolLocked {
                        vm.popDisplayMode()
                      }
                    }
                  }
                }
              }.onChange(of: selectedKey) { _ in
                proxy.scrollTo("top", anchor: .top)
              }
            }.frame(width: width * 4 / 5 - 1)
          }
        }
      }.frame(height: getKeyboardHeight(totalHeight))
    }
  }
}
