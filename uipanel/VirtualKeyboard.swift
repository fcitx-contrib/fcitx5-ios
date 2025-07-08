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
  @Published var candidates: [String] = []
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
    VStack(spacing: 0) {
      if viewModel.mode == .initial {
        ToolbarView()
      } else if viewModel.mode == .candidates {
        CandidateBarView(candidates: $viewModel.candidates)
      }
      if viewModel.mode == .statusArea {
        StatusAreaView(actions: $viewModel.actions)
      } else if viewModel.mode == .edit {
        EditView()
      } else {
        KeyboardView(
          layer: $viewModel.layer, lock: $viewModel.lock, spaceLabel: $viewModel.spaceLabel,
          enterLabel: $viewModel.enterLabel)
      }
    }.background(lightBackground)
  }

  public func setDisplayMode(_ mode: DisplayMode) {
    viewModel.mode = mode
  }

  public func setCandidates(_ candidates: [String]) {
    if !candidates.isEmpty {
      setDisplayMode(.candidates)
    } else if viewModel.mode == .candidates {
      setDisplayMode(.initial)
    }
    viewModel.candidates = candidates
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
