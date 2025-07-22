// Modified by changing CalculatedElement to store index instead of subview due to an intermittent crash.
// https://github.com/FluidGroup/swiftui-WrapLayout/commit/7c89d42687a8412985642d667afd85cf48ff9670

import SwiftUI

struct WrapLayout: Layout {

  public struct CacheStorage {

    struct CalculatedElement {
      let index: Int
      let size: CGSize
    }

    struct Line {

      var width: CGFloat = 0
      var height: CGFloat = 0

      var elements: [CalculatedElement] = []
    }

    var lines: [Line] = []

    func calculateSize(verticalSpacing: CGFloat) -> CGSize {

      // get a length from the longest line.
      let maxWidth = lines.max(by: { $0.width < $1.width })?.width ?? 0

      // get a total height by all lines.
      let totalHeight: CGFloat = lines.reduce(0) { partialResult, line in
        partialResult + line.height
      }

      // total spacing from each line.
      let verticalSpacing: CGFloat = (CGFloat(max(0, (lines.count - 1))) * verticalSpacing)

      return .init(width: maxWidth, height: totalHeight + verticalSpacing)

    }
  }

  public let horizontalSpacing: CGFloat
  public let verticalSpacing: CGFloat

  public init(
    horizontalSpacing: CGFloat = 0,
    verticalSpacing: CGFloat = 0
  ) {
    self.horizontalSpacing = horizontalSpacing
    self.verticalSpacing = verticalSpacing
  }

  public func makeCache(subviews: Subviews) -> CacheStorage {
    return .init()
  }

  func sizeThatFits(
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout CacheStorage
  ) -> CGSize {

    cache.lines.removeAll(keepingCapacity: true)

    let maxWidth = proposal.width ?? .infinity
    var offsetX: CGFloat = 0
    var currentLine = CacheStorage.Line()

    for i in subviews.indices {
      let size = subviews[i].sizeThatFits(.init(width: maxWidth, height: .infinity))

      if offsetX + size.width > maxWidth {
        currentLine.width = offsetX
        cache.lines.append(currentLine)
        currentLine = CacheStorage.Line()
        offsetX = 0
      }

      currentLine.elements.append(.init(index: i, size: size))
      offsetX += size.width + horizontalSpacing
      currentLine.height = max(currentLine.height, size.height)
    }

    currentLine.width = offsetX
    cache.lines.append(currentLine)

    return cache.calculateSize(verticalSpacing: verticalSpacing)
  }

  func placeSubviews(
    in bounds: CGRect,
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout CacheStorage
  ) {

    var cursorY: CGFloat = 0

    for line in cache.lines {
      var cursorX: CGFloat = 0
      for element in line.elements {
        let view = subviews[element.index]
        view.place(
          at: CGPoint(
            x: bounds.minX + cursorX,
            y: bounds.minY + cursorY),
          anchor: .topLeading,
          proposal: .init(element.size)
        )
        cursorX += element.size.width + horizontalSpacing
      }
      cursorY += line.height + verticalSpacing
    }
  }
}
