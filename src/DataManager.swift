import AlertToast
import FcitxIpc
import SwiftUI
import SwiftUtil
import UIKit
import UniformTypeIdentifiers

private struct ExportedArchive: Identifiable {
  let url: URL
  let id = UUID()
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

private let backupArchive = BackupArchive(
  configDirectory: appGroupConfig,
  dataDirectory: appGroupData,
  databasesDirectory: clipboardDatabases,
  clipboardStore: clipboardStore)

private func archiveFileName(_ date: Date) -> String {
  let formatter = ISO8601DateFormatter()
  formatter.formatOptions = [.withInternetDateTime]
  let timestamp = formatter.string(from: date).replacingOccurrences(of: ":", with: "_")
  return "fcitx5-ios_\(timestamp).zip"
}

private func importArchive(from sourceURL: URL, source: ImportSource) throws {
  let scoped = sourceURL.startAccessingSecurityScopedResource()
  defer {
    if scoped {
      sourceURL.stopAccessingSecurityScopedResource()
    }
  }

  try backupArchive.importData(from: sourceURL, source: source)
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
        try backupArchive.export(to: url, date: date)
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
        try Task.checkCancellation()
        await MainActor.run {
          importing = false
          requestReload()
          displayToast(NSLocalizedString("Import succeeded", comment: ""), icon: "success")
        }
      } catch is CancellationError {
        await MainActor.run {
          importing = false
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
