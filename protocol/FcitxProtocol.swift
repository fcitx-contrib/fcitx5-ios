import UIKit

public protocol FcitxProtocol {
  func getView() -> UIStackView
  func keyPressed(_ key: String)
  func commitString(_ string: String)
}
