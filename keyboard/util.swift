import Foundation

func lengthOfFirstLine(_ s: String) -> Int {
  if let index = s.firstIndex(of: "\n") {
    return s.utf16.distance(from: s.utf16.startIndex, to: index.samePosition(in: s.utf16)!) - 1
  }
  return s.utf16.count
}

func lengthOfLastLine(_ s: String) -> Int {
  if let index = s.lastIndex(of: "\n") {
    return s.utf16.distance(from: index.samePosition(in: s.utf16)!, to: s.utf16.endIndex) - 1
  }
  return s.utf16.count
}

func utf16LengthOfLastGrapheme(_ s: String) -> Int {
  guard !s.isEmpty else { return 1 }
  return s.utf16.count - s.dropLast().utf16.count
}

func utf16LengthOfFirstGrapheme(_ s: String) -> Int {
  guard !s.isEmpty else { return 1 }
  return s.utf16.count - s.dropFirst().utf16.count
}
