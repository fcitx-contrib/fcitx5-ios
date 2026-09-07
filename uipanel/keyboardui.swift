import Fcitx
import FcitxProtocol
import SwiftUI
import SwiftUtil

public func setCandidatesAsync(
  _ program: String, _ documentIdentifier: String, _ auxUp: String, _ preedit: String,
  _ caret: Int32, _ candidates: [String],
  _ highlighted: Int32, _ bulk: Bool, _ hasClientPreedit: Bool, _ tabActionsJSON: String,
  _ hasPrev: Bool, _ hasNext: Bool, _ endReached: Bool
) {
  DispatchQueue.main.async {
    guard let client, client.isCurrentDocument(program, documentIdentifier) else { return }
    vm.setCandidates(
      program, documentIdentifier, auxUp, preedit, caret, candidates, highlighted, bulk,
      hasClientPreedit,
      deserialize([CandidateAction].self, tabActionsJSON), hasPrev, hasNext, endReached)
  }
}

public func scrollAsync(
  _ program: String, _ documentIdentifier: String, _ candidates: [String], _ end: Bool
) {
  DispatchQueue.main.async {
    guard let client, client.isCurrentDocument(program, documentIdentifier) else { return }
    vm.scroll(candidates, end)
  }
}

public struct StatusAreaAction: Identifiable, Sendable {
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

public func setStatusAreaAsync(
  _ program: String, _ documentIdentifier: String, _ actions: [StatusAreaAction]
) {
  DispatchQueue.main.async {
    guard let client, client.isCurrentDocument(program, documentIdentifier) else { return }
    vm.setStatusArea(actions)
  }
}

public func setCurrentInputMethodAsync(
  _ program: String, _ documentIdentifier: String, _ im: String
) {
  DispatchQueue.main.async {
    guard let client, client.isCurrentDocument(program, documentIdentifier) else { return }
    vm.setCurrentInputMethod(
      im, deserialize([InputMethod].self, String(getInputMethods())))
  }
}
