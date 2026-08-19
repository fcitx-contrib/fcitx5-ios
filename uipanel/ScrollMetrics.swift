import SwiftUI

struct ScrollMetrics: Equatable {
  var offset: CGFloat = 0
  var contentHeight: CGFloat = 0
  var containerHeight: CGFloat = 0
}

extension View {
  @ViewBuilder
  func onScrollMetricsChange(_ onChange: @escaping (ScrollMetrics) -> Void) -> some View {
    if #available(iOS 18.0, *) {
      self.onScrollGeometryChange(for: ScrollMetrics.self) { geometry in
        ScrollMetrics(
          offset: geometry.contentOffset.y,
          contentHeight: geometry.contentSize.height,
          containerHeight: geometry.containerSize.height
        )
      } action: { _, newValue in
        onChange(newValue)
      }
    } else {
      self
    }
  }
}
