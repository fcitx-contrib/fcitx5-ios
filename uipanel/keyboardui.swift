import FcitxProtocol
import SwiftUI

var client: FcitxProtocol!

public func showKeyboardAsync(_ clientPtr: UnsafeMutableRawPointer) {
  let obj: AnyObject = Unmanaged.fromOpaque(clientPtr).takeUnretainedValue()
  guard let obj = obj as? FcitxProtocol else {
    return
  }
  client = obj
}

public func setCandidatesAsync(_ candidates: [String]) {
  DispatchQueue.main.async {
    virtualKeyboardView.setCandidates(candidates)
  }
}

public struct StatusAreaAction: Identifiable {
  public let id: Int32
  let desc: String
  let checked: Bool
  let separator: Bool
  let children: [StatusAreaAction]

  public init(id: Int32, desc: String, checked: Bool, separator: Bool, children: [StatusAreaAction])
  {
    self.id = id
    self.desc = desc
    self.separator = separator
    self.checked = checked
    self.children = children
  }
}

public func setStatusAreaActionsAsync(_ actions: [StatusAreaAction]) {
  DispatchQueue.main.async {
    virtualKeyboardView.setActions(actions)
  }
}
