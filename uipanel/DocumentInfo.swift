import FcitxProtocol
import Foundation
import SwiftUI

private func paddedHex(_ value: UInt32, minimumWidth: Int) -> String {
  let hex = String(value, radix: 16, uppercase: true)
  return String(repeating: "0", count: max(0, minimumWidth - hex.count)) + hex
}

private func scalarDisplay(_ scalar: Unicode.Scalar) -> String {
  switch scalar.value {
  case 0x00:
    return "\\0"
  case 0x09:
    return "\\t"
  case 0x0A:
    return "\\n"
  case 0x0D:
    return "\\r"
  case 0x20:
    return "SP"
  case 0x7F:
    return "DEL"
  case 0xA0:
    return "NBSP"
  case 0x200B:
    return "ZERO WIDTH SPACE"
  case 0x200C:
    return "ZERO WIDTH NON-JOINER"
  case 0x200D:
    return "ZERO WIDTH JOINER"
  case 0x2028:
    return "LINE SEPARATOR"
  case 0x2029:
    return "PARAGRAPH SEPARATOR"
  case 0x2060:
    return "WORD JOINER"
  case 0xFEFF:
    return "BOM / ZERO WIDTH NBSP"
  case 0x01...0x1F, 0x80...0x9F:
    return "CONTROL"
  default:
    return String(scalar)
  }
}

private func dumpScalars(_ text: String?) -> String {
  guard let text else { return "nil" }

  var lines = ["UTF16  scalar  display"]
  var utf16Offset = 0
  for scalar in text.unicodeScalars {
    let offset = String(utf16Offset)
    let paddedOffset = String(repeating: "0", count: max(0, 5 - offset.count)) + offset
    let scalarText = "U+" + paddedHex(scalar.value, minimumWidth: 4)
    let scalarPadding = String(repeating: " ", count: max(1, 8 - scalarText.count))
    lines.append("\(paddedOffset)  \(scalarText)\(scalarPadding)\(scalarDisplay(scalar))")
    utf16Offset += scalar.value > 0xFFFF ? 2 : 1
  }
  let endOffset = String(utf16Offset)
  lines.append(String(repeating: "0", count: max(0, 5 - endOffset.count)) + endOffset)
  return lines.joined(separator: "\n")
}

private func processStartDescription(_ startTime: Date, capturedAt: Date) -> String {
  let formatter = DateFormatter()
  formatter.locale = Locale(identifier: "en_US_POSIX")
  formatter.timeZone = .current
  formatter.dateFormat = "yyyy-MM-dd HH:mm"

  let totalMinutes = max(0, Int(capturedAt.timeIntervalSince(startTime)) / 60)
  let durationFormatter = DateComponentsFormatter()
  durationFormatter.unitsStyle = .abbreviated
  if totalMinutes >= 24 * 60 {
    durationFormatter.allowedUnits = [.day, .hour, .minute]
  } else if totalMinutes >= 60 {
    durationFormatter.allowedUnits = [.hour, .minute]
  } else {
    durationFormatter.allowedUnits = [.minute]
  }
  durationFormatter.zeroFormattingBehavior = .dropLeading
  let duration = durationFormatter.string(from: TimeInterval(totalMinutes * 60)) ?? ""
  return "\(formatter.string(from: startTime)) (\(duration))"
}

private struct DocumentInfoField: View {
  let name: String
  let value: String

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(name).font(.caption).foregroundColor(.secondary)
      Text(value)
        .font(.system(size: 11, design: .monospaced))
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

struct DocumentInfoView: View {
  @Environment(\.totalHeight) var totalHeight
  let width: CGFloat
  let info: DocumentInfo?

  var body: some View {
    VStack(spacing: 0) {
      ReturnBarView(width: width)
      ZStack(alignment: .topTrailing) {
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 14) {
            if let info {
              DocumentInfoField(
                name: "processStartTime",
                value: processStartDescription(
                  info.processStartTime, capturedAt: info.capturedAt))
              DocumentInfoField(
                name: "currentDocumentIdentifier",
                value: info.currentDocumentIdentifier ?? "nil")
              DocumentInfoField(name: "keyboardType", value: info.keyboardType)
              DocumentInfoField(
                name: "documentContextBeforeInput",
                value: dumpScalars(info.documentContextBeforeInput))
              DocumentInfoField(
                name: "selectedText",
                value: dumpScalars(info.selectedText))
              DocumentInfoField(
                name: "documentContextAfterInput",
                value: dumpScalars(info.documentContextAfterInput))
            } else {
              Text("Document information is unavailable.")
            }
          }.padding()
        }.frame(height: getKeyboardHeight(totalHeight))
        Button {
          vm.refreshDocumentInfo()
        } label: {
          Image(systemName: "arrow.clockwise")
            .foregroundColor(.primary)
            .frame(width: getBarHeight(totalHeight), height: getBarHeight(totalHeight))
        }.accessibilityIdentifier("Refresh document info")
      }
    }
  }
}
