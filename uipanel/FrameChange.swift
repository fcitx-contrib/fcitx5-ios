import SwiftUI

private struct ViewFramePreferenceKey: PreferenceKey {
  static var defaultValue: [UUID: CGRect] = [:]

  static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
    value.merge(nextValue(), uniquingKeysWith: { $1 })
  }
}

private struct OnFrameChangeModifier: ViewModifier {
  let id = UUID()
  let action: (CGRect) -> Void

  func body(content: Content) -> some View {
    content
      .background(
        GeometryReader { geo in
          Color.clear.preference(
            key: ViewFramePreferenceKey.self,
            value: [id: geo.frame(in: .global)]
          )
        }
      )
      .onPreferenceChange(ViewFramePreferenceKey.self) { values in
        guard let frame = values[id] else { return }
        action(frame)
      }
  }
}

extension View {
  func onFrameChange(perform action: @escaping (CGRect) -> Void) -> some View {
    self.modifier(OnFrameChangeModifier(action: action))
  }
}
