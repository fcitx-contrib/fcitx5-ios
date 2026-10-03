import Foundation

func firstLine(_ s: String) -> String {
  let index = s.firstIndex(where: \.isNewline) ?? s.endIndex
  return String(s[..<index])
}

func lastLine(_ s: String) -> String {
  if let index = s.lastIndex(where: \.isNewline) {
    return String(s[s.index(after: index)...])
  }
  return s
}
