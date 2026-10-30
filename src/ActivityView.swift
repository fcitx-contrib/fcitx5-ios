import SwiftUI
import UIKit

struct ActivityView: UIViewControllerRepresentable {
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
