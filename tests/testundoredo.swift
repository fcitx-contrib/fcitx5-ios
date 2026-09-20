import Foundation

@MainActor
private final class TestContext {
  var failures = 0

  func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
      print("FAILED: \(message)")
      failures += 1
    }
  }
}

@MainActor
private func state(
  _ text: String, _ caret: Int, selected: Range<Int>? = nil,
  identifier: String = "document", beforePrefix: String = "", afterSuffix: String = ""
) -> UndoRedoDocumentState {
  let selection = selected ?? caret..<caret
  let start = text.index(text.startIndex, offsetBy: selection.lowerBound)
  let end = text.index(text.startIndex, offsetBy: selection.upperBound)
  return UndoRedoDocumentState(
    identifier: identifier,
    contextBeforeInput: beforePrefix + text[..<start],
    selectedText: String(text[start..<end]),
    contextAfterInput: String(text[end...]) + afterSuffix)
}

@MainActor
private func replace(
  _ replacement: UndoRedoReplacement, text: inout String,
  currentState: inout UndoRedoDocumentState
) -> UndoRedoDocumentState? {
  guard replacement.range.lowerBound >= 0,
    replacement.range.upperBound <= text.count,
    replacement.finalCaret >= 0,
    replacement.finalCaret <= replacement.expectedText.count
  else {
    return nil
  }

  let start = text.index(text.startIndex, offsetBy: replacement.range.lowerBound)
  let end = text.index(text.startIndex, offsetBy: replacement.range.upperBound)
  text.replaceSubrange(start..<end, with: replacement.text)
  currentState = state(text, replacement.finalCaret)
  return currentState
}

@MainActor
private func testInsertMergeAndRedo(_ test: TestContext) {
  var time: TimeInterval = 0
  let manager = UndoRedoManager(now: { time })
  var text = "x"
  var currentState = state(text, 1)
  manager.reset(to: currentState)

  time = 1
  text = "xa"
  currentState = state(text, 2)
  manager.update(to: currentState)
  time = 4
  text = "xab"
  currentState = state(text, 3)
  manager.update(to: currentState)

  test.expect(manager.canUndo, "continuous insertion should enable undo")
  test.expect(
    manager.undo(from: currentState) {
      replace($0, text: &text, currentState: &currentState)
    }, "continuous insertion should undo")
  test.expect(text == "x", "inserts within five seconds should merge")
  test.expect(manager.canRedo, "undo should enable redo")
  test.expect(
    manager.redo(from: currentState) {
      replace($0, text: &text, currentState: &currentState)
    }, "merged insertion should redo")
  test.expect(text == "xab", "redo should restore the merged insertion")
}

@MainActor
private func testMergeTimeout(_ test: TestContext) {
  var time: TimeInterval = 0
  let manager = UndoRedoManager(now: { time })
  var text = ""
  var currentState = state(text, 0)
  manager.reset(to: currentState)

  text = "a"
  currentState = state(text, 1)
  manager.update(to: currentState)
  time = 5
  text = "ab"
  currentState = state(text, 2)
  manager.update(to: currentState)
  _ = manager.undo(from: currentState) {
    replace($0, text: &text, currentState: &currentState)
  }
  test.expect(text == "a", "transactions at the five-second boundary must not merge")
}

@MainActor
private func testBackspaceMerge(_ test: TestContext) {
  let manager = UndoRedoManager(now: { 0 })
  var text = "abc"
  var currentState = state(text, 3)
  manager.reset(to: currentState)

  text = "ab"
  currentState = state(text, 2)
  manager.update(to: currentState)
  text = "a"
  currentState = state(text, 1)
  manager.update(to: currentState)
  _ = manager.undo(from: currentState) {
    replace($0, text: &text, currentState: &currentState)
  }
  test.expect(text == "abc", "continuous backspace should merge")
}

@MainActor
private func testSelectionReplacementWithRepeatedText(_ test: TestContext) {
  let manager = UndoRedoManager(now: { 0 })
  var text = "aaa"
  var currentState = state(text, 1)
  manager.reset(to: currentState)

  currentState = state(text, 1, selected: 1..<2)
  manager.update(to: currentState)
  text = "aba"
  currentState = state(text, 2)
  manager.update(to: currentState)
  test.expect(manager.canUndo, "host paste over a selection should be recorded")
  _ = manager.undo(from: currentState) {
    replace($0, text: &text, currentState: &currentState)
  }
  test.expect(text == "aaa", "selection anchors should disambiguate repeated text")
}

@MainActor
private func testCutFromHostEditMenu(_ test: TestContext) {
  let manager = UndoRedoManager(now: { 0 })
  var text = "before selected after"
  var currentState = state(text, 7, selected: 7..<15)
  manager.reset(to: currentState)

  text = "before  after"
  currentState = state(text, 7)
  manager.update(to: currentState)
  _ = manager.undo(from: currentState) {
    replace($0, text: &text, currentState: &currentState)
  }
  test.expect(text == "before selected after", "host cut should preserve both selection anchors")
}

@MainActor
private func testCaretMoveWithinLine(_ test: TestContext) {
  let manager = UndoRedoManager(now: { 0 })
  var text = "abc"
  var currentState = state("ab", 2)
  manager.reset(to: currentState)
  currentState = state(text, 3)
  manager.update(to: currentState)

  currentState = state(text, 0)
  manager.update(to: currentState)
  _ = manager.undo(from: currentState) {
    replace($0, text: &text, currentState: &currentState)
  }
  test.expect(text == "ab", "same-line caret movement should preserve undo history")
}

@MainActor
private func testHistoryInvalidation(_ test: TestContext) {
  let manager = UndoRedoManager(now: { 0 })
  manager.reset(to: state("abc", 3, afterSuffix: "\nab"))
  manager.update(to: state("ab", 2, beforePrefix: "abc\n"))
  test.expect(!manager.canUndo && !manager.canRedo, "moving to another line should clear history")

  manager.reset(to: state("abc", 3))
  manager.update(to: state("abcd", 4))
  manager.update(to: state("abcd", 4, identifier: "other-document"))
  test.expect(!manager.canUndo && !manager.canRedo, "changing documents should clear history")

  manager.reset(to: state("abc", 3))
  manager.update(to: state("", 0, beforePrefix: "abc\n"))
  test.expect(!manager.canUndo && !manager.canRedo, "newline edits should clear line-scoped history")
}

@main
struct UndoRedoTest {
  @MainActor
  static func main() {
    let test = TestContext()
    testInsertMergeAndRedo(test)
    testMergeTimeout(test)
    testBackspaceMerge(test)
    testSelectionReplacementWithRepeatedText(test)
    testCutFromHostEditMenu(test)
    testCaretMoveWithinLine(test)
    testHistoryInvalidation(test)
    if test.failures > 0 {
      fatalError("\(test.failures) undo/redo tests failed")
    }
  }
}
