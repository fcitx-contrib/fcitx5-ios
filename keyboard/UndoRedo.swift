import Foundation

struct UndoRedoDocumentState: Equatable {
  // Changing focus between TextFields on the same app screen may not call viewWillAppear. iOS
  // issues a new documentIdentifier even when focus returns to a previously focused TextField.
  let identifier: String
  let contextBeforeInput: String?
  let selectedText: String?
  let contextAfterInput: String?

  var lineForUndoRedo: UndoRedoLineState? {
    let selected = selectedText ?? ""
    guard !selected.contains("\n") else { return nil }

    let textBefore = lastLine(contextBeforeInput ?? "")
    let textAfter = firstLine(contextAfterInput ?? "")
    return UndoRedoLineState(
      text: textBefore + selected + textAfter,
      textBefore: textBefore,
      selectedText: selected,
      textAfter: textAfter)
  }

  fileprivate var visibleNewlineCount: Int {
    ((contextBeforeInput ?? "") + (selectedText ?? "") + (contextAfterInput ?? ""))
      .filter { $0 == "\n" }.count
  }
}

struct UndoRedoReplacement {
  let range: Range<Int>
  let text: String
  let finalCaret: Int
  let expectedText: String
}

struct UndoRedoLineState {
  let text: String
  let textBefore: String
  let selectedText: String
  let textAfter: String

  var selectionStart: Int { textBefore.count }
  var selectionEnd: Int { selectionStart + selectedText.count }
}

private struct UndoRedoOperation {
  var start: Int
  var deletedText: String
  var insertedText: String
  var beforeText: String
  var afterText: String
  var caretBefore: Int
  var caretAfter: Int
  var time: TimeInterval
}

@MainActor
final class UndoRedoManager {
  private static let mergeTimeout: TimeInterval = 5
  private static let stackLimit = 1024

  private var currentState: UndoRedoDocumentState?
  private var undoes = [UndoRedoOperation]()
  private var redoes = [UndoRedoOperation]()
  private let now: () -> TimeInterval

  init(now: @escaping () -> TimeInterval = { Date.timeIntervalSinceReferenceDate }) {
    self.now = now
  }

  var canUndo: Bool { !undoes.isEmpty }
  var canRedo: Bool { !redoes.isEmpty }

  func reset(to state: UndoRedoDocumentState? = nil) {
    currentState = state
    undoes.removeAll()
    redoes.removeAll()
  }

  /// Observes both keyboard-owned mutations and changes made through the host text view's edit
  /// menu. Selection is part of the old line, so replacing or cutting selected text is recorded as
  /// an edit instead of being mistaken for a move to another line.
  func update(to state: UndoRedoDocumentState) {
    guard let oldState = currentState else {
      currentState = state
      return
    }
    guard state != oldState else { return }
    guard state.identifier == oldState.identifier else {
      reset(to: state)
      return
    }
    guard let oldLine = oldState.lineForUndoRedo, let newLine = state.lineForUndoRedo else {
      reset(to: state)
      return
    }

    // Moving the caret or changing a selection within the current line does not change the line's
    // text. A host that only exposes the current line cannot distinguish identical lines here.
    guard oldLine.text != newLine.text else {
      currentState = state
      return
    }

    // The manager is intentionally line-scoped. Inserting or deleting a newline changes which
    // line the proxy exposes and cannot be represented as a safe line-relative replacement.
    guard oldState.visibleNewlineCount == state.visibleNewlineCount else {
      reset(to: state)
      return
    }

    guard
      let operation = calculateOperation(
        from: oldState, oldLine: oldLine, to: state, newLine: newLine)
    else {
      reset(to: state)
      return
    }

    redoes.removeAll()
    if !merge(operation) {
      undoes.append(operation)
      if undoes.count > Self.stackLimit {
        undoes.removeFirst()
      }
    }
    currentState = state
  }

  @discardableResult
  func undo(
    from state: UndoRedoDocumentState,
    applying: (UndoRedoReplacement) -> UndoRedoDocumentState?
  ) -> Bool {
    update(to: state)
    guard let operation = undoes.last,
      state.lineForUndoRedo?.text == operation.afterText
    else {
      reset(to: state)
      return false
    }

    let replacement = UndoRedoReplacement(
      range: operation.start..<(operation.start + operation.insertedText.count),
      text: operation.deletedText,
      finalCaret: operation.caretBefore,
      expectedText: operation.beforeText)
    guard let result = applying(replacement) else {
      reset(to: state)
      return false
    }
    guard result.lineForUndoRedo?.text == operation.beforeText else {
      reset(to: result)
      return false
    }

    undoes.removeLast()
    redoes.append(operation)
    currentState = result
    return true
  }

  @discardableResult
  func redo(
    from state: UndoRedoDocumentState,
    applying: (UndoRedoReplacement) -> UndoRedoDocumentState?
  ) -> Bool {
    update(to: state)
    guard var operation = redoes.last,
      state.lineForUndoRedo?.text == operation.beforeText
    else {
      reset(to: state)
      return false
    }

    let replacement = UndoRedoReplacement(
      range: operation.start..<(operation.start + operation.deletedText.count),
      text: operation.insertedText,
      finalCaret: operation.caretAfter,
      expectedText: operation.afterText)
    guard let result = applying(replacement) else {
      reset(to: state)
      return false
    }
    guard result.lineForUndoRedo?.text == operation.afterText else {
      reset(to: result)
      return false
    }

    redoes.removeLast()
    // Prevent an edit immediately after redo from merging into the restored operation.
    operation.time = 0
    undoes.append(operation)
    currentState = result
    return true
  }

