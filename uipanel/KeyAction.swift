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
        super.init(key: key, action:  { client in
            client.keyPressed(key)
        })
    }
}

class BackspaceKeyAction: KeyAction {
    init() {
        super.init(key: "Backspace", action: { client in
            client.keyPressed("⌫")
        })
    }
}
