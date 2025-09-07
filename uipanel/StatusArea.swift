import SwiftUI
import UIPanel

private let circleDiameter: CGFloat = 60

private func getActionView(_ icon: String, _ desc: String) -> some View {
  var text: String?
  var symbol: String?
  var width: CGFloat = 24
  var uiImage: UIImage?
  switch icon {
  case "fcitx-chttrans-active":
    text = "繁"
  case "fcitx-chttrans-inactive":
    text = "简"
  case "fcitx-fullwidth-active":
    symbol = "moonphase.new.moon"
  case "fcitx-fullwidth-inactive":
    symbol = "moon.fill"
  case "fcitx-punc-active":
    let path = Bundle.main.bundlePath + "/share/png/full-punc.png"
    uiImage = UIImage(contentsOfFile: path)
    width = 32
  case "fcitx-punc-inactive":
    let path = Bundle.main.bundlePath + "/share/png/half-punc.png"
    uiImage = UIImage(contentsOfFile: path)
    width = 32
  case "fcitx-remind-active":
    symbol = "lightbulb.fill"
    width = 18
  case "fcitx-remind-inactive":
    symbol = "lightbulb"
    width = 18
  default:
    if !desc.isEmpty {
      text = String(desc.prefix(1))
    }
  }
  if let uiImage = uiImage {
    return AnyView(Image(uiImage: uiImage).resizable().scaledToFit().frame(width: width))
  }
  if let symbol = symbol {
    return AnyView(Image(systemName: symbol).resizable().scaledToFit().frame(width: width))
  }
  return AnyView(Text(text ?? "").font(.system(size: 28)))
}

struct StatusAreaView: View {
  @Environment(\.totalHeight) var totalHeight
  @Binding var actions: [StatusAreaAction]

  private let columns = [
    GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()),
  ]

  var body: some View {
    VStack(spacing: 0) {
      ReturnBarView()
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
                    getActionView(action.icon, action.desc).foregroundColor(.white)
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
      }.frame(height: getKeyboardHeight(totalHeight))
    }
  }
}
