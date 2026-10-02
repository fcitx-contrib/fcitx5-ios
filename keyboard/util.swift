import Foundation

func firstLine(_ s: String) -> String {
  let index = s.firstIndex { $0 == "\n" || $0 == "\r" } ?? s.endIndex
  return String(s[..<index])
}

func lastLine(_ s: String) -> String {
  if let index = s.lastIndex(where: { $0 == "\n" || $0 == "\r" }) {
    return String(s[s.index(after: index)...])
  }
  return s
}
