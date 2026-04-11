import SwiftUI
import SwiftUtil

struct SyncPendingView: View {
  var body: some View {
    VStack(alignment: .leading) {
      Spacer()
      Text("Full access is required to synchronize data from local server.")
      Text(
        "Please click the Grant button above, then open \"⌨️ Keyboards\" and enable \"Allow Full Access\"."
      )
      Spacer()
    }.padding()
  }
}

struct SyncRunningView: View {
  @ObservedObject var viewModel = vm

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        VStack {
          Spacer()
          Text("Synchronizing \(viewModel.keyboardDisplayName) keyboard")
          Text("\(viewModel.syncProgress)/\(viewModel.syncTotal)")
          Spacer()
            .frame(height: geometry.size.height / 2 + 8)
        }
        .frame(maxWidth: .infinity)
        ProgressView(
          value: Double(viewModel.syncProgress), total: max(1, Double(viewModel.syncTotal)))
        VStack {
          Spacer()
            .frame(height: geometry.size.height / 2 + 8)
          Text(viewModel.fileInSync)
          Spacer()
        }
      }
    }
    .padding()
  }
}

struct SyncDoneView: View {
  @ObservedObject var viewModel = vm

  var body: some View {
    VStack {
      Spacer()
      Button {
        removeFile(documents.appendingPathComponent("tmp/checksums.json"))
        removeFile(documents.appendingPathComponent("config"))
        removeFile(documents.appendingPathComponent("data"))
        client.syncConfig()
      } label: {
        Text("Clear data and sync again")
      }
      .buttonStyle(.bordered)
      .tint(.red)

      Spacer()

      Button {
        client.dismissKeyboard()
      } label: {
        Text("Done")
      }
      .buttonStyle(.bordered)
      .tint(.blue)
      Spacer()
    }.frame(maxWidth: .infinity)
      .padding()
  }
}
