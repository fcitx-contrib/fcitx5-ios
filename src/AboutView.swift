import SwiftUI
import SwiftUtil

let sourceRepo = "https://github.com/fcitx-contrib/fcitx5-ios"

func urlButton(_ text: String, _ link: String) -> some View {
  Link(text, destination: URL(string: link)!)
}

private func getDate() -> String {
  let dateFormatter = DateFormatter()
  dateFormatter.dateStyle = .medium
  dateFormatter.timeStyle = .medium
  dateFormatter.locale = Locale.current
  return dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(unixTime)))
}

struct AboutView: View {
  var body: some View {
    GeometryReader { geometry in
      let isPortrait = geometry.size.height > geometry.size.width
      let texts = VStack(spacing: 8) {
        Text(String("Fcitx5 iOS"))  // no i18n by design
          .font(.system(size: 32))

        if appGroup == documents {
          Text("Unsigned")
        } else {
          Text("Signed")
        }

        urlButton(String(commit.prefix(7)), sourceRepo + "/commit/" + commit)

        Text(getDate())

        HStack {
          Text("Developed by")
          urlButton("Qijia Liu", "https://github.com/eagleoflqj")
        }

        HStack {
          Text("Licensed under")
          urlButton("GPLv3", sourceRepo + "/blob/master/LICENSE")
        }

        urlButton(
          NSLocalizedString("3rd-party source code", comment: ""),
          sourceRepo + "/blob/master/CREDITS.md")
      }.font(.system(size: 24))

      if let uiImage = UIImage(contentsOfFile: Bundle.main.bundlePath + "/AppIcon76x76@2x~ipad.png")
      {
        let image = Image(uiImage: uiImage)
          .resizable()
          .frame(width: 152, height: 152)
        if isPortrait {
          VStack(alignment: .center) {
            image
            texts
          }.frame(width: geometry.size.width, height: geometry.size.height)
        } else {
          HStack {
            image
            texts
          }.frame(width: geometry.size.width, height: geometry.size.height)
        }
      }
    }
  }
}
