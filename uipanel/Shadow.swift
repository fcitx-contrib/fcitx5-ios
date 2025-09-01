import SwiftUI

// |\_______/|
// |         |
//  \_______/

// Put it below a key that needs shadow.
// Needed because .shadow affects the entire button's transparency.

struct ShadowShape: Shape {
  let r: CGFloat

  func path(in rect: CGRect) -> Path {
    var path = Path()
    let w = rect.width
    let h = rect.height

    path.move(to: CGPoint(x: 0, y: h - r))
    path.addArc(
      center: CGPoint(x: r, y: h - r),
      radius: r,
      startAngle: .degrees(180),
      endAngle: .degrees(90),
      clockwise: true)
    path.addLine(to: CGPoint(x: w - r, y: h))
    path.addArc(
      center: CGPoint(x: w - r, y: h - r),
      radius: r,
      startAngle: .degrees(90),
      endAngle: .degrees(0),
      clockwise: true)
    path.addLine(to: CGPoint(x: w, y: 0))
    path.addArc(
      center: CGPoint(x: w - r, y: 0),
      radius: r,
      startAngle: .degrees(0),
      endAngle: .degrees(90),
      clockwise: false)
    path.addLine(to: CGPoint(x: r, y: r))
    path.addArc(
      center: CGPoint(x: r, y: 0),
      radius: r,
      startAngle: .degrees(90),
      endAngle: .degrees(180),
      clockwise: false)
    path.closeSubpath()
    return path
  }
}

struct ShadowView: View {
  let width: CGFloat
  let height: CGFloat
  let radius: CGFloat
  let color: Color

  var body: some View {
    ShadowShape(r: radius)
      .fill(color)
      .frame(width: width, height: height + radius)
  }
}
