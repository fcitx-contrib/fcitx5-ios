import UIKit

class CandidateView: UICollectionViewCell {
  static let identifier = "CandidateView"

  let wordLabel: UILabel = {
    let label = UILabel()
    label.textAlignment = .center
    label.font = UIFont.systemFont(ofSize: 18)
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
  }()

  override init(frame: CGRect) {
    super.init(frame: frame)
    contentView.addSubview(wordLabel)
    setupConstraints()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setupConstraints() {
    NSLayoutConstraint.activate([
      wordLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
      wordLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
    ])
  }

  func configure(with word: String) {
    wordLabel.text = word
  }
}
