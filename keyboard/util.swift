import Foundation

func firstLine(_ s: String) -> String {
  let index = s.firstIndex(of: "\n") ?? s.endIndex
  return String(s[..<index])
}

func lastLine(_ s: String) -> String {
  if let index = s.lastIndex(of: "\n") {
    return String(s[s.index(after: index)...])
  }
  return s
}
