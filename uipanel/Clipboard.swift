import SwiftUI

struct ClipboardEntry: Identifiable {
  let id = UUID()
  let text: String
  var isPinned = false
  var sequence: UInt64
}

private struct ClipboardEntryView: View {
  @Environment(\.colorScheme) private var colorScheme
  @State private var isPressed = false
  @State private var swipeOffset: CGFloat = 0

  let entry: ClipboardEntry

  private let deleteThreshold: CGFloat = 60

  var body: some View {
    ZStack(alignment: .trailing) {
      if swipeOffset < 0 {
        Color.red
        Image(systemName: "trash")
          .foregroundColor(.white)
          .padding(.trailing, 16)
      }

      Text(entry.text)
        .font(.system(size: 14))
        .foregroundColor(getNormalForeground(colorScheme))
        .lineLimit(4)
        .multilineTextAlignment(.leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .padding(.trailing, entry.isPinned ? 10 : 0)
        .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
        .background(
          (isPressed ? getFunctionBackground(colorScheme) : getNormalBackground(colorScheme))
            .blend(with: getBackground(colorScheme))
        )
        .cornerRadius(8)
        .overlay(alignment: .bottomTrailing) {
          if entry.isPinned {
            Image(systemName: "pin.fill")
              .font(.system(size: 9))
              .foregroundColor(getNormalForeground(colorScheme).opacity(0.4))
              .padding(4)
          }
        }
        .offset(x: swipeOffset)
    }
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .contentShape(RoundedRectangle(cornerRadius: 8))
    .onContextMenu(
      onPressingChanged: { pressing in
        isPressed = pressing
      },
      {
        [
          MenuItem(
            text: entry.isPinned
              ? NSLocalizedString("Unpin", comment: "")
              : NSLocalizedString("Pin", comment: ""),
            action: { vm.toggleClipboardEntryPin(entry.id) }),
          MenuItem(
            text: NSLocalizedString("Delete", comment: ""),
            action: { vm.deleteClipboardEntry(entry.id) }),
        ]
      }
    )
    .simultaneousGesture(
      DragGesture(minimumDistance: 10)
        .onChanged { value in
          guard !vm.showMenu else {
            swipeOffset = 0
            return
          }
          guard abs(value.translation.width) > abs(value.translation.height) else { return }
          swipeOffset = min(0, value.translation.width)
        }
        .onEnded { value in
          guard !vm.showMenu else {
            swipeOffset = 0
            return
          }
          let isHorizontal = abs(value.translation.width) > abs(value.translation.height)
          if isHorizontal && value.translation.width < -deleteThreshold {
            withAnimation(.easeOut(duration: 0.15)) {
              vm.deleteClipboardEntry(entry.id)
            }
          } else {
            withAnimation(.easeOut(duration: 0.15)) {
              swipeOffset = 0
            }
          }
        }
        .exclusively(
          before: TapGesture()
            .onEnded {
              guard !vm.showMenu else { return }
              client.commitString(entry.text)
            }
        )
    )
  }
}

struct ClipboardView: View {
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.totalHeight) private var totalHeight
  @ObservedObject private var viewModel = vm

  let width: CGFloat

  @State private var showClearConfirmation = false
  @State private var clearIncludesPinned = false

  private var hasUnpinnedEntries: Bool {
    viewModel.clipboardEntries.contains { !$0.isPinned }
  }

  private func entries(inColumn column: Int) -> [ClipboardEntry] {
    viewModel.clipboardEntries.enumerated().compactMap { index, entry in
      index % 2 == column ? entry : nil
    }
  }

  private var clearConfirmationMessage: String {
    if clearIncludesPinned {
      return NSLocalizedString("Delete all pinned items?", comment: "")
    }
    if viewModel.clipboardEntries.contains(where: { $0.isPinned }) {
      return NSLocalizedString("Delete all items except pinned ones?", comment: "")
    }
    return NSLocalizedString("Delete all items?", comment: "")
  }

  var body: some View {
    ZStack {
      VStack(spacing: 0) {
        ReturnBarView(width: width, title: NSLocalizedString("Clipboard", comment: "")) {
          Button {
            clearIncludesPinned = !hasUnpinnedEntries
            showClearConfirmation = true
          } label: {
            Image(systemName: "trash")
              .foregroundColor(
                viewModel.clipboardEntries.isEmpty
                  ? disabledForeground : getNormalForeground(colorScheme)
              )
              .frame(width: getBarHeight(totalHeight), height: getBarHeight(totalHeight))
          }
          .disabled(viewModel.clipboardEntries.isEmpty)
        }
        if viewModel.clipboardEntries.isEmpty {
          VStack(spacing: 12) {
            Image(systemName: "doc.on.clipboard")
              .font(.system(size: 72))
              .foregroundColor(disabledForeground)
            Text("Try copying something")
              .foregroundColor(getNormalForeground(colorScheme))
          }
          .frame(width: width, height: getKeyboardHeight(totalHeight))
        } else {
          ScrollView {
            HStack(alignment: .top, spacing: 8) {
              ForEach(0..<2) { column in
                LazyVStack(spacing: 8) {
                  ForEach(entries(inColumn: column)) { entry in
                    ClipboardEntryView(entry: entry)
                  }
                }
                .frame(maxWidth: .infinity)
              }
            }
            .padding(4)
          }
          .frame(width: width, height: getKeyboardHeight(totalHeight))
        }
      }
      if showClearConfirmation {
        DialogView(
          width: width,
          height: totalHeight,
          message: clearConfirmationMessage,
          actions: [
            DialogAction(NSLocalizedString("Cancel", comment: "")),
            DialogAction(NSLocalizedString("Clear", comment: ""), role: .destructive) {
              viewModel.clearClipboard(includePinned: clearIncludesPinned)
            },
          ],
          onDismiss: { showClearConfirmation = false })
      }
    }
  }
}
