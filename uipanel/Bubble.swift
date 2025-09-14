import SwiftUI

//  ___________
// /           \ c = 2*r
// |           |
// |           |
// \  _______  /       h = 2*height + 1.5*rowGap - shadowRadius
//  \/       \/  r
//   |       |   +
//   | (x,y) | height - 2*r
//   |       |   +
//   \_______/   r
// s + width + s = w
//
// s = 0.4*width

let sideRatio = 0.4
let shadowRadius: CGFloat = 2
let cellWidth: CGFloat = 30

enum BubblePosition {
  case left
  case middle
  case right
}

struct BubbleShape: Shape {
  let s: CGFloat
  let height: CGFloat
  let position: BubblePosition
  let labels: [String]
  let index: Int

  func path(in rect: CGRect) -> Path {
    var path = Path()
    let w = rect.width
    let h = rect.height
    let r = keyCornerRadius
    let c = r * 2
    let left =
      position == .left ? 0 : ((position == .middle ? s : 2 * s) + CGFloat(index) * cellWidth)
    let right =
      w
      - (position == .right
        ? 0 : ((position == .middle ? s : 2 * s) + CGFloat(labels.count - 1 - index) * cellWidth))
    let leftArc = position != .left && index > 0
    let rightArc = position != .right && index < labels.count - 1
    let middle = h - height - columnGap

    path.move(to: CGPoint(x: 0, y: c))
    // top left corner
    path.addArc(
      center: CGPoint(x: c, y: c),
      radius: c,
      startAngle: .degrees(180),
      endAngle: .degrees(270),
      clockwise: false)
    // top
    path.addLine(to: CGPoint(x: w - c, y: 0))
    // top right corner
    path.addArc(
      center: CGPoint(x: w - c, y: c),
      radius: c,
      startAngle: .degrees(270),
      endAngle: .degrees(360),
      clockwise: false)
    if rightArc {
      // upper right
      path.addLine(to: CGPoint(x: w, y: middle - c))
      path.addArc(
        center: CGPoint(x: w - c, y: middle - c),
        radius: c,
        startAngle: .degrees(0),
        endAngle: .degrees(90),
        clockwise: false)
      // middle right
      path.addLine(to: CGPoint(x: right + columnGap + r, y: middle))
      path.addArc(
        center: CGPoint(x: right + columnGap + r, y: middle + columnGap + r),
        radius: columnGap + r,
        startAngle: .degrees(270),
        endAngle: .degrees(180),
        clockwise: true)
    } else {
      // upper right
      path.addLine(to: CGPoint(x: w, y: h * 0.4))
      // middle right
      path.addCurve(
        to: CGPoint(x: right, y: h * 0.65),
        control1: CGPoint(x: w, y: h * 0.55),
        control2: CGPoint(x: right, y: h * 0.5))
    }
    // lower right
    path.addLine(to: CGPoint(x: right, y: h - r))
    // bottom right corner
    path.addArc(
      center: CGPoint(x: right - r, y: h - r),
      radius: r,
      startAngle: .degrees(0),
      endAngle: .degrees(90),
      clockwise: false)
    // bottom
    path.addLine(to: CGPoint(x: left + r, y: h))
    // bottom left corner
    path.addArc(
      center: CGPoint(x: left + r, y: h - r),
      radius: r,
      startAngle: .degrees(90),
      endAngle: .degrees(180),
      clockwise: false)
    if leftArc {
      // lower left
      path.addLine(to: CGPoint(x: left, y: middle + columnGap + r))
      path.addArc(
        center: CGPoint(x: left - columnGap - r, y: middle + columnGap + r),
        radius: columnGap + r,
        startAngle: .degrees(360),
        endAngle: .degrees(270),
        clockwise: true)
      // middle left
      path.addLine(to: CGPoint(x: c, y: middle))
      path.addArc(
        center: CGPoint(x: c, y: middle - c),
        radius: c,
        startAngle: .degrees(90),
        endAngle: .degrees(180),
        clockwise: false)
    } else {
      // lower left
      path.addLine(to: CGPoint(x: left, y: h * 0.65))
      // middle left
      path.addCurve(
        to: CGPoint(x: 0, y: h * 0.4),
        control1: CGPoint(x: left, y: h * 0.5),
        control2: CGPoint(x: 0, y: h * 0.55))
    }
    // upper left
    path.closeSubpath()

    return path
  }
}

struct BubbleView: View {
  let x: CGFloat
  let y: CGFloat
  let width: CGFloat
  let height: CGFloat
  let keyboardWidth: CGFloat
  let background: Color
  let shadow: Color
  let label: String?
  let labels: [String]
  let index: Int
  let highlight: Int

  var body: some View {
    let h = 2 * height + 1.5 * rowGap - shadowRadius
    let s = sideRatio * width
    let position: BubblePosition =
      x - width / 2 - s < 0 ? .left : (x + width / 2 + s > keyboardWidth ? .right : .middle)
    let offsetX = position == .left ? s : (position == .middle ? 0 : -s)
    if let label = label {
      BubbleShape(s: s, height: height, position: position, labels: [label], index: 0)
        .fill(background)
        .shadow(color: shadow, radius: shadowRadius)
        .frame(width: (1 + 2 * sideRatio) * width, height: h)
        .overlay(
          Text(label).font(.system(size: h * 0.4).weight(.light))
            .offset(y: -h / 4)
        )
        .position(x: x + offsetX, y: y - (h - height) / 2)
    } else {
      let offsetCell = (CGFloat(labels.count - 1) / 2 - CGFloat(index)) * cellWidth
      BubbleShape(s: s, height: height, position: position, labels: labels, index: index)
        .fill(background)
        .shadow(color: shadow, radius: shadowRadius)
        .frame(
          width: (1 + 2 * sideRatio) * width + CGFloat(labels.count - 1) * cellWidth, height: h
        )
        .overlay(
          HStack(spacing: 0) {
            ForEach(Array(labels.enumerated()), id: \.offset) { i, label in
              Text(label).font(.system(size: h * 0.25).weight(.light))
                .frame(width: cellWidth)
                .condition(i == highlight) {
                  $0.foregroundColor(.white).background(highlightBackground)
                }
                .cornerRadius(keyCornerRadius)
            }
          }.offset(y: -h / 4)
        )
        .position(x: x + offsetCell + offsetX, y: y - (h - height) / 2)
    }
  }
}
