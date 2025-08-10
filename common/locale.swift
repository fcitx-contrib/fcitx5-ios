// See fcitx5-macos/src/locale.swift

import Foundation
import SwiftUtil

// Return app locale or system locale if called from app.
// Return system locale if called from keyboard.
public func getLocale() -> String {
  let locale = Locale.current
  logger.info("System locale = \(locale.identifier)")

  if let languageCode = locale.language.languageCode?.identifier {
    if languageCode == "zh" {
      if let scriptCode = locale.language.script?.identifier {
        if scriptCode == "Hans" {
          return "zh_CN"
        } else {
          return "zh_TW"
        }
      }
      if locale.region?.identifier == "SG" {
        return "zh_CN"
      } else {
        return "zh_TW"
      }
    }
    return languageCode
  }
  return "C"
}
