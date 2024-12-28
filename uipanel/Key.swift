import FcitxProtocol
import UIKit

class Key: UIButton {
  let client: FcitxProtocol
  let action: KeyAction

  init(_ client: FcitxProtocol, _ label: String, _ action: KeyAction) {
    self.client = client
    self.action = action
    super.init(frame: .zero)
    setTitle(label, for: .normal)
    titleLabel?.font = UIFont.systemFont(ofSize: 24)
    backgroundColor = UIColor.gray.withAlphaComponent(0.2)
    layer.cornerRadius = 8
    addTarget(self, action: #selector(keyPressed(_:)), for: .touchUpInside)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  @objc private func keyPressed(_ sender: UIButton) {
    guard let currentTitle = sender.currentTitle else {
      return
    }
    self.action.perform(self.client)
  }
}
