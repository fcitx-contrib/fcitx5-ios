import SwiftUI

struct UnknownView: OptionViewProtocol {
  let label: String
  let data: [String: Any]
  let value: Any
  let onUpdate: (Any) -> Void

  var body: some View {
    Text(label)
  }
}
