import SwiftUI
import UIKit

struct ClipboardEntry: Identifiable {
  let id = UUID()
  let text: String
  var isPinned = false
  var sequence: UInt64
}

private struct ClipboardEntryInteraction: UIViewRepresentable {
  let onPressingChanged: (Bool) -> Void
  let onTap: () -> Void
  let onLongPress: (CGRect) -> Void
  let onSwipeChanged: (CGFloat) -> Void
  let onSwipeEnded: (CGFloat?) -> Void

  func makeUIView(context: Context) -> ClipboardGestureView {
    ClipboardGestureView(frame: .zero)
  }

  func updateUIView(_ view: ClipboardGestureView, context: Context) {
    view.onPressingChanged = onPressingChanged
    view.onTap = onTap
    view.onLongPress = onLongPress
    view.onSwipeChanged = onSwipeChanged
    view.onSwipeEnded = onSwipeEnded
  }
}

private class ClipboardGestureView: UIView, UIGestureRecognizerDelegate {
  var onPressingChanged: ((Bool) -> Void)?
  var onTap: (() -> Void)?
  var onLongPress: ((CGRect) -> Void)?
  var onSwipeChanged: ((CGFloat) -> Void)?
  var onSwipeEnded: ((CGFloat?) -> Void)?

  private lazy var pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan))

  override init(frame: CGRect) {
    super.init(frame: frame)
    pan.maximumNumberOfTouches = 1
    pan.delegate = self
    addGestureRecognizer(pan)

    let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
    addGestureRecognizer(longPress)

    let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
    tap.require(toFail: pan)
    tap.require(toFail: longPress)
    addGestureRecognizer(tap)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesBegan(touches, with: event)
    onPressingChanged?(true)
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesEnded(touches, with: event)
    onPressingChanged?(false)
  }

  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesCancelled(touches, with: event)
    onPressingChanged?(false)
  }

  override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    guard gestureRecognizer === pan else { return true }
    let translation = pan.translation(in: self)
    // Fail before recognition so a vertical drag can start the enclosing ScrollView.
    return translation.x < 0 && abs(translation.x) > abs(translation.y) * 1.2
  }

  func gestureRecognizer(
    _ gestureRecognizer: UIGestureRecognizer,
    shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
  ) -> Bool {
    guard gestureRecognizer === pan,
      let scrollView = otherGestureRecognizer.view as? UIScrollView
    else { return false }
    // The scroll recognizer waits only until this directional pan begins or fails.
    return otherGestureRecognizer === scrollView.panGestureRecognizer
  }

  @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
    onPressingChanged?(false)
    onTap?()
  }

  @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
    if gesture.state == .began {
      onLongPress?(convert(bounds, to: nil))
    }
  }

  @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
    onPressingChanged?(false)
    let translation = gesture.translation(in: self).x
    switch gesture.state {
    case .began, .changed:
      onSwipeChanged?(translation)
    case .ended:
      onSwipeEnded?(translation)
    case .cancelled, .failed:
      onSwipeEnded?(nil)
    default:
      break
    }
  }
}

private struct ClipboardEntryView: View {
  @Environment(\.colorScheme) private var colorScheme
  @State private var isPressed = false
  @State private var swipeOffset: CGFloat = 0

  let entry: ClipboardEntry
  let onDelete: (UUID) -> Void

  private let deleteThreshold: CGFloat = 60

  private func commitEntry() {
    guard !vm.showMenu else { return }
    client.commitString(entry.text)
  }

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
    .overlay {
      ClipboardEntryInteraction(
        onPressingChanged: { isPressed = $0 },
        onTap: commitEntry,
        onLongPress: { frame in
          guard !vm.showMenu else { return }
          vm.showContextMenu(
            frame,
            [
              MenuItem(
                text: entry.isPinned
                  ? NSLocalizedString("Unpin", comment: "")
                  : NSLocalizedString("Pin", comment: ""),
                action: { vm.toggleClipboardEntryPin(entry.id) }),
              MenuItem(
                text: NSLocalizedString("Delete", comment: ""),
                action: { onDelete(entry.id) }),
            ])
        },
        onSwipeChanged: { translation in
          swipeOffset = vm.showMenu ? 0 : min(0, translation)
        },
        onSwipeEnded: { translation in
          withAnimation(.easeOut(duration: 0.15)) {
            swipeOffset = 0
            if !vm.showMenu, let translation, translation < -deleteThreshold {
              onDelete(entry.id)
            }
          }
        })
    }
    .accessibilityAddTraits(.isButton)
    .accessibilityAction { commitEntry() }
  }
}

