import UIKit

public func commitStringAsync(_ clientPtr: UnsafeMutableRawPointer, _ commit: String) {
  let client: AnyObject = Unmanaged.fromOpaque(clientPtr).takeUnretainedValue()
  guard let client = client as? UITextDocumentProxy else {
    return
  }
  DispatchQueue.main.async {
    client.insertText(commit)
  }
}
