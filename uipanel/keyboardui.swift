import FcitxProtocol
import SwiftUI
import UIKit

let candidateCollectionView = CandidateCollectionView()

let toolbarHostingController = UIHostingController(rootView: Toolbar())

var keyboardView: Keyboard? = nil

let statusArea = StatusArea()
let statusAreaHostingController = UIHostingController(rootView: statusArea)

private func setupMainLayout(_ client: FcitxProtocol) {
  client.addChild(toolbarHostingController)
  client.addChild(statusAreaHostingController)

  let mainStackView = client.getView()

  toolbarHostingController.view.backgroundColor = UIColor.clear
  mainStackView.addArrangedSubview(toolbarHostingController.view)

  candidateCollectionView.translatesAutoresizingMaskIntoConstraints = false
  candidateCollectionView.isHidden = true
  mainStackView.addArrangedSubview(candidateCollectionView)

  keyboardView = Keyboard(client)
  keyboardView!.translatesAutoresizingMaskIntoConstraints = false
  mainStackView.addArrangedSubview(keyboardView!)

  statusAreaHostingController.view.backgroundColor = UIColor.clear
  statusAreaHostingController.view.isHidden = true
  mainStackView.addArrangedSubview(statusAreaHostingController.view)
}

public func showKeyboardAsync(_ clientPtr: UnsafeMutableRawPointer) {
  let client: AnyObject = Unmanaged.fromOpaque(clientPtr).takeUnretainedValue()
  guard let client = client as? FcitxProtocol else {
    return
  }
  if keyboardView == nil {
    DispatchQueue.main.async {
      setupMainLayout(client)
    }
  }
}

public func setCandidatesAsync(_ candidates: [String]) {
  DispatchQueue.main.async {
    candidateCollectionView.updateCandidates(candidates)
    toolbarHostingController.view.isHidden = !candidates.isEmpty
    candidateCollectionView.isHidden = candidates.isEmpty
  }
}

func toggleStatusArea(_ show: Bool) {
  if show {
    NSLayoutConstraint.activate([
      statusAreaHostingController.view.heightAnchor.constraint(
        equalToConstant: keyboardView!.frame.height + toolbarHostingController.view.frame.height)
    ])
  }
  keyboardView!.isHidden = show
  toolbarHostingController.view.isHidden = show
  statusAreaHostingController.view.isHidden = !show
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
    statusArea.setActions(actions)
  }
}
