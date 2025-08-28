import FcitxProtocol
import Foundation

private func getClient(_ clientPtr: UnsafeMutableRawPointer) -> FcitxProtocol? {
  let client: AnyObject = Unmanaged.fromOpaque(clientPtr).takeUnretainedValue()
  return client as? FcitxProtocol
}

public func commitStringAsync(_ clientPtr: UnsafeMutableRawPointer, _ commit: String) {
  guard let client = getClient(clientPtr) else {
    return
  }
  DispatchQueue.main.async {
    client.commitString(commit)
  }
}

public func setPreeditAsync(_ clientPtr: UnsafeMutableRawPointer, _ preedit: String, _ cursor: Int)
{
  guard let client = getClient(clientPtr) else {
    return
  }
  DispatchQueue.main.async {
    client.setPreedit(preedit, cursor)
  }
}

public func forwardKeyAsync(_ clientPtr: UnsafeMutableRawPointer, _ key: String, _ code: String) {
  guard let client = getClient(clientPtr) else {
    return
  }
  DispatchQueue.main.async {
    client.forwardKey(key, code)
  }
}
