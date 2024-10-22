import SwiftUI

struct ContentView: View {
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    VStack {
      Image(systemName: "globe")
        .imageScale(.large)
        .foregroundStyle(.tint)
      Text("Hello, world!")
    }
    .padding()
    .onAppear {
      // The stupid iOS doesn't show empty directory in Files.app.
      try? "".write(
        to: documents.appendingPathComponent("placeholder"), atomically: true, encoding: .utf8)
    }
    .onChange(of: scenePhase) { newPhase in
      if newPhase == .active {
        sync(documents.appendingPathComponent("rime"), appGroupData.appendingPathComponent("rime"))
      }
    }
  }
}
