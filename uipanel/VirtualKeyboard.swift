import FcitxProtocol
import SwiftUI

public enum DisplayMode {
  case initial
  case candidates
  case statusArea
}

private class ViewModel: ObservableObject {
  @Published var mode: DisplayMode = .initial
  @Published var candidates: [String] = []
  @Published var actions = [StatusAreaAction]()
}

public struct VirtualKeyboardView: View {
  @ObservedObject private var viewModel = ViewModel()

  public var body: some View {
    VStack(spacing: 0) {
      if viewModel.mode == .initial {
        ToolbarView()
      } else if viewModel.mode == .candidates {
        CandidateBarView(candidates: $viewModel.candidates)
      }
      if viewModel.mode == .statusArea {
        StatusAreaView(actions: $viewModel.actions)
      } else {
        KeyboardView()
      }
    }.background(lightBackground)
  }

  public func keyPressed(_ key: String) {
    client.keyPressed(key)
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

  public func setActions(_ actions: [StatusAreaAction]) {
    viewModel.actions = actions
  }
}

public let virtualKeyboardView = VirtualKeyboardView()
