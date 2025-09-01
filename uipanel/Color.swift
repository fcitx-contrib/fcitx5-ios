import SwiftUI

extension Color {
  private func toRGBA() -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)? {
    let nativeColor = UIColor(self)
    var r: CGFloat = 0
    var g: CGFloat = 0
    var b: CGFloat = 0
    var a: CGFloat = 0
    guard nativeColor.getRed(&r, green: &g, blue: &b, alpha: &a) else {
      return nil
    }
    return (r, g, b, a)
  }

  func blend(with background: Color) -> Color {
    guard let fg = self.toRGBA(),
      let bg = background.toRGBA()
    else {
      return self
    }

    let r = (fg.r * fg.a + bg.r * (1 - fg.a))
    let g = (fg.g * fg.a + bg.g * (1 - fg.a))
    let b = (fg.b * fg.a + bg.b * (1 - fg.a))

    return Color(.sRGB, red: r, green: g, blue: b, opacity: 1)
  }
}
