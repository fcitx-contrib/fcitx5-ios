import AlertToast
import SwiftUI
import SwiftUtil
import UIKit
import ZIPFoundation

private struct ExportedArchive: Identifiable {
  let url: URL
  let id = UUID()
}

private struct ArchiveEntry {
  let sourceURL: URL?
  let archivePath: String
  let isDirectory: Bool
}

private struct ActivityView: UIViewControllerRepresentable {
  let activityItems: [Any]
  let onComplete: (Bool) -> Void

  func makeUIViewController(context: Context) -> UIActivityViewController {
    let controller = UIActivityViewController(
      activityItems: activityItems, applicationActivities: nil)
    controller.popoverPresentationController?.sourceView = controller.view
    controller.completionWithItemsHandler = { _, completed, _, _ in
      onComplete(completed)
    }
    return controller
  }

  func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private let fcitx5ExportMappings = [
  (source: appGroupConfig, destination: "external/config/"),
  (source: appGroupData, destination: "external/data/"),
]

private let requiredDirectoryEntries = [
  "external/",
  "databases/",
  "recently_used/",
  "shared_prefs/",
]

private let metadataEntry = "metadata.json"

private func archiveFileName(_ date: Date) -> String {
  let formatter = ISO8601DateFormatter()
  formatter.formatOptions = [.withInternetDateTime]
  let timestamp = formatter.string(from: date).replacingOccurrences(of: ":", with: "_")
  return "fcitx5-ios_\(timestamp).zip"
}

private func getMetadata(_ date: Date) throws -> Data {
  let object: [String: Any] = [
    "packageName": "org.fcitx.fcitx5.android",
    "versionCode": 0,
    "versionName": "",
    "exportTime": Int64(date.timeIntervalSince1970 * 1000),
  ]
  return try JSONSerialization.data(withJSONObject: object)
}

private func collectEntries() -> [ArchiveEntry] {
  var entries = [ArchiveEntry]()

  for mapping in fcitx5ExportMappings {
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: mapping.source.path, isDirectory: &isDirectory),
      isDirectory.boolValue
    else {
      continue
    }

    entries.append(
      ArchiveEntry(sourceURL: nil, archivePath: mapping.destination, isDirectory: true))

    guard
      let enumerator = FileManager.default.enumerator(
        at: mapping.source,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [])
    else {
      continue
    }

    for case let url as URL in enumerator {
      let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
      let isDirectory = values?.isDirectory == true
      let basePath = ((mapping.source.path as NSString).standardizingPath as String) + "/"
      let path = (url.path as NSString).standardizingPath
      guard path.hasPrefix(basePath) else {
        continue
      }
      let relativePath = String(path.dropFirst(basePath.count))
      let archivePath = mapping.destination + relativePath + (isDirectory ? "/" : "")
      entries.append(
        ArchiveEntry(
          sourceURL: isDirectory ? nil : url, archivePath: archivePath, isDirectory: isDirectory))
    }
  }

  return entries
}

private func addDirectory(_ path: String, to archive: Archive) throws {
  try archive.addEntry(
    with: path.hasSuffix("/") ? path : path + "/",
    type: .directory,
    uncompressedSize: Int64(0),
    provider: { _, _ in Data() })
}

