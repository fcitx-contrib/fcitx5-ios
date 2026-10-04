import SwiftUI

enum DialogActionRole {
  case normal
  case destructive
}

struct DialogAction: Identifiable {
  let id = UUID()
  let title: String
  let role: DialogActionRole
  let action: () -> Void

  init(
    _ title: String, role: DialogActionRole = .normal, action: @escaping () -> Void = {}
  ) {
    self.title = title
    self.role = role
    self.action = action
  }
}

struct DialogView: View {
  @Environment(\.colorScheme) private var colorScheme

  let width: CGFloat
  let height: CGFloat
  let message: String
  let actions: [DialogAction]
  let onDismiss: () -> Void

  var body: some View {
    ZStack {
      Color.black.opacity(0.2)
        .contentShape(Rectangle())
        .onTapGesture {
          onDismiss()
        }

      VStack(spacing: 0) {
        Text(message)
          .font(.headline)
          .foregroundColor(getNormalForeground(colorScheme))
          .multilineTextAlignment(.center)
          .padding()
        Divider()
        HStack(spacing: 0) {
          ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
            if index > 0 {
              Divider()
            }
            Button {
              onDismiss()
              action.action()
            } label: {
              Text(action.title)
                .foregroundColor(
                  action.role == .destructive ? .red : getNormalForeground(colorScheme)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
          }
        }
        .frame(height: 44)
      }
      .frame(width: min(width * 0.8, 320))
      .background(getNormalBackground(colorScheme).blend(with: getBackground(colorScheme)))
      .cornerRadius(8)
      .shadow(radius: 4)
    }
    .frame(width: width, height: height)
  }
}
