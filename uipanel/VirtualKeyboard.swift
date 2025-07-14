import FcitxProtocol
import SwiftUI
import SwiftUtil

public enum DisplayMode {
  case initial
  case candidates
  case edit
  case statusArea
}

class ViewModel: ObservableObject {
  @Published var mode: DisplayMode = .initial
  @Published var auxUp = ""
  @Published var preedit = ""
  @Published var caret = 0
  @Published var candidates: [String] = []
  @Published var batch = 0  // Tell candidate container to reset state
  @Published var actions = [StatusAreaAction]()
  @Published var inputMethods = [InputMethod]()
  @Published var spaceLabel = ""
  @Published var enterLabel = ""
  @Published var layer = "default"
  @Published var lock = false
}

public struct VirtualKeyboardView: View {
  @ObservedObject var viewModel = ViewModel()

  public var body: some View {
    GeometryReader { geometry in
      let width = geometry.size.width
      VStack(spacing: 0) {
        if viewModel.mode == .initial {
          ToolbarView()
        } else if viewModel.mode == .candidates {
          CandidateBarView(
            auxUp: $viewModel.auxUp, preedit: $viewModel.preedit, caret: $viewModel.caret,
            candidates: $viewModel.candidates, batch: $viewModel.batch)
        }
        if viewModel.mode == .statusArea {
          StatusAreaView(actions: $viewModel.actions)
        } else if viewModel.mode == .edit {
          EditView(totalWidth: width)
        } else {
          KeyboardView(
            width: width, layer: viewModel.layer, lock: viewModel.lock,
            spaceLabel: viewModel.spaceLabel,
            enterLabel: viewModel.enterLabel)
        }
      }.background(lightBackground)
    }.frame(height: barHeight + keyboardHeight)
  }

  public func setDisplayMode(_ mode: DisplayMode) {
    viewModel.mode = mode
  }

  public func setCandidates(
    _ auxUp: String, _ preedit: String, _ caret: Int32, _ candidates: [String]
  ) {
    if !auxUp.isEmpty || !preedit.isEmpty || !candidates.isEmpty {
      setDisplayMode(.candidates)
    } else if viewModel.mode == .candidates {
      setDisplayMode(.initial)
    }
    viewModel.auxUp = auxUp
    viewModel.preedit = preedit
    viewModel.caret = Int(caret)
    viewModel.candidates = candidates
    viewModel.batch = (viewModel.batch + 1) & 0xFFFF
  }

  public func setStatusArea(
    _ actions: [StatusAreaAction], _ currentInputMethod: String, _ inputMethods: [InputMethod]
  ) {
    viewModel.actions = actions
    viewModel.inputMethods = inputMethods
    for inputMethod in inputMethods {
      if inputMethod.name == currentInputMethod {
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
}

public let virtualKeyboardView = VirtualKeyboardView()
