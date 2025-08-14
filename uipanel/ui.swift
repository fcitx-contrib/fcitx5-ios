import SwiftUI

let barHeight: CGFloat = 52
let keyboardWidth: CGFloat = UIScreen.main.bounds.width
let keyboardHeight: CGFloat = 208
let keyCornerRadius: CGFloat = 5
let rowGap: CGFloat = 8
let columnGap: CGFloat = 5

let preeditFontSize: CGFloat = 14
let candidateFontSize: CGFloat = 20
let candidateHorizontalPadding: CGFloat = 10
let candidateVerticalPadding: CGFloat = 4
let candidateGap: CGFloat = 4

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
let darkNormalBackground = Color(
  .sRGB, red: 107 / 255.0, green: 107 / 255.0, blue: 107 / 255.0, opacity: 1)
let darkFunctionBackground = Color(
  .sRGB, red: 70 / 255.0, green: 70 / 255.0, blue: 70 / 255.0, opacity: 1)
let darkShadow = Color(.sRGB, red: 37 / 255.0, green: 37 / 255.0, blue: 37 / 255.0, opacity: 1)
let darkHighlightBackground = Color(
  .sRGB, red: 67 / 255.0, green: 67 / 255.0, blue: 70 / 255.0, opacity: 1)
