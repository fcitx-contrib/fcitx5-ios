import FcitxProtocol
import Foundation

@MainActor
private var client: FcitxProtocol!

@MainActor
public func setClient(_ cli: FcitxProtocol) {
  client = cli
}

public func commitStringAsync(_ commit: String) {
  DispatchQueue.main.async {
    client.commitString(commit)
  }
}

public func deleteSurroundingTextAsync(_ offset: Int, _ size: Int) {
  DispatchQueue.main.async {
    client.deleteSurroundingText(offset, size)
  }
}

public func setPreeditAsync(_ preedit: String, _ cursor: Int) {
  DispatchQueue.main.async {
    client.setPreedit(preedit, cursor)
  }
}

public func forwardKeyAsync(_ key: String, _ code: String) {
  DispatchQueue.main.async {
    client.forwardKey(key, code)
  }
}