private func createExportArchive(at destinationURL: URL, date: Date) throws {
  let entries = collectEntries()

  try? FileManager.default.removeItem(at: destinationURL)

  var success = false
  defer {
    if !success {
      try? FileManager.default.removeItem(at: destinationURL)
    }
  }

  let archive = try Archive(url: destinationURL, accessMode: .create)
  var addedDirectories = Set<String>()

  for path in requiredDirectoryEntries {
    try addDirectory(path, to: archive)
    addedDirectories.insert(path)
  }

  for entry in entries.filter({ $0.isDirectory }).sorted(by: { $0.archivePath < $1.archivePath })
  where !addedDirectories.contains(entry.archivePath) {
    try addDirectory(entry.archivePath, to: archive)
    addedDirectories.insert(entry.archivePath)
  }

  for entry in entries.filter({ !$0.isDirectory }).sorted(by: { $0.archivePath < $1.archivePath }) {
    if let sourceURL = entry.sourceURL {
      try archive.addEntry(
        with: entry.archivePath,
        fileURL: sourceURL,
        compressionMethod: .deflate)
    }
  }

  let metadata = try getMetadata(date)
  try archive.addEntry(
    with: metadataEntry,
    type: .file,
    uncompressedSize: Int64(metadata.count),
    compressionMethod: .deflate,
    provider: { position, size in
      let start = Int(position)
      let end = min(start + size, metadata.count)
      return metadata.subdata(in: start..<end)
    })

  success = true
}

struct DataManagerView: View {
  @State private var exporting = false
  @State private var exportedArchive: ExportedArchive?
  @State private var showToast = false
  @State private var toastMessage = ""
  @State private var toastIcon = "success"
  @State private var exportTask: Task<Void, Never>?
  // Cleanup test procedure:
  // 0. Open the FileManager.default.temporaryDirectory directory.
  // 1. Click export, back immediately, see file disappears.
  // 2. Click export, close sheet, see file disappears.
  // 3. Click export, save, see file disappears.
  // 4. Click export, swipe down sheet, see file remains;
  // 5. Click export, see old file replaced, swipe down sheet, back, see file disappears.
  @State private var currentExportURL: URL?

  private func displayToast(_ message: String, icon: String) {
    toastMessage = message
    toastIcon = icon
    showToast = true
  }

  private func exportData() {
    let date = Date()
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(archiveFileName(date))
    if let oldURL = currentExportURL {
      try? FileManager.default.removeItem(at: oldURL)
    }
    currentExportURL = url
    exporting = true
    exportTask = Task.detached(priority: .userInitiated) {
      do {
        try createExportArchive(at: url, date: date)
        guard !Task.isCancelled else {
          try? FileManager.default.removeItem(at: url)
          return
        }
        await MainActor.run {
          exporting = false
          exportedArchive = ExportedArchive(url: url)
        }
      } catch {
        await MainActor.run {
          exporting = false
          displayToast(NSLocalizedString("Export failed", comment: ""), icon: "error")
        }
      }
    }
  }

  var body: some View {
    Form {
      Section {
        Button {
          exportData()
        } label: {
          Text("Fcitx5 Android/iOS/macOS")
        }
        .disabled(exporting)
      } header: {
        Text("Export data to …").textCase(nil)
      }
    }
    .navigationTitle(NSLocalizedString("Data Manager", comment: ""))
    .navigationBarTitleDisplayMode(.inline)
    .sheet(item: $exportedArchive) { archive in
      ActivityView(activityItems: [archive.url]) { completed in
        // This callback doesn't execute if the sheet is swiped down, so can't rely on remove here.
        try? FileManager.default.removeItem(at: archive.url)
        exportedArchive = nil
        if completed {
          displayToast(NSLocalizedString("Export succeeded", comment: ""), icon: "success")
        }
      }
    }
    .toast(isPresenting: $showToast) {
      AlertToast(
        displayMode: .alert,
        type: toastIcon == "error" ? .error(Color.red) : .complete(Color.green),
        subTitle: toastMessage,
        style: AlertToast.AlertStyle.style(subTitleFont: Font.system(size: 20)))
    }
    .toast(isPresenting: $exporting) {
      AlertToast(
        displayMode: .alert,
        type: .loading,
        subTitle: NSLocalizedString("Exporting", comment: ""),
        style: AlertToast.AlertStyle.style(subTitleFont: Font.system(size: 20)))
    }
    .onDisappear {
      exportTask?.cancel()
      if let url = currentExportURL {
        try? FileManager.default.removeItem(at: url)
        currentExportURL = nil
      }
    }
  }
}
