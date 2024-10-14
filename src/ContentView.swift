import SwiftUI

struct ContentView: View {
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
        to: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
          .appendingPathComponent("placeholder"), atomically: true, encoding: .utf8)
    }
  }
}
