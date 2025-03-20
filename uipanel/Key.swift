import SwiftUI

struct KeyView: View {
  let label: String

  var body: some View {
    Button {
      client.keyPressed(label, "")
    } label: {
      Text(label)
        .frame(width: label == " " ? 100 : 35, height: 40)
        .background(Color.white)
        .cornerRadius(5)
        .overlay(
          RoundedRectangle(cornerRadius: 5)
            .stroke(Color.gray, lineWidth: 1)
        )
    }
  }
}
