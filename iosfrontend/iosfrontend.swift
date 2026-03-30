import FcitxProtocol
import Foundation

private var client: FcitxProtocol!

public func setClient(_ cli: FcitxProtocol) {
  client = cli
}

public func commitStringAsync(_ commit: String) {
  DispatchQueue.main.async {
    client.commitString(commit)
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
