import Fcitx
import FcitxIpc
import SwiftUI
import SwiftUtil

let globalConfigUri = "fcitx://config/global"

func getConfig(_ uri: String) -> [String: Any] {
  guard let data = String(Fcitx.getConfig(uri)).data(using: .utf8),
    let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
  else {
    return ["ERROR": "Failed to get config"]
  }
  return json
}

func setConfig(_ uri: String, _ option: String, _ value: Any) {
  let object = option.isEmpty ? value : [option: value]
  guard JSONSerialization.isValidJSONObject(object),
    let data = try? JSONSerialization.data(withJSONObject: object),
    let jsonString = String(data: data, encoding: .utf8)
  else {
    return
  }
  Fcitx.setConfig(uri, jsonString)
  requestReload()
}

func extractValue(_ config: [String: Any], reset: Bool) -> Any {
  if reset, let defaultValue = config["DefaultValue"] {
    return defaultValue
  }
  if !reset, let value = config["Value"] {
    return value
  }
  if let children = config["Children"] as? [[String: Any]] {
    var value = [String: Any]()
    for child in children {
      if let option = child["Option"] as? String {
        value[option] = extractValue(child, reset: reset)
      }
    }
    return value
  }
  return ""
}

@MainActor
class ConfigManager: ObservableObject {
  @Published var uri = "" {
    didSet {
      reload()
    }
  }
  @Published var config = [String: Any]()
  @Published var children = [[String: Any]]()
  @Published var value: Any = [:]
  @Published var error: String?

  private func save(_ value: Any) {
    self.value = value
    setConfig(uri, "", value)
  }

  func set(_ value: Any) {
    save(value)
  }

  func reset() {
    set(extractValue(self.config, reset: true))
  }

  func reload() {
    if uri.isEmpty {
      return
    }
    let config: [String: Any] = getConfig(uri)
    if let error = config["ERROR"] as? String {
      self.config = [:]
      self.children = []
      self.value = [:]
      self.error = error
    } else {
      self.config = config
      let children = config["Children"] as? [[String: Any]] ?? []
      self.children = uri == globalConfigUri ? children.reversed() : children
      self.value = extractValue(config, reset: false)
      self.error = nil
    }
  }
}
