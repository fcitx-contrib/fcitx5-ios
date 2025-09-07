import SwiftUI

let keyCornerRadius: CGFloat = 5
let rowGap: CGFloat = 8
let columnGap: CGFloat = 5

let preeditFontSize: CGFloat = 14
let candidateFontSize: CGFloat = 20
let candidateHorizontalPadding: CGFloat = 10
let candidateVerticalPadding: CGFloat = 4
let candidateGap: CGFloat = 4

let transparent = Color.black.opacity(0.001)

let lightBackground = Color(
  .sRGB, red: 210 / 255.0, green: 212 / 255.0, blue: 218 / 255.0, opacity: 1)
let lightNormalBackground = Color.white
let lightFunctionBackground = Color(
  .sRGB, red: 171 / 255.0, green: 177 / 255.0, blue: 186 / 255.0, opacity: 1)
let lightShadow = Color.gray
let lightHighlightBackground = Color(
  .sRGB, red: 247 / 255.0, green: 248 / 255.0, blue: 250 / 255.0, opacity: 1)

let darkBackground = Color(
  .sRGB, red: 43 / 255.0, green: 43 / 255.0, blue: 43 / 255.0, opacity: 1)
// Get 107, 107, 107 when blending with darkBackground.
let darkNormalBackground = Color(
  .sRGB, red: 1.0, green: 1.0, blue: 1.0, opacity: 0.3)
// Get 70, 70, 70 when blending with darkBackground.
let darkFunctionBackground = Color(
  .sRGB, red: 133 / 255.0, green: 133 / 255.0, blue: 133 / 255.0, opacity: 0.3)
let darkShadow = Color(.sRGB, red: 16 / 255.0, green: 13 / 255.0, blue: 14 / 255.0, opacity: 0.3)
// Get 67, 67, 70 when blending with darkBackground.
let darkHighlightBackground = Color(
  .sRGB, red: 123 / 255.0, green: 123 / 255.0, blue: 133 / 255.0, opacity: 0.3)

let disabledForeground = Color.gray
let highlightForeground = Color.white
let highlightBackground = Color(
  .sRGB, red: 0, green: 122 / 255.0, blue: 1, opacity: 1)
