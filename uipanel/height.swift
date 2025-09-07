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

private var isFloating = false

func setFloating(_ width: CGFloat) {
  isFloating =
    (UIScreen.main.bounds.width >= 1000 || UIScreen.main.bounds.height > 1000)
    && width < UIScreen.main.bounds.width && width < UIScreen.main.bounds.height
}

func getKeyboardState() -> KeyboardState {
  if isFloating {
    return .floating
  }
  if UIScreen.main.bounds.width < UIScreen.main.bounds.height {
    return .portrait
  }
  return .landscape
}

func getDefaultTotalHeight() -> CGFloat {
  switch getKeyboardState() {
  case .portrait:
    let height = UIScreen.main.bounds.height
    if height < 900 {
      return 260
    } else if height < 1000 {
      return 270
    } else if height < 1150 {
      return 260
    } else if height < 1200 {
      return 255
    } else if height < 1300 {
      return 260
    }
    return 325
  case .landscape:
    let height = UIScreen.main.bounds.width
    if height < 1000 {
      return 198
    } else if height < 1150 {
      return 348
    } else if height < 1200 {
      return 342
    } else if height < 1300 {
      return 348
    }
    return 420
  case .floating:
    return 255
  }
}

func getKeyboardHeight(_ totalHeight: CGFloat) -> CGFloat {
  return totalHeight * 0.8
}

func getBarHeight(_ totalHeight: CGFloat) -> CGFloat {
  return totalHeight * 0.2
}
