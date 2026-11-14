import Foundation

// Shared by key modifiers so an intervening key breaks a pending Shift pair.
struct KeyPressTracker {
  private var previousPress: (key: UUID, time: Date)?

  mutating func press(_ key: UUID, at time: Date, supportsDoubleTap: Bool = false) -> Bool {
    if supportsDoubleTap, let previousPress, previousPress.key == key,
      time.timeIntervalSince(previousPress.time) < 0.3
    {
      // Consume the pair: a third press starts a new single tap.
      self.previousPress = nil
      return true
    }
    previousPress = (key, time)
    return false
  }
}
