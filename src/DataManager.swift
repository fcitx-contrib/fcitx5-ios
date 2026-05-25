import AlertToast
import FcitxIpc
import SwiftUI
import SwiftUtil
import UIKit
import UniformTypeIdentifiers
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
private let hamsterRimePrefix = "HamsterBackup/RIME/Rime/"

private struct InvalidZipError: Error {}

private enum ImportSource: Sendable {
  case fcitx5
  case hamster

  var mappings: [(source: String, destination: URL)] {
    switch self {
    case .fcitx5:
      return [
        ("external/config/", appGroupConfig),
        ("external/data/", appGroupData),
      ]
    case .hamster:
      return [
        (hamsterRimePrefix, appGroupData.appendingPathComponent("rime"))
      ]
    }
  }
}

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

private func validateImportArchive(_ archive: Archive, source: ImportSource) -> Bool {
  switch source {
  case .fcitx5:
    return archive.contains { $0.path == metadataEntry }
  case .hamster:
    return archive.contains { $0.path == hamsterRimePrefix || $0.path.hasPrefix(hamsterRimePrefix) }
  }
}

private func destinationURL(root: URL, relativePath: String) throws -> URL {
  guard !relativePath.hasPrefix("/"), !relativePath.contains("\\") else {
    throw InvalidZipError()
  }

  var destination = root
  for component in relativePath.split(separator: "/", omittingEmptySubsequences: true) {
    guard component != "." && component != ".." else {
      throw InvalidZipError()
    }
    destination.appendPathComponent(String(component))
  }

  let rootPath = (root.path as NSString).standardizingPath
  let destinationPath = (destination.path as NSString).standardizingPath
  guard destinationPath == rootPath || destinationPath.hasPrefix(rootPath + "/") else {
    throw InvalidZipError()
  }
  return destination
}

private func destinationURL(for entry: Entry, source: ImportSource) throws -> URL? {
  for mapping in source.mappings where entry.path.hasPrefix(mapping.source) {
    let relativePath = String(entry.path.dropFirst(mapping.source.count))
    return try destinationURL(root: mapping.destination, relativePath: relativePath)
  }
  return nil
}

private func importArchive(from sourceURL: URL, source: ImportSource) throws {
  let scoped = sourceURL.startAccessingSecurityScopedResource()
  defer {
    if scoped {
      sourceURL.stopAccessingSecurityScopedResource()
    }
  }

  let archive = try Archive(url: sourceURL, accessMode: .read)
  guard validateImportArchive(archive, source: source) else {
    throw InvalidZipError()
  }

  for entry in archive {
    try Task.checkCancellation()
    guard let destination = try destinationURL(for: entry, source: source) else {
      continue
    }

    switch entry.type {
    case .directory:
      try? FileManager.default.removeItem(at: destination)
      try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
    case .file:
      try FileManager.default.createDirectory(
        at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
      try? FileManager.default.removeItem(at: destination)
      _ = try archive.extract(entry, to: destination)
    case .symlink:
      continue
    }
  }
}

struct DataManagerView: View {
  @State private var exporting = false
  @State private var importing = false
  @State private var importSource: ImportSource?
  @State private var showImporter = false
  @State private var exportedArchive: ExportedArchive?
  @State private var showToast = false
  @State private var toastMessage = ""
  @State private var toastIcon = "success"
  @State private var exportTask: Task<Void, Never>?
  @State private var importTask: Task<Void, Never>?
  // Cleanup test procedure (each case should see file disappears in the end):
  // 0. Open the FileManager.default.temporaryDirectory (Documents/../tmp) on macOS.
  // 1. Click export, back immediately.
  // 2. Click export, swipe down sheet.
  // 3. Click export, close sheet.
  // 4. Click export, save.
  @State private var currentExportURL: URL?

  private func displayToast(_ message: String, icon: String) {
    toastMessage = message
    toastIcon = icon
    showToast = true
  }

  private func exportData() {
    guard !exporting && !importing else {
      return
    }
    let date = Date()
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(archiveFileName(date))
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

  private func displayImporter(source: ImportSource) {
    guard !exporting && !importing else {
      return
    }
    importSource = source
    showImporter = true
  }

  private func importData(from url: URL, source: ImportSource) {
    importing = true
    importTask = Task.detached(priority: .userInitiated) {
      do {
        try importArchive(from: url, source: source)
        guard !Task.isCancelled else {
          return
        }
        await MainActor.run {
          importing = false
          requestReload()
          displayToast(NSLocalizedString("Import succeeded", comment: ""), icon: "success")
        }
      } catch is InvalidZipError {
        await MainActor.run {
          importing = false
          displayToast(NSLocalizedString("Invalid zip", comment: ""), icon: "error")
        }
      } catch {
        await MainActor.run {
          importing = false
          displayToast(NSLocalizedString("Import failed", comment: ""), icon: "error")
        }
      }
    }
  }

  var body: some View {
    Form {
      Section {
        Button {
          displayImporter(source: .fcitx5)
        } label: {
          Text("Fcitx5 Android/iOS/macOS")
        }
        .disabled(exporting || importing)
        Button {
          displayImporter(source: .hamster)
        } label: {
          Text("Hamster")
        }
        .disabled(exporting || importing)
      } header: {
        Text("Import data from …").textCase(nil)
      }

      Section {
        Button {
          exportData()
        } label: {
          Text("Fcitx5 Android/iOS/macOS")
        }
        .disabled(exporting || importing)
      } header: {
        Text("Export data to …").textCase(nil)
      }
    }
    .navigationTitle(NSLocalizedString("Data Manager", comment: ""))
    .navigationBarTitleDisplayMode(.inline)
    .fileImporter(isPresented: $showImporter, allowedContentTypes: [.zip]) { result in
      guard let source = importSource else {
        return
      }
      importSource = nil
      switch result {
      case .success(let url):
        importData(from: url, source: source)
      case .failure(let error):
        if let cocoaError = error as? CocoaError, cocoaError.code == .userCancelled {
          return
        }
        displayToast(NSLocalizedString("Import failed", comment: ""), icon: "error")
      }
    }
    .sheet(
      item: $exportedArchive,
      onDismiss: {
        if let url = currentExportURL {
          try? FileManager.default.removeItem(at: url)
          currentExportURL = nil
        }
      }
    ) { archive in
      ActivityView(activityItems: [archive.url]) { completed in
        // This callback doesn't execute if the sheet is swiped down, so can't rely on remove here.
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
    .toast(isPresenting: $importing) {
      AlertToast(
        displayMode: .alert,
        type: .loading,
        subTitle: NSLocalizedString("Importing", comment: ""),
        style: AlertToast.AlertStyle.style(subTitleFont: Font.system(size: 20)))
    }
    .onDisappear {
      exportTask?.cancel()
      importTask?.cancel()
      if let url = currentExportURL {
        try? FileManager.default.removeItem(at: url)
        currentExportURL = nil
      }
    }
  }
}
