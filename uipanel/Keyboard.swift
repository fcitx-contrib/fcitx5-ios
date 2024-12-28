import FcitxProtocol
import UIKit

class Keyboard: UIStackView {
  let client: FcitxProtocol

  let keys: [[String]] = [
    ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
    ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
    ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
    ["`", "z", "x", "c", "v", "b", "n", "m", "⌫"],
    [",", " ", "."],
  ]

  init(_ client: FcitxProtocol) {
    self.client = client
    super.init(frame: .zero)
    setupKeyboardLayout()
  }

  required init(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setupKeyboardLayout() {
    axis = .vertical
    distribution = .fillEqually
    alignment = .fill
    spacing = 5

    for row in keys {
      let rowStackView = UIStackView()
      rowStackView.axis = .horizontal
      rowStackView.distribution = .fillEqually
      rowStackView.alignment = .fill
      rowStackView.spacing = 5

      for key in row {
        let button = Key(client, key, AlphabetKeyAction(key: key))
        rowStackView.addArrangedSubview(button)
      }
      addArrangedSubview(rowStackView)
    }
  }
}
