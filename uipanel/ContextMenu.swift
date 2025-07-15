import SwiftUI

struct MenuItem: Identifiable {
  let id = UUID()
  let text: String
  let action: () -> Void
}

struct ContextMenuOverlay: View {
  let items: [MenuItem]
  let frame: CGRect
  let containerSize: CGSize
  let onDismiss: () -> Void

  @State private var menuSize: CGSize = .zero
  @State private var adjustedPosition: CGPoint = .zero
  @State private var hasScroll = false

  var body: some View {
    ZStack {
      Color.black.opacity(0.001)
        .ignoresSafeArea()
        .onTapGesture {
          hasScroll = false
          onDismiss()
        }

      let menu = VStack {
        ForEach(items) { item in
          Button {
            item.action()
            onDismiss()
          } label: {
            Text(item.text)
              .foregroundColor(.black)
              .padding(.vertical, 8)
          }.frame(minWidth: 0, maxWidth: containerSize.width * 0.6)
        }
      }
      // If we wrap with ScrollView when not needed, the height will be extended.
      if hasScroll {
        ScrollView {
          menu.background(Color.white)
        }.cornerRadius(8)
          .shadow(radius: 4)
          .position(adjustedPosition)
      } else {
        menu.background(
          GeometryReader { geometry in
            Color.white
              .onAppear {
                menuSize = geometry.size
                adjustedPosition = adjustPosition()
              }
          }
        ).cornerRadius(8)
          .shadow(radius: 4)
          .position(adjustedPosition)
      }
    }
  }

  private func adjustPosition() -> CGPoint {
    let x = max(min(frame.minX, containerSize.width - menuSize.width), 0)
    var y = frame.maxY

    // First step: place it above or below the target element.
    if frame.midY > containerSize.height / 2 {
      y = frame.minY - menuSize.height
    }
    // Next step: adjust the bottom position if it exceeds the container.
    // Final step: adjust the top position if it exceeds the container.
    y = max(min(containerSize.height - menuSize.height, y), 0)
    if menuSize.height > containerSize.height {
      hasScroll = true
    }
    return CGPoint(x: x + menuSize.width / 2, y: y + min(containerSize.height, menuSize.height) / 2)
  }
}

// To get element frame on long press.
struct LongPressMeasureModifier: ViewModifier {
  let getMenuItems: () -> [MenuItem]
  @State private var showMeasurement = false

  func body(content: Content) -> some View {
    ZStack {
      content
        .onLongPressGesture {
          showMeasurement = true
        }

      if showMeasurement {
        GeometryReader { geometry in
          Color.clear
            .onAppear {
              let frame = geometry.frame(in: .global)
              let items = getMenuItems()
              showMeasurement = false
              if items.isEmpty {
                return
              }
              virtualKeyboardView.showContextMenu(frame, items)
            }
        }
      }
    }
  }
}

extension View {
  func onContextMenu(_ getMenuItems: @escaping () -> [MenuItem]) -> some View {
    self.modifier(LongPressMeasureModifier(getMenuItems: getMenuItems))
  }
}
