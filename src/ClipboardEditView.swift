import SwiftUI
import SwiftUtil

struct ClipboardEditView: View {
  let request: ClipboardEditRequest
  let onSaved: () -> Void

  @State private var text: String
  @State private var isSaving = false
  @State private var errorMessage: String?
  @FocusState private var isFocused: Bool
  @Environment(\.dismiss) private var dismiss

  init(request: ClipboardEditRequest, onSaved: @escaping () -> Void) {
    self.request = request
    self.onSaved = onSaved
    _text = State(initialValue: request.text)
  }

  private func save() {
    guard !isSaving else { return }
    guard text != request.text else {
      dismiss()
      return
    }
    isSaving = true
    errorMessage = nil
    let request = request
    let updatedText = text
    Task {
      defer { isSaving = false }
      do {
        try await Task.detached {
          try clipboardStore.edit(request, text: updatedText, allowInsert: !appGroupAvailable)
        }.value
        isFocused = false
        onSaved()
      } catch ClipboardStore.EditFailure.duplicateText {
        errorMessage = NSLocalizedString("This text already exists in the clipboard.", comment: "")
      } catch ClipboardStore.EditFailure.missingEntry {
        errorMessage = NSLocalizedString("This clipboard item is no longer available.", comment: "")
      } catch ClipboardStore.EditFailure.emptyText {
        errorMessage = NSLocalizedString("Clipboard text cannot be empty.", comment: "")
      } catch {
        errorMessage = error.localizedDescription
      }
    }
  }

  var body: some View {
    VStack {
      TextEditor(text: $text)
        .focused($isFocused)
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .accessibilityIdentifier("ClipboardEditText")
      if let errorMessage {
        Text(errorMessage)
          .foregroundColor(.red)
      }
    }
    .padding()
    .navigationTitle(NSLocalizedString("Edit clipboard item", comment: ""))
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button {
          dismiss()
        } label: {
          Text("Cancel")
        }
        .disabled(isSaving)
      }
      ToolbarItem(placement: .confirmationAction) {
        Button {
          save()
        } label: {
          Text("Save")
        }
        .disabled(isSaving || !text.contains(where: { !$0.isWhitespace }))
      }
    }
    // Keep the text view alive when switching items; replacing it can dismiss the keyboard.
    .task(id: request.id) {
      isFocused = false
      text = request.text
      errorMessage = nil
      // Let UIKit apply the old focus change before requesting the keyboard again.
      do { try await Task.sleep(nanoseconds: 200_000_000) } catch { return }
      guard !Task.isCancelled else { return }
      isFocused = true
    }
    .interactiveDismissDisabled(isSaving)
  }
}
