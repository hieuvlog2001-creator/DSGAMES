import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = MainViewController()
        self.window = window
        window.makeKeyAndVisible()
        return true
    }
}

final class MainViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let content = UIStackView()
    private let searchField = UITextField()
    private var library = Set<String>()
    private var gameButtons: [String: UIButton] = [:]

    private let games: [(name: String, subtitle: String, image: String)] = [
        ("Arena of Valor", "Liên Quân Mobile", "aov"),
        ("CrossFire Mobile", "CrossFire Legends", "cfm"),
        ("Free Fire MAX", "Garena", "ffmax"),
        ("Wild Rift", "League of Legends", "h_ahri")
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        buildInterface()
    }

    private func buildInterface() {
        let header = UIStackView()
        header.axis = .horizontal
        header.alignment = .center
        header.translatesAutoresizingMaskIntoConstraints = false

        let titleStack = UIStackView()
        titleStack.axis = .vertical
        titleStack.spacing = 2
        let title = label("DSGames", size: 25, weight: .bold)
        let sub = label("GAME CENTER", size: 9, weight: .bold)
        sub.textColor = .secondaryLabel
        titleStack.addArrangedSubview(title)
        titleStack.addArrangedSubview(sub)
        header.addArrangedSubview(titleStack)
        header.addArrangedSubview(UIView())

        let bell = roundedButton(symbol: "bell.fill")
        let avatar = roundedButton(title: "T")
        header.addArrangedSubview(bell)
        header.addArrangedSubview(avatar)
        view.addSubview(header)

        searchField.placeholder = "Search games"
        searchField.textColor = .white
        searchField.tintColor = .white
        searchField.backgroundColor = UIColor.white.withAlphaComponent(0.07)
        searchField.layer.cornerRadius = 14
        searchField.leftView = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        searchField.leftView?.tintColor = .secondaryLabel
        searchField.leftViewMode = .always
        searchField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchField)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)

        content.axis = .vertical
        content.spacing = 16
        content.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(content)

        addSectionTitle("Featured")
        addFeaturedCard()
        addSectionTitle("Games")
        games.forEach { addGameRow($0) }
        addSectionTitle("Champion library")
        addChampionGrid()

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            bell.widthAnchor.constraint(equalToConstant: 38), bell.heightAnchor.constraint(equalToConstant: 38),
            avatar.widthAnchor.constraint(equalToConstant: 38), avatar.heightAnchor.constraint(equalToConstant: 38),
            searchField.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 14),
            searchField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            searchField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            searchField.heightAnchor.constraint(equalToConstant: 44),
            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            content.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 4),
            content.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 18),
            content.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -18),
            content.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            content.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -36)
        ])
    }

    private func addSectionTitle(_ text: String) {
        let l = label(text, size: 21, weight: .bold)
        content.addArrangedSubview(l)
    }

    private func addFeaturedCard() {
        let card = UIView()
        card.backgroundColor = UIColor.white.withAlphaComponent(0.07)
        card.layer.cornerRadius = 24
        card.clipsToBounds = true
        card.heightAnchor.constraint(equalToConstant: 210).isActive = true

        let image = UIImageView(image: UIImage(named: "aov"))
        image.contentMode = .scaleAspectFill
        image.alpha = 0.55
        image.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(image)

        let overlay = UIView()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        overlay.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(overlay)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 7
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        let rec = label("RECOMMENDED", size: 10, weight: .bold)
        rec.textColor = .systemCyan
        stack.addArrangedSubview(rec)
        stack.addArrangedSubview(label("Arena of Valor", size: 25, weight: .bold))
        let s = label("Liên Quân Mobile", size: 13, weight: .regular)
        s.textColor = .secondaryLabel
        stack.addArrangedSubview(s)

        let button = UIButton(type: .system)
        button.setTitle("Add to library", for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.backgroundColor = .white
        button.layer.cornerRadius = 18
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        button.addTarget(self, action: #selector(addFeatured), for: .touchUpInside)
        stack.addArrangedSubview(button)

        content.addArrangedSubview(card)
        NSLayoutConstraint.activate([
            image.topAnchor.constraint(equalTo: card.topAnchor), image.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            image.leadingAnchor.constraint(equalTo: card.leadingAnchor), image.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            overlay.topAnchor.constraint(equalTo: card.topAnchor), overlay.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            overlay.leadingAnchor.constraint(equalTo: card.leadingAnchor), overlay.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20)
        ])
    }

    @objc private func addFeatured() {
        toggleGame("Arena of Valor")
    }

    private func addGameRow(_ game: (name: String, subtitle: String, image: String)) {
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.layoutMargins = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        row.isLayoutMarginsRelativeArrangement = true
        row.backgroundColor = UIColor.white.withAlphaComponent(0.045)
        row.layer.cornerRadius = 18

        let image = UIImageView(image: UIImage(named: game.image))
        image.contentMode = .scaleAspectFill
        image.clipsToBounds = true
        image.layer.cornerRadius = 14
        image.widthAnchor.constraint(equalToConstant: 58).isActive = true
        image.heightAnchor.constraint(equalToConstant: 58).isActive = true
        row.addArrangedSubview(image)

        let texts = UIStackView()
        texts.axis = .vertical
        texts.spacing = 4
        texts.addArrangedSubview(label(game.name, size: 15, weight: .semibold))
        let sub = label(game.subtitle, size: 12, weight: .regular)
        sub.textColor = .secondaryLabel
        texts.addArrangedSubview(sub)
        row.addArrangedSubview(texts)
        row.addArrangedSubview(UIView())

        let button = UIButton(type: .system)
        button.setTitle("+", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 20)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        button.layer.cornerRadius = 17
        button.widthAnchor.constraint(equalToConstant: 34).isActive = true
        button.heightAnchor.constraint(equalToConstant: 34).isActive = true
        button.accessibilityIdentifier = game.name
        button.addTarget(self, action: #selector(gameButtonTapped(_:)), for: .touchUpInside)
        gameButtons[game.name] = button
        row.addArrangedSubview(button)
        content.addArrangedSubview(row)
    }

    @objc private func gameButtonTapped(_ sender: UIButton) {
        guard let name = sender.accessibilityIdentifier else { return }
        toggleGame(name)
    }

    private func toggleGame(_ name: String) {
        if library.contains(name) { library.remove(name) } else { library.insert(name) }
        let button = gameButtons[name]
        button?.setTitle(library.contains(name) ? "✓" : "+", for: .normal)
    }

    private func addChampionGrid() {
        let names = ["h_ahri","h_akali","h_ashe","h_kassadin","h_jinx","h_ekko","h_yasuo","h_lux","h_garen","h_zed","h_jax","h_sylas"]
        let grid = UIStackView()
        grid.axis = .vertical
        grid.spacing = 10
        var index = 0
        while index < names.count {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 10
            for _ in 0..<4 {
                if index < names.count {
                    let iv = UIImageView(image: UIImage(named: names[index]))
                    iv.contentMode = .scaleAspectFill
                    iv.clipsToBounds = true
                    iv.layer.cornerRadius = 14
                    iv.heightAnchor.constraint(equalToConstant: 70).isActive = true
                    iv.widthAnchor.constraint(equalToConstant: 70).isActive = true
                    row.addArrangedSubview(iv)
                    index += 1
                } else { row.addArrangedSubview(UIView()) }
            }
            grid.addArrangedSubview(row)
        }
        content.addArrangedSubview(grid)
    }

    private func label(_ text: String, size: CGFloat, weight: UIFont.Weight) -> UILabel {
        let l = UILabel()
        l.text = text
        l.textColor = .white
        l.font = .systemFont(ofSize: size, weight: weight)
        l.numberOfLines = 0
        return l
    }

    private func roundedButton(symbol: String? = nil, title: String? = nil) -> UIButton {
        let b = UIButton(type: .system)
        if let symbol { b.setImage(UIImage(systemName: symbol), for: .normal) }
        if let title { b.setTitle(title, for: .normal); b.titleLabel?.font = .boldSystemFont(ofSize: 16) }
        b.tintColor = .white
        b.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        b.layer.cornerRadius = 19
        return b
    }
}
