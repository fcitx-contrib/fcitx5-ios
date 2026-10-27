import FcitxProtocol
import Foundation
import SwiftUtil

public func setClipboardHistoryLimit(_ limit: Int32) {
  do {
    try clipboardStore.setHistoryLimit(Int(limit))
  } catch {
    FCITX_ERROR("Failed to apply clipboard history limit: \(error)")
  }
}

@MainActor
private weak var client: FcitxProtocol?

@MainActor
public func setClient(_ cli: FcitxProtocol) {
  client = cli
}

public func commitStringAsync(
  _ program: String, _ documentIdentifier: String, _ commit: String
) {
  DispatchQueue.main.async {
    guard let client, client.isCurrentDocument(program, documentIdentifier) else { return }
    client.commitString(commit)
  }
}

public func deleteSurroundingTextAsync(
  _ program: String, _ documentIdentifier: String, _ offset: Int, _ size: Int
) {
  DispatchQueue.main.async {
    guard let client, client.isCurrentDocument(program, documentIdentifier) else { return }
    client.deleteSurroundingText(offset, size)
  }
}

public func setPreeditAsync(
  _ program: String, _ documentIdentifier: String, _ preedit: String, _ cursor: Int
) {
  DispatchQueue.main.async {
    guard let client, client.isCurrentDocument(program, documentIdentifier) else { return }
    client.setPreedit(preedit, cursor)
  }
}

public func forwardKeyAsync(
  _ program: String, _ documentIdentifier: String, _ key: String, _ code: String
) {
  DispatchQueue.main.async {
    guard let client, client.isCurrentDocument(program, documentIdentifier) else { return }
    client.forwardKey(key, code)
  }
}
