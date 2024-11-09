import CryptoKit
import Foundation
import OSLog

public let logger = Logger(subsystem: "org.fcitx.Fcitx5", category: "FcitxLog")

public let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
public let appGroup = FileManager.default.containerURL(
  forSecurityApplicationGroupIdentifier: "org.fcitx.Fcitx5")!
public let appGroupConfig = appGroup.appendingPathComponent("config")
public let appGroupTmp = appGroup.appendingPathComponent("tmp")
public let appGroupData = appGroup.appendingPathComponent("data")

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
public func sync(_ src: URL, _ dst: URL) -> Bool {
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

public func mkdirP(_ path: String) {
  do {
    try FileManager.default.createDirectory(
      atPath: path, withIntermediateDirectories: true, attributes: nil)
  } catch {}
}

public func removeFile(_ file: URL) -> Bool {
  do {
    try FileManager.default.removeItem(at: file)
    return true
  } catch {
    return false
  }
}

// Call on both app and keyboard to initialize input method list after install.
public func initProfile() {
  mkdirP(appGroupConfig.path)
  let profileURL = appGroupConfig.appendingPathComponent("profile")
  if !profileURL.exists() {
    try? FileManager.default.copyItem(at: Bundle.main.bundleURL.appendingPathComponent("profile"), to: profileURL)
  }
}
