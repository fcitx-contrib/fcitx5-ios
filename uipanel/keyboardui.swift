import FcitxCommon
import FcitxProtocol
import SwiftUI
import SwiftUtil

var client: FcitxProtocol!

public func showKeyboardAsync(_ clientPtr: UnsafeMutableRawPointer) {
  let obj: AnyObject = Unmanaged.fromOpaque(clientPtr).takeUnretainedValue()
  guard let obj = obj as? FcitxProtocol else {
    return
  }
  client = obj
}

public func setCandidatesAsync(
  _ auxUp: String, _ preedit: String, _ caret: Int32, _ candidates: [String]
) {
  DispatchQueue.main.async {
    virtualKeyboardView.setCandidates(auxUp, preedit, caret, candidates)
  }
}

public func scrollAsync(_ candidates: [String], _ start: Bool, _ end: Bool) {
  DispatchQueue.main.async {
    virtualKeyboardView.scroll(candidates, start, end)
  }
}

public struct StatusAreaAction: Identifiable {
  public let id: Int32
  let desc: String
  let icon: String
  let checked: Bool
  let separator: Bool
  let children: [StatusAreaAction]

  public init(
    id: Int32, desc: String, icon: String, checked: Bool, separator: Bool,
    children: [StatusAreaAction]
  ) {
    self.id = id
    self.desc = desc
    self.icon = icon
    self.separator = separator
    self.checked = checked
    self.children = children
  }
}

public func setStatusAreaAsync(_ actions: [StatusAreaAction], _ currentInputMethod: String) {
  DispatchQueue.main.async {
    virtualKeyboardView.setStatusArea(
      actions, currentInputMethod, deserialize([InputMethod].self, String(getInputMethods())))
  }
}
