import UIKit

class CandidateCollectionView: UIView {

  var words = [String]()

  private var collectionView: UICollectionView!

  override init(frame: CGRect) {
    super.init(frame: frame)
    setupCollectionView()
    setupConstraints()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setupCollectionView() {
    let layout = UICollectionViewFlowLayout()
    layout.scrollDirection = .horizontal

    collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
    collectionView.translatesAutoresizingMaskIntoConstraints = false
    collectionView.backgroundColor = UIColor.clear
    collectionView.delegate = self
    collectionView.dataSource = self
    collectionView.register(
      CandidateView.self, forCellWithReuseIdentifier: CandidateView.identifier)

    addSubview(collectionView)
  }

  private func setupConstraints() {
    NSLayoutConstraint.activate([
      collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
      collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
      collectionView.topAnchor.constraint(equalTo: topAnchor),
      collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
      collectionView.heightAnchor.constraint(equalToConstant: 35),
    ])
  }

  func updateCandidates(_ candidates: [String]) {
    words = candidates
    collectionView.reloadData()
  }
}

extension CandidateCollectionView: UICollectionViewDataSource {
  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int)
    -> Int
  {
    return words.count
  }

  func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath)
    -> UICollectionViewCell
  {
    guard
      let cell = collectionView.dequeueReusableCell(
        withReuseIdentifier: CandidateView.identifier, for: indexPath) as? CandidateView
    else {
      return UICollectionViewCell()
    }
    cell.configure(with: words[indexPath.item])
    return cell
  }
}

extension CandidateCollectionView: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    logger.error("Selected word: \(words[indexPath.item])")
  }
}

extension CandidateCollectionView: UICollectionViewDelegateFlowLayout {
  func collectionView(
    _ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
    sizeForItemAt indexPath: IndexPath
  ) -> CGSize {
    let word = words[indexPath.item]
    let width = word.size(withAttributes: [.font: UIFont.systemFont(ofSize: 18)]).width + 20
    return CGSize(width: width, height: 35)
  }

  func collectionView(
    _ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
    minimumLineSpacingForSectionAt section: Int
  ) -> CGFloat {
    return 10
  }
}
