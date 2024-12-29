import FcitxProtocol

class KeyAction {
  var key: String
  var capsKey: String
  var label: String
  var capsLabel: String
  var action: (_ client: FcitxProtocol) -> Void

  init(key: String, capsKey: String, label: String, capsLabel: String, action: @escaping (_ client: FcitxProtocol) -> Void) {
    self.key = key
    self.capsKey = capsKey
    self.label = label
    self.capsLabel = capsLabel
    self.action = action
  }

  convenience init(key: String, capsKey: String, action: @escaping (_ client: FcitxProtocol) -> Void) {
    self.init(key: key, capsKey: capsKey, label: key, capsLabel: capsKey, action: action)
  }

  convenience init(key: String, label: String, action: @escaping (_ client: FcitxProtocol) -> Void) {
    self.init(key: key, capsKey: key, label: label, capsLabel: label, action: action)
  }

  convenience init(key: String, action: @escaping (_ client: FcitxProtocol) -> Void) {
    self.init(key: key, capsKey: key, action: action)
  }

  func perform(_ client: FcitxProtocol) {
    self.action(client)
  }
}

class AlphabetKeyAction: KeyAction {
  init(key: String) {
    super.init(
      key: key,
      capsKey: key.uppercased(),
      label: key,
      capsLabel: key.uppercased(),
      action: { client in
        client.keyPressed(key)
      })
  }
}

class SymbolKeyAction: KeyAction {
  init(symbol: String, label: String) {
    // Use the symbol name of keyNameList in `fcitx5/src/lib/fcitx-utils/keynametable.h`
    super.init(
      key: symbol,
      capsKey: symbol,
      label: label,
      capsLabel: label,
      action: { client in
        client.keyPressed(symbol)
      })
  }
}

class BackspaceKeyAction: SymbolKeyAction {
  init() {
    super.init(symbol: "BackSpace", label: "⌫")
  }
}
