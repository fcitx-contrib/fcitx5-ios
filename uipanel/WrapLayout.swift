import UIKit

func calculateLayout(_ candidates: [String], _ width: CGFloat) -> [Int] {
  var rowItemCount = [Int]()
  var currentRowCount = 0
  var currentRowWidth: CGFloat = 0
  let minWidth = width / 6

  for candidate in candidates {
    let itemWidth = max(
      (candidate as NSString).size(withAttributes: [
        .font: UIFont.systemFont(ofSize: candidateFontSize)
      ]).width + 2 * candidateHorizontalPadding, minWidth)
    if currentRowWidth + itemWidth <= width {
      currentRowWidth += itemWidth
      currentRowCount += 1
    } else {
      if currentRowCount > 0 {
        rowItemCount.append(currentRowCount)
      }
      currentRowCount = 1
      currentRowWidth = itemWidth
    }
  }
  if currentRowCount > 0 {
    rowItemCount.append(currentRowCount)
  }
  return rowItemCount
}
