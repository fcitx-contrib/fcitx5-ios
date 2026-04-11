import AlertToast
import FcitxIpc
import SwiftUI
import SwiftUtil
import Swifter

private let localhostOnly = true

private let configPrefix =
  (documents.appendingPathComponent("config").path as NSString)
  .standardizingPath + "/"
private let dataPrefix =
  (documents.appendingPathComponent("data").path as NSString)
  .standardizingPath + "/"
private let localePath = (documents.appendingPathComponent("tmp/locale").path as NSString)
  .standardizingPath

final class ServerManager: Sendable {
  static let shared = ServerManager()
  nonisolated(unsafe) let server = HttpServer()
  static nonisolated(unsafe) var onDone: ((String) -> Void)?

  private init() {
    server.listenAddressIPv4 = localhostOnly ? localhostV4 : "0.0.0.0"
    server["/health"] = { _ in .ok(.text("")) }
    server["/list"] = ServerManager.listHandler
    server["/download"] = ServerManager.downloadHandler
    server["/done"] = ServerManager.doneHandler
  }

  private static func listHandler(_ request: HttpRequest) -> HttpResponse {
    let keyboard = request.queryParams.first { $0.0 == "keyboard" }?.1 ?? ""
    var list = [[String]]()
    // Must standardize, as documents.path starts with /var but urlPath starts with /private/var.
    let docsPath = (documents.path as NSString).standardizingPath

    func enumerate(_ relativePath: String, exclude: [String]? = nil) {
      list.append(["\(relativePath)/", ""])
      let dir = documents.appendingPathComponent(relativePath)
      if let enumerator = FileManager.default.enumerator(
        at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
      {
        for case let url as URL in enumerator {
          var isDir: ObjCBool = false
          FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
          let urlPath = (url.path as NSString).standardizingPath
          var fullPath = urlPath.replacingOccurrences(of: docsPath, with: "")
          if fullPath.hasPrefix("/") {
            fullPath.removeFirst()
          }
          if isDir.boolValue {
            fullPath += "/"
          }
          if let exclude = exclude,
            exclude.contains(where: {
              if $0.hasSuffix("/") {
                return fullPath.hasPrefix($0)
              } else {
                return fullPath == $0
              }
            })
          {
            continue
          }
          let hash = isDir.boolValue ? "" : md5Hash(url)
          list.append([fullPath, hash])
        }
      }
    }

    enumerate("config")
    if keyboard == "Chinese" {
      for subdir in ["data", "table", "inputmethod", "punctuation"] {
        enumerate("data/\(subdir)")
      }
      enumerate("data/pinyin", exclude: ["data/pinyin/user.dict", "data/pinyin/user.history"])
    } else if keyboard == "Rime" {
      enumerate("data/rime")
    }
    let localePath = documents.appendingPathComponent("tmp/locale")
    if FileManager.default.fileExists(atPath: localePath.path) {
      list.append(["tmp/", ""])
      list.append(["tmp/locale", md5Hash(localePath)])
    }

    FCITX_INFO("GET /list keyboard=\(keyboard) 200")
    return .ok(.json(list))
  }

  private static func downloadHandler(request: HttpRequest) -> HttpResponse {
    let path = request.queryParams.first { $0.0 == "path" }?.1.removingPercentEncoding ?? ""
    let startStr = request.queryParams.first { $0.0 == "start" }?.1 ?? "0"
    let start = Int(startStr) ?? 0
    let normalizedPath = ((documents.path as NSString).appendingPathComponent(path) as NSString)
      .standardizingPath
    guard
      normalizedPath == configPrefix || normalizedPath.hasPrefix(configPrefix)
        || normalizedPath == dataPrefix || normalizedPath.hasPrefix(dataPrefix)
        || normalizedPath == localePath
    else {
      FCITX_WARN("GET /download path=\(path) start=\(start) 403")
      return .forbidden(nil)
    }
    guard let handle = try? FileHandle(forReadingFrom: URL(fileURLWithPath: normalizedPath)) else {
      FCITX_WARN("GET /download path=\(path) start=\(start) 404")
      return .notFound(nil)
    }
    defer { try? handle.close() }
    let fileSize = (try? handle.seekToEnd()) ?? 0
    if start < 0 || start > Int(fileSize) {
      FCITX_WARN("GET /download path=\(path) start=\(start) 400")
      return .badRequest(nil)
    }
    try? handle.seek(toOffset: UInt64(start))
    let end = min(start + syncConfigChunkSize, Int(fileSize))
    guard let chunk = try? handle.read(upToCount: end - start) else {
      FCITX_ERROR("GET /download path=\(path) start=\(start) read failed")
      return .internalServerError(nil)
    }
    let isDone = end >= Int(fileSize)
    let statusCode = isDone ? 200 : 206
    FCITX_INFO("GET /download path=\(path) start=\(start) count=\(chunk.count) \(statusCode)")
    return .raw(
      statusCode, isDone ? "OK" : "Partial Content", nil,
      { writer in
        try writer.write(chunk)
      })
  }

  private static func doneHandler(_ request: HttpRequest) -> HttpResponse {
    let keyboard = request.queryParams.first { $0.0 == "keyboard" }?.1 ?? ""
    Task { @MainActor in
      ServerManager.onDone?(keyboard)
    }
    FCITX_INFO("GET /done keyboard=\(keyboard) 200")
    return .ok(.text(""))
  }

  func start() {
    do {
      try server.start(syncConfigPort, forceIPv4: true)
    } catch {
      FCITX_ERROR("failed to start server: \(error)")
    }
  }

  func stop() {
    server.stop()
  }
}

struct SyncConfigView: View {
  @State private var isServerRunning = false
  @State private var hasFullAccess: Bool?
  @State private var text = syncConfigMagicText
  @State private var showToast = false
  @State private var toastMessage = ""
  @State private var toastIcon = "success"
  @State private var completedKeyboards: Set<String> = []
  @FocusState private var isTextFieldFocused: Bool
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(alignment: .leading) {
      HStack {
        Circle()
          .fill(isServerRunning ? Color.green : Color.red)
          .frame(width: 12, height: 12)
        if isServerRunning {
          Text("Local server is running")
        } else {
          Text("Local server is not running")
        }
      }
      HStack {
        Circle()
          .fill(hasFullAccess == true ? Color.green : Color.red)
          .frame(width: 12, height: 12)
        if hasFullAccess == nil {
          Text("Please switch to a Fcitx5 keyboard")
        } else if hasFullAccess == true {
          Text("Keyboard has full access")
        } else {
          Text("Keyboard requires full access")
          Button {
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
          } label: {
            Text("Grant")
          }
        }
      }
      ForEach(listKeyboardInfo(), id: \.id) { info in
        HStack {
          Circle()
            .fill(completedKeyboards.contains(info.id) ? Color.green : Color.yellow)
            .frame(width: 12, height: 12)
          Text(
            String(
              format: completedKeyboards.contains(info.id)
                ? NSLocalizedString("%@ keyboard synced", comment: "")
                : NSLocalizedString("%@ keyboard not synced", comment: ""),
              info.displayName))
        }
      }
      TextField(syncConfigMagicText, text: $text)
        .focused($isTextFieldFocused)
        .onChange(of: text) { newValue in
          if newValue.hasSuffix(syncConfigFullAccess) {
            hasFullAccess = true
          } else if newValue.hasSuffix(syncConfigNoFullAccess) {
            hasFullAccess = false
          }
          text = syncConfigMagicText
        }
        .onChange(of: isTextFieldFocused) { focused in
          if !focused {
            dismiss()
          }
        }
        .opacity(0)
      Spacer()
    }
    .padding(.horizontal)
    .navigationTitle(NSLocalizedString("Sync config", comment: ""))
    .navigationBarTitleDisplayMode(.inline)
    .onReceive(
      NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
    ) { _ in
      // Back to main screen when moving app to background, so that switching back doesn't trigger another sync.
      dismiss()
    }
    .task {
      ServerManager.shared.start()
      // Heartbeat
      while !Task.isCancelled {
        let url = URL(string: "http://\(localhostV4):\(syncConfigPort)/health")!
        if let (_, response) = try? await URLSession.shared.data(from: url),
          let httpResponse = response as? HTTPURLResponse
        {
          FCITX_DEBUG("health check: \(httpResponse.statusCode)")
          isServerRunning = httpResponse.statusCode == 200
        } else {
          isServerRunning = false
          ServerManager.shared.stop()
          ServerManager.shared.start()
        }
        try? await Task.sleep(nanoseconds: 1_000_000_000)
      }
    }
    .onAppear {
      // Force focus on hidden TextField so that keyboard appears.
      isTextFieldFocused = true
      ServerManager.onDone = { keyboard in
        completedKeyboards.insert(keyboard)
        toastMessage = NSLocalizedString("Sync config completed", comment: "")
        toastIcon = "success"
        showToast = true
      }
    }
    .onDisappear {
      ServerManager.shared.stop()
      ServerManager.onDone = nil
    }
    .toast(isPresenting: $showToast) {
      AlertToast(
        displayMode: .alert,
        type: toastIcon == "error" ? .error(Color.red) : .complete(Color.green),
        subTitle: toastMessage,
        style: AlertToast.AlertStyle.style(subTitleFont: Font.system(size: 20)))
    }
  }
}
