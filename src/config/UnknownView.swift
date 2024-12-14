import SwiftUI

struct UnknownView: OptionViewProtocol {
  let label: String
  let data: [String: Any]
  @Binding var value: Any

  var body: some View {
    Text(label)
  }
}
