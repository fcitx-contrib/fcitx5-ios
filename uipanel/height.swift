import SwiftUI

struct TotalHeightKey: EnvironmentKey {
  static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
  var totalHeight: CGFloat {
    get { self[TotalHeightKey.self] }
    set { self[TotalHeightKey.self] = newValue }
  }
}

enum KeyboardState {
  case portrait
  case landscape
  case floating
}

@MainActor
private var isFloating = false

@MainActor
func setFloating(_ width: CGFloat) {
  isFloating =
    (UIScreen.main.bounds.width >= 1000 || UIScreen.main.bounds.height > 1000)
    && width < UIScreen.main.bounds.width && width < UIScreen.main.bounds.height
}

@MainActor
func getKeyboardState() -> KeyboardState {
  if isFloating {
    return .floating
  }
  if UIScreen.main.bounds.width < UIScreen.main.bounds.height {
    return .portrait
  }
  return .landscape
}

@MainActor
func getDefaultTotalHeight() -> CGFloat {
  switch getKeyboardState() {
  case .portrait:
    let height = UIScreen.main.bounds.height
    if height < 1000 {
      // The 414 × 896 phones share the larger keyboard with Plus and Pro Max models.
      return UIScreen.main.bounds.width >= 414 ? 270 : 260
    } else if height < 1150 {
      return 260
    } else if height < 1200 {
      // Older 11-inch Pros are shorter than 1200 pt but keep the Pro keyboard size.
      return UIScreen.main.bounds.width >= 834 ? 260 : 255
    } else if height < 1300 {
      return 260
    }
    return 325
  case .landscape:
    let height = UIScreen.main.bounds.width
    if height < 1000 {
      return 198
    } else if height < 1150 {
      // The 10.5-inch Air uses the compact landscape keyboard.
      return UIScreen.main.bounds.height >= 834 ? 342 : 348
    } else if height < 1200 {
      return UIScreen.main.bounds.height >= 834 ? 348 : 342
    } else if height < 1300 {
      return 348
    }
    return 420
  case .floating:
    return 255
  }
}

@MainActor
func getKeyLabelFontSize(_ rowHeight: CGFloat) -> CGFloat {
  let isPad = UIDevice.current.userInterfaceIdiom == .pad
  let maximumFontSize: CGFloat
  switch getKeyboardState() {
  case .portrait:
    maximumFontSize = isPad ? 22 : 24.5
  case .landscape:
    maximumFontSize = isPad ? 27 : 21.5
  case .floating:
    maximumFontSize = 24.5
  }
  // Native landscape labels are larger than half a short phone row.
  // Only unusually short custom rows need to shrink below the measured size.
  return min(rowHeight * 0.7, maximumFontSize)
}

func getKeyboardHeight(_ totalHeight: CGFloat) -> CGFloat {
  return totalHeight * 0.8
}

func getBarHeight(_ totalHeight: CGFloat) -> CGFloat {
  return totalHeight * 0.2
}
