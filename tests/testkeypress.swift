import Foundation

@main
private struct KeyPressTests {
  static func main() {
    let shift = UUID()
    let letter = UUID()
    let space = UUID()
    let start = Date(timeIntervalSinceReferenceDate: 0)
    var failures = 0
    var checks = 0
    func expect(_ condition: Bool, _ message: String) {
      checks += 1
      if !condition {
        print("FAILED: \(message)")
        failures += 1
      }
    }

    // Double taps consume pairs, preserving the existing triple/fourth-tap rule.
    var tracker = KeyPressTracker()
    for index in 0..<6 {
      let doubleTap = tracker.press(
        shift, at: start.addingTimeInterval(Double(index) * 0.05), supportsDoubleTap: true)
      expect(doubleTap == (index % 2 == 1), "consecutive Shift press \(index + 1)")
    }

    // A different accepted key breaks the pair, even before that key releases.
    for otherKey in [letter, space] {
      tracker = KeyPressTracker()
      expect(!tracker.press(shift, at: start, supportsDoubleTap: true), "initial Shift is single")
      expect(
        !tracker.press(otherKey, at: start.addingTimeInterval(0.05)),
        "ordinary keys do not double tap")
      expect(
        !tracker.press(shift, at: start.addingTimeInterval(0.1), supportsDoubleTap: true),
        "intervening key prevents Shift lock")
      expect(
        tracker.press(shift, at: start.addingTimeInterval(0.15), supportsDoubleTap: true),
        "the next consecutive Shift can form a fresh pair")
    }

    for interval in [0.299, 0.3, 0.301] {
      tracker = KeyPressTracker()
      _ = tracker.press(shift, at: start, supportsDoubleTap: true)
      expect(
        tracker.press(shift, at: start.addingTimeInterval(interval), supportsDoubleTap: true)
          == (interval < 0.3), "strict 300ms boundary at \(interval)s")
    }

    // An expired press is a fresh single, and can start the next valid pair.
    tracker = KeyPressTracker()
    _ = tracker.press(shift, at: start, supportsDoubleTap: true)
    expect(
      !tracker.press(shift, at: start.addingTimeInterval(0.4), supportsDoubleTap: true),
      "expired Shift pair")
    expect(
      tracker.press(shift, at: start.addingTimeInterval(0.5), supportsDoubleTap: true),
      "fresh pair after timeout")

    tracker = KeyPressTracker()
    expect(!tracker.press(letter, at: start), "ordinary first press")
    expect(
      !tracker.press(letter, at: start.addingTimeInterval(0.05)),
      "ordinary repeat press has no double-tap action")

    if failures != 0 {
      fatalError("\(failures) of \(checks) key-press checks failed")
    }
    print("KeyPressSwift: \(checks) checks passed")
  }
}
