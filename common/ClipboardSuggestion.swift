import Foundation

/// Source apps opt into this convention; iOS does not classify passwords for us.
public let concealedPasteboardType = "org.nspasteboard.ConcealedType"

public func clipboardDisplayText(
  _ text: String, sensitive: Bool, maskSensitive: Bool, limit: Int? = nil
) -> String {
  let excerpt = limit.map { String(text.prefix($0)) } ?? text
  return sensitive && maskSensitive ? String(repeating: "•", count: excerpt.count) : excerpt
}

/// Transient clipboard content, independent of history retention and pin ordering.
public struct ClipboardSuggestionState {
  public private(set) var presentedText: String?
  public private(set) var presentedSensitive = false

  private var capturedText: String?
  private var capturedSensitive = false
  private var capturedAt: Date?
  private var enabled = true
  private var timeout = 30

  public init() {}

  public mutating func configure(enabled: Bool, timeout: Int, now: Date = Date()) {
    self.enabled = enabled
    self.timeout = max(-1, timeout)
    if !enabled {
      dismiss()
    } else {
      refresh(now: now)
    }
  }

  public mutating func capture(_ text: String, sensitive: Bool = false, now: Date = Date()) {
    guard enabled else { return }
    guard text.contains(where: { !$0.isWhitespace }) else {
      dismiss()
      return
    }
    capturedText = text
    capturedSensitive = sensitive
    capturedAt = now
    refresh(now: now)
  }

  /// Reevaluate only when the keyboard/toolbar is shown or configuration changes.
  public mutating func refresh(now: Date = Date()) {
    // Deliberately do not schedule an automatic UI dismissal at the deadline:
    // the user may be about to tap Paste, and the target must not disappear.
    // An already presented suggestion remains usable until the next reevaluation.
    guard enabled, let capturedAt,
      timeout < 0 || now.timeIntervalSince(capturedAt) < Double(timeout)
    else {
      presentedText = nil
      presentedSensitive = false
      return
    }
    presentedText = capturedText
    presentedSensitive = capturedSensitive
  }

  public mutating func hide() {
    presentedText = nil
    presentedSensitive = false
  }

  public mutating func dismiss() {
    hide()
    capturedText = nil
    capturedSensitive = false
    capturedAt = nil
  }

  public mutating func takePresentedText() -> String? {
    // Do not recheck expiry on tap: a suggestion that is still visible can be pasted.
    let text = presentedText
    dismiss()
    return text
  }
}