struct ClipboardView: View {
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.totalHeight) private var totalHeight
  @ObservedObject private var viewModel = vm

  let width: CGFloat

  @State private var showClearConfirmation = false
  @State private var clearIncludesPinned = false
  @State private var pendingDeletedEntries = [ClipboardEntry]()
  @State private var toastDismissID = UUID()
  @State private var isMonitoring = false
  @State private var showMonitorFullAccessDialog = false

  private let toastDuration: UInt64 = 3_000_000_000

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

  private var deletedItemsMessage: String {
    String.localizedStringWithFormat(
      NSLocalizedString("%lld item(s) deleted", comment: ""),
      Int64(pendingDeletedEntries.count))
  }

  private var monitorBinding: Binding<Bool> {
    Binding(
      get: { isMonitoring },
      set: { enabled in
        isMonitoring = enabled
        client.setClipboardMonitoring(enabled)
        if enabled && !client.hasKeyboardFullAccess() {
          showMonitorFullAccessDialog = true
        }
      })
  }

  private func deleteEntry(_ id: UUID) {
    guard let deletedEntry = viewModel.deleteClipboardEntry(id) else { return }
    showUndoToast(for: [deletedEntry])
  }

  private func showUndoToast(for deletedEntries: [ClipboardEntry]) {
    guard !deletedEntries.isEmpty else { return }
    pendingDeletedEntries.append(contentsOf: deletedEntries)
    toastDismissID = UUID()
  }

  private func undoDelete() {
    let deletedEntries = pendingDeletedEntries
    dismissUndoToast(animated: false)
    withAnimation(.easeOut(duration: 0.15)) {
      viewModel.restoreClipboardEntries(deletedEntries)
    }
  }

  private func dismissUndoToast(animated: Bool) {
    toastDismissID = UUID()
    if animated {
      withAnimation(.easeOut(duration: 0.35)) {
        pendingDeletedEntries.removeAll()
      }
    } else {
      var transaction = Transaction()
      transaction.disablesAnimations = true
      withTransaction(transaction) {
        pendingDeletedEntries.removeAll()
      }
    }
  }

  var body: some View {
    ZStack(alignment: .bottom) {
      VStack(spacing: 0) {
        ReturnBarView(width: width, title: NSLocalizedString("Clipboard", comment: "")) {
          HStack(spacing: 4) {
            Text("Monitor")
            Toggle("", isOn: monitorBinding)
              .labelsHidden()
              .accessibilityLabel(Text("Monitor"))
              .fixedSize()
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
                    ClipboardEntryView(entry: entry, onDelete: deleteEntry)
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
      if !pendingDeletedEntries.isEmpty {
        ToastView(
          message: deletedItemsMessage,
          actionTitle: NSLocalizedString("Undo", comment: ""),
          action: undoDelete
        )
        .frame(width: min(max(width - 48, 0), 480))
        .padding(.bottom, 16)
        .transition(.opacity)
      }
      if showClearConfirmation {
        DialogView(
          width: width,
          height: totalHeight,
          message: clearConfirmationMessage,
          actions: [
            DialogAction(NSLocalizedString("Cancel", comment: "")),
            DialogAction(NSLocalizedString("Clear", comment: ""), role: .destructive) {
              showUndoToast(
                for: viewModel.clearClipboard(includePinned: clearIncludesPinned))
            },
          ],
          onDismiss: { showClearConfirmation = false })
      }
      if showMonitorFullAccessDialog {
        DialogView(
          width: width,
          height: totalHeight,
          message: NSLocalizedString(
            "Full access is required to monitor the clipboard.", comment: ""),
          detail: NSLocalizedString(
            "In the Fcitx5 main app, tap \"Full Access\", then follow the instructions at the bottom of the page.",
            comment: ""),
          actions: [
            DialogAction(NSLocalizedString("OK", comment: "")),
            DialogAction(NSLocalizedString("Close", comment: "")) {
              monitorBinding.wrappedValue = false
            },
          ],
          onDismiss: { showMonitorFullAccessDialog = false })
      }
    }
    .task(id: toastDismissID) {
      guard !pendingDeletedEntries.isEmpty else { return }
      let dismissID = toastDismissID
      do {
        try await Task.sleep(nanoseconds: toastDuration)
      } catch {
        return
      }
      guard !Task.isCancelled, toastDismissID == dismissID else { return }
      dismissUndoToast(animated: true)
    }
    .onAppear {
      isMonitoring = client.clipboardMonitoringEnabled()
      if isMonitoring && !client.hasKeyboardFullAccess() {
        showMonitorFullAccessDialog = true
      }
    }
    .onDisappear {
      dismissUndoToast(animated: false)
    }
  }
}
