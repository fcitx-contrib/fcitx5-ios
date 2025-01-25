import FcitxProtocol
import Foundation

public func commitStringAsync(_ clientPtr: UnsafeMutableRawPointer, _ commit: String) {
  let client: AnyObject = Unmanaged.fromOpaque(clientPtr).takeUnretainedValue()
  guard let client = client as? FcitxProtocol else {
    return
  }
  DispatchQueue.main.async {
    client.commitString(commit)
  }
}

public func setPreeditAsync(_ clientPtr: UnsafeMutableRawPointer, _ preedit: String, _ cursor: Int)
{
  let client: AnyObject = Unmanaged.fromOpaque(clientPtr).takeUnretainedValue()
  guard let client = client as? FcitxProtocol else {
    return
  }
  DispatchQueue.main.async {
    client.setPreedit(preedit, cursor)
  }
}
