import CryptoKit
import Foundation

let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
let appGroupData = FileManager.default.containerURL(
  forSecurityApplicationGroupIdentifier: "org.fcitx.Fcitx5")!.appendingPathComponent("data")

extension URL {
  var isDirectory: Bool {
    (try? resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
  }

  // Local file name is %-encoded with path()
  func localPath() -> String {
    let path = self.path
    guard let decoded = path.removingPercentEncoding else {
      return path
    }
    return decoded
  }

  func exists() -> Bool {
    return FileManager.default.fileExists(atPath: self.path)
  }
}

func md5Hash(_ url: URL) -> String {
  guard let fileData = try? Data(contentsOf: url) else {
    return ""
  }

  let digest = Insecure.MD5.hash(data: fileData)
  return digest.map { String(format: "%02hhx", $0) }.joined()
}

// Remove if different type, then copy if different content.
func sync(_ src: URL, _ dst: URL) -> Bool {
  if !src.exists() {
    return false
  }
  if dst.exists() && dst.isDirectory != src.isDirectory {
    try? FileManager.default.removeItem(at: dst)
  }
  if src.isDirectory {
    try? FileManager.default.createDirectory(at: dst, withIntermediateDirectories: true)
    var success = true
    for fileName in (try? FileManager.default.contentsOfDirectory(atPath: src.localPath())) ?? [] {
      if !sync(src.appendingPathComponent(fileName), dst.appendingPathComponent(fileName)) {
        success = false
      }
    }
    return success
  }
  if dst.exists() {
    let srcHash = md5Hash(src)
    let dstHash = md5Hash(dst)
    if srcHash == dstHash {
      return true
    }
    try? FileManager.default.removeItem(at: dst)
  } else if !dst.deletingLastPathComponent().exists() {
    try? FileManager.default.createDirectory(
      at: dst.deletingLastPathComponent(), withIntermediateDirectories: true)
  }
  do {
    try FileManager.default.copyItem(at: src, to: dst)
    return true
  } catch {
    return false
  }
}
