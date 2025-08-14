import FcitxProtocol
import SwiftUI
import SwiftUtil

public enum DisplayMode {
  case initial
  case candidates
  case edit
  case statusArea
  case symbol
}

class ViewModel: ObservableObject {
  @Published var mode: DisplayMode = .initial
  @Published var returnMode: DisplayMode = .initial  // or .candidates

  @Published var auxUp = ""
  @Published var preedit = ""
  @Published var caret = 0
  @Published var candidates = [String]()
  @Published var highlighted = -1
  @Published var hasClientPreedit = false
  @Published var batch = 0  // Tell candidate container to reset state
  @Published var scrollEnd = false
  @Published var rowItemCount = [Int]()  // number of candidates in each row
  @Published var expanded = false
  // Have requested load more candidates starting from this index.
  @Published var pendingScroll = 0

  @Published var actions = [StatusAreaAction]()
  @Published var inputMethods = [InputMethod]()
  @Published var spaceLabel = ""
  @Published var enterLabel = ""
  @Published var layer = "default"
  @Published var lock = false

  @Published var frame = CGRect()
  @Published var menuItems = [MenuItem]()
  @Published var showMenu = false
}

public struct VirtualKeyboardView: View {
  @Environment(\.colorScheme) var colorScheme
  @ObservedObject var viewModel = ViewModel()

  public var body: some View {
    GeometryReader { geometry in
      ZStack {
        let width = geometry.size.width
        VStack(spacing: 0) {
          if viewModel.mode == .initial {
            ToolbarView(width: width)
          } else if viewModel.mode == .candidates {
            CandidateBarView(
              width: width, auxUp: viewModel.auxUp, preedit: viewModel.preedit,
              caret: viewModel.caret, candidates: viewModel.candidates,
              highlighted: viewModel.highlighted,
              rowItemCount: viewModel.rowItemCount,
              batch: viewModel.batch, scrollEnd: viewModel.scrollEnd,
              expanded: $viewModel.expanded,
              pendingScroll: $viewModel.pendingScroll)
          }
          if viewModel.mode == .statusArea {
            StatusAreaView(actions: $viewModel.actions)
          } else if viewModel.mode == .edit {
            EditView(totalWidth: width)
          } else if viewModel.mode == .symbol {
            SymbolView(width: width)
          } else {
            KeyboardView(
              width: width, layer: viewModel.layer, lock: viewModel.lock,
              spaceLabel: viewModel.spaceLabel,
              enterLabel: viewModel.enterLabel)
          }
        }.background(colorScheme == .dark ? darkBackground : lightBackground)
        if viewModel.showMenu {
          ContextMenuOverlay(
            items: viewModel.menuItems,
            frame: viewModel.frame,
            containerSize: CGSize(width: width, height: barHeight + keyboardHeight),
            onDismiss: { viewModel.showMenu = false }
          )
        }
      }
    }.frame(height: barHeight + keyboardHeight)
  }

  public func setDisplayMode(_ mode: DisplayMode) {
    if viewModel.mode == .candidates && mode == .symbol {
      viewModel.returnMode = .candidates
    }
    viewModel.mode = mode
  }

  public func popDisplayMode() {
    if viewModel.returnMode == .candidates {
      viewModel.mode = .candidates
      viewModel.returnMode = .initial
    } else {
      viewModel.mode = .initial
    }
  }

  public func setCandidates(
    _ auxUp: String, _ preedit: String, _ caret: Int32, _ candidates: [String],
    _ highlighted: Int32, _ hasClientPreedit: Bool
  ) {
    if !auxUp.isEmpty || !preedit.isEmpty || !candidates.isEmpty {
      setDisplayMode(.candidates)
      if preedit.isEmpty && !hasClientPreedit {
        // For prediction candidates, collapse to single bar so that user can ignore them and type keyboard.
        viewModel.expanded = false
      }
    } else if viewModel.mode == .candidates {
      setDisplayMode(.initial)
      viewModel.expanded = false
    }
    viewModel.auxUp = auxUp
    viewModel.preedit = preedit
    viewModel.caret = Int(caret)
    viewModel.candidates = candidates
    viewModel.highlighted = Int(highlighted)
    viewModel.hasClientPreedit = hasClientPreedit
    viewModel.batch = (viewModel.batch + 1) & 0xFFFF
    viewModel.scrollEnd = false
    viewModel.rowItemCount = calculateLayout(candidates, keyboardWidth * 4 / 5)
    viewModel.pendingScroll = 0
  }

  public func scroll(_ candidates: [String], _ end: Bool) {
    viewModel.candidates.append(contentsOf: candidates)
    viewModel.rowItemCount = calculateLayout(viewModel.candidates, keyboardWidth * 4 / 5)
    // Don't update batch as we don't want to reset scroll position.
    viewModel.scrollEnd = end
  }

  public func setStatusArea(_ actions: [StatusAreaAction]) {
    viewModel.actions = actions
  }

  public func setCurrentInputMethod(_ im: String, _ inputMethods: [InputMethod]) {
    viewModel.inputMethods = inputMethods
    for inputMethod in inputMethods {
      if inputMethod.name == im {
        viewModel.spaceLabel = inputMethod.displayName
        break
      }
    }
  }

  public func setReturnKeyType(_ type: UIReturnKeyType?) {
    switch type {
    case .done:
      viewModel.enterLabel = NSLocalizedString("done", comment: "")
    case .go:
      viewModel.enterLabel = NSLocalizedString("go", comment: "")
    case .next:
      viewModel.enterLabel = NSLocalizedString("next", comment: "")
    case .search:
      viewModel.enterLabel = NSLocalizedString("search", comment: "")
    case .send:
      viewModel.enterLabel = NSLocalizedString("send", comment: "")
    default:
      viewModel.enterLabel = NSLocalizedString("return", comment: "")
    }
  }

  func setLayer(_ layer: String, lock: Bool = false) {
    viewModel.layer = layer
    viewModel.lock = lock
  }

  func resetLayerIfNotLocked() {
    if !viewModel.lock {
      viewModel.layer = "default"
    }
  }

  func showContextMenu(_ frame: CGRect, _ items: [MenuItem]) {
    viewModel.frame = frame
    viewModel.menuItems = items
    viewModel.showMenu = true
  }
}

public let virtualKeyboardView = VirtualKeyboardView()