  private func calculateOperation(
    from oldState: UndoRedoDocumentState, oldLine: UndoRedoLineState,
    to newState: UndoRedoDocumentState, newLine: UndoRedoLineState
  ) -> UndoRedoOperation? {
    guard newLine.selectedText.isEmpty else { return nil }

    let oldBefore = oldState.contextBeforeInput ?? ""
    let oldAfter = oldState.contextAfterInput ?? ""
    let newBefore = newState.contextBeforeInput ?? ""
    let newAfter = newState.contextAfterInput ?? ""
    let operation: UndoRedoOperation

    if newLine.text.hasPrefix(oldLine.textBefore),
      newLine.text.hasSuffix(oldLine.textAfter),
      newLine.text.count >= oldLine.textBefore.count + oldLine.textAfter.count
    {
      // Insertion, cut, and paste replace the old selection while keeping the text on both sides.
      // Constructing the operation from those sides avoids ambiguous diffs in text such as "aaa".
      let insertedText = substring(
        newLine.text,
        oldLine.textBefore.count..<(newLine.text.count - oldLine.textAfter.count))
      guard newLine.selectionStart == oldLine.selectionStart + insertedText.count,
        newAfter == oldAfter,
        newBefore == oldBefore + insertedText
      else {
        return nil
      }
      operation = makeOperation(
        start: oldLine.selectionStart,
        deletedText: oldLine.selectedText,
        insertedText: insertedText,
        oldLine: oldLine,
        newLine: newLine)
    } else if newLine.textAfter == oldLine.textAfter,
      oldLine.textBefore.hasPrefix(newLine.textBefore)
    {
      // Backspace removes a suffix immediately before the caret and leaves the right side intact.
      let deletedText = String(oldLine.textBefore.dropFirst(newLine.textBefore.count))
      guard !deletedText.isEmpty,
        newLine.selectionStart == oldLine.selectionStart - deletedText.count,
        newAfter == oldAfter,
        oldBefore == newBefore + deletedText
      else {
        return nil
      }
      operation = makeOperation(
        start: newLine.selectionStart,
        deletedText: deletedText,
        insertedText: "",
        oldLine: oldLine,
        newLine: newLine)
    } else if newLine.textBefore == oldLine.textBefore,
      oldLine.textAfter.hasSuffix(newLine.textAfter)
    {
      // Forward-delete removes a prefix immediately after the caret and leaves the left side intact.
      let deletedCount = oldLine.textAfter.count - newLine.textAfter.count
      let deletedText = String(oldLine.textAfter.prefix(deletedCount))
      guard !deletedText.isEmpty, newLine.selectionStart == oldLine.selectionStart,
        newBefore == oldBefore,
        oldAfter == deletedText + newAfter
      else {
        return nil
      }
      operation = makeOperation(
        start: oldLine.selectionStart,
        deletedText: deletedText,
        insertedText: "",
        oldLine: oldLine,
        newLine: newLine)
    } else {
      return nil
    }

    guard !operation.deletedText.isEmpty || !operation.insertedText.isEmpty else { return nil }
    return operation
  }

  private func makeOperation(
    start: Int, deletedText: String, insertedText: String,
    oldLine: UndoRedoLineState, newLine: UndoRedoLineState
  ) -> UndoRedoOperation {
    UndoRedoOperation(
      start: start,
      deletedText: deletedText,
      insertedText: insertedText,
      beforeText: oldLine.text,
      afterText: newLine.text,
      caretBefore: oldLine.selectionEnd,
      caretAfter: newLine.selectionEnd,
      time: now())
  }

  private func substring(_ text: String, _ range: Range<Int>) -> String {
    let start = text.index(text.startIndex, offsetBy: range.lowerBound)
    let end = text.index(text.startIndex, offsetBy: range.upperBound)
    return String(text[start..<end])
  }

  private func merge(_ operation: UndoRedoOperation) -> Bool {
    guard var last = undoes.last, operation.time - last.time < Self.mergeTimeout,
      last.afterText == operation.beforeText
    else {
      return false
    }

    if last.deletedText.isEmpty && operation.deletedText.isEmpty
      && last.start + last.insertedText.count == operation.start
    {
      last.insertedText += operation.insertedText
    } else if last.insertedText.isEmpty && operation.insertedText.isEmpty {
      if operation.start + operation.deletedText.count == last.start {
        last.start = operation.start
        last.deletedText = operation.deletedText + last.deletedText
      } else if last.start == operation.start {
        last.deletedText += operation.deletedText
      } else {
        return false
      }
    } else {
      return false
    }

    last.afterText = operation.afterText
    last.caretAfter = operation.caretAfter
    undoes[undoes.count - 1] = last
    return true
  }
}
