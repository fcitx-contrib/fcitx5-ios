import OSLog

private let logger = Logger(subsystem: "org.fcitx.Fcitx5", category: "FcitxLog")

// swift-format-ignore: AlwaysUseLowerCamelCase
public func FCITX_DEBUG(_ message: String) {
  // https://stackoverflow.com/questions/57509909/swift-oslog-os-log-not-showing-up-in-console-app
  #if targetEnvironment(simulator)
    logger.info("\(message, privacy: .public)")
  #else
    logger.debug("\(message, privacy: .public)")
  #endif
}

// swift-format-ignore: AlwaysUseLowerCamelCase
public func FCITX_INFO(_ message: String) {
  logger.info("\(message, privacy: .public)")
}

// swift-format-ignore: AlwaysUseLowerCamelCase
public func FCITX_WARN(_ message: String) {
  logger.error("\(message, privacy: .public)")
}

// swift-format-ignore: AlwaysUseLowerCamelCase
public func FCITX_ERROR(_ message: String) {
  logger.fault("\(message, privacy: .public)")
}
