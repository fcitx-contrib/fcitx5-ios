import Foundation

func lengthOfFirstLine(_ s: String) -> Int {
  if let index = s.index(of: "\n") {
    return s.distance(from: s.startIndex, to: index) - 1
  }
  return s.count
}

func lengthOfLastLine(_ s: String) -> Int {
  if let index = s.lastIndex(of: "\n") {
    return s.distance(from: index, to: s.endIndex) - 1
  }
  return s.count
}
