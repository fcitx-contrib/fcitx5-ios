import SwiftUI

struct ConfigView: View {
  let inputMethod: InputMethod

  var body: some View {
    VStack {
    }
    .navigationTitle(inputMethod.displayName)
    .navigationBarTitleDisplayMode(.inline)
  }
}
