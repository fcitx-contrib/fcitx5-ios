import SwiftUI

struct ToastView: View {
  @Environment(\.colorScheme) private var colorScheme

  let message: String
  let actionTitle: String
  let action: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      Text(message)
        .foregroundColor(getNormalForeground(colorScheme))
        .lineLimit(2)
      Spacer(minLength: 8)
      Button(action: action) {
        Text(actionTitle)
          .fontWeight(.semibold)
          .foregroundColor(highlightBackground)
          .padding(.horizontal, 8)
          .frame(minHeight: 44)
      }
    }
    .padding(.leading, 16)
    .padding(.trailing, 8)
    .frame(minHeight: 48)
    .background(getFunctionBackground(colorScheme).blend(with: getBackground(colorScheme)))
    .cornerRadius(8)
    .shadow(radius: 4)
  }
}
