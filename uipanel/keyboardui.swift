import FcitxProtocol
import OSLog
import SwiftUI
import UIKit

let logger = Logger(subsystem: "org.fcitx.Fcitx5", category: "FcitxLog")

let candidateCollectionView = CandidateCollectionView()

let toolbarHostingController = UIHostingController(rootView: Toolbar())

var keyboardView: Keyboard? = nil

let statusAreaHostingController = UIHostingController(rootView: StatusArea())

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
  DispatchQueue.main.async {
    setupMainLayout(client)
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
