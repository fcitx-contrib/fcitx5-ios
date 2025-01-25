import SwiftUI
import UIPanel

private let circleDiameter: CGFloat = 60

struct StatusAreaView: View {
  @Binding var actions: [StatusAreaAction]

  private let columns = [
    GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()),
  ]

  var body: some View {
    VStack {
      HStack {
        Button {
          virtualKeyboardView.setDisplayMode(.initial)
        } label: {
          Image(systemName: "arrow.backward")
            .frame(width: barHeight, height: barHeight)
        }.background(lightBackground)
        Spacer()
      }
      ScrollView {
        LazyVGrid(columns: columns) {
          ForEach(actions) { action in
            if action.children.isEmpty {
              Button {
                activateStatusAreaAction(action.id)
              } label: {
                VStack {
                  ZStack {
                    Circle().fill(action.checked ? Color.accentColor : Color.gray).frame(
                      width: circleDiameter, height: circleDiameter)
                    Text(
                      action.desc.isEmpty ? "" : String(action.desc.prefix(1))
                    ).font(
                      .system(size: 28)
                    ).foregroundColor(.white)
                  }
                  Text(action.desc).foregroundColor(.primary)
                }
              }
            } else {
              Menu {
                ForEach(action.children) { child in
                  if child.separator {
                    Divider()
                  } else {
                    Button {
                      activateStatusAreaAction(child.id)
                    } label: {
                      Text(child.desc)
                    }
                  }
                }
              } label: {
                VStack {
                  ZStack {
                    Circle().fill(Color.gray).frame(width: circleDiameter, height: circleDiameter)
                    Image(systemName: "chevron.left.chevron.right").resizable().scaledToFit().frame(
                      width: 24
                    ).foregroundColor(.white)
                  }
                  Text(action.desc).foregroundColor(.primary)
                    .lineLimit(1)  // Keep buttons same height.
                }
              }
            }
          }
        }
      }
    }.frame(height: barHeight + keyboardHeight)
  }
}
