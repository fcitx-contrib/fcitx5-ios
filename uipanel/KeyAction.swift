import FcitxProtocol

class KeyAction {
  var key: String
  var action: (_ client: FcitxProtocol) -> Void

  init(key: String, action: @escaping (_ client: FcitxProtocol) -> Void) {
    self.key = key
    self.action = action
  }

  func perform(_ client: FcitxProtocol) {
    self.action(client)
  }
}

class AlphabetKeyAction: KeyAction {
  init(key: String) {
    super.init(
      key: key,
      action: { client in
        client.keyPressed(key)
      })
  }
}

class SymbolKeyAction: KeyAction {
  init(symbol: String) {
    // Use the symbol name of keyNameList in `fcitx5/src/lib/fcitx-utils/keynametable.h`
    super.init(
      key: symbol,
      action: { client in
        client.keyPressed(symbol)
      })
  }
}

class BackspaceKeyAction: SymbolKeyAction {
  init() {
    super.init(symbol: "BackSpace")
  }
}
