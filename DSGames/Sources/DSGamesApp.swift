import UIKit

// MARK: - Remote catalog

struct RemoteGame: Codable, Hashable {
    let id: String
    let name: String
    let developer: String
    let icon: String?
    let banner: String?
    let description: String?
    let version: String?
    let category: String?
    let launchURL: String?
    let featured: Bool
    let enabled: Bool
    let sortOrder: Int
    let updatedAt: String?

    var displayName: String {
        switch id.lowercased() {
        case "aov": return "Liên Quân Mobile DS"
        case "cfm": return "CrossFire Mobile DS"
        case "ffmax": return "Free Fire MAX DS"
        case "ffth": return "Free Fire TH DS"
        case "wildrift": return "Wild Rift DS"
        case "standoff2": return "Standoff 2 DS"
        case "8ballpool": return "8 Ball Pool DS"
        case "codm": return "Call of Duty Mobile (VNG / Global) DS"
        default: return name
        }
    }

    var statusText: String { "Mở cùng menu overlay" }
}

struct GamesResponse: Codable {
    let version: Int
    let updatedAt: String?
    let games: [RemoteGame]
}

private enum APIConfig {
    static let gamesURL = "https://dsgames-catalog.hieuvlog2001.workers.dev/api/games"
    static let timeout: TimeInterval = 12
}

final class GamesAPI {
    static let shared = GamesAPI()
    private init() {}

    func fetchGames(completion: @escaping (Result<GamesResponse, Error>) -> Void) {
        guard let url = URL(string: APIConfig.gamesURL) else {
            completion(.failure(NSError(domain: "DSGames", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid catalog URL"])))
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = APIConfig.timeout
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("DSGames-iOS/1.9.1", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error { completion(.failure(error)); return }
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                completion(.failure(NSError(domain: "DSGames", code: code, userInfo: [NSLocalizedDescriptionKey: "HTTP \(code)"])))
                return
            }
            guard let data else {
                completion(.failure(NSError(domain: "DSGames", code: 2, userInfo: [NSLocalizedDescriptionKey: "Empty response"])))
                return
            }
            do { completion(.success(try JSONDecoder().decode(GamesResponse.self, from: data))) }
            catch { completion(.failure(error)) }
        }.resume()
    }
}

final class RemoteImageLoader {
    static let shared = RemoteImageLoader()
    private let cache = NSCache<NSURL, UIImage>()

    func load(_ value: String?, fallback: String? = nil, completion: @escaping (UIImage?) -> Void) {
        if let value, !value.isEmpty, let url = URL(string: value), let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
            if let cached = cache.object(forKey: url as NSURL) { completion(cached); return }
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                let image = data.flatMap(UIImage.init(data:))
                if let image { self?.cache.setObject(image, forKey: url as NSURL) }
                DispatchQueue.main.async { completion(image ?? fallback.flatMap(UIImage.init(named:))) }
            }.resume()
            return
        }
        completion(fallback.flatMap(UIImage.init(named:)) ?? value.flatMap(UIImage.init(named:)))
    }
}

final class GameStore {
    static let shared = GameStore()
    private(set) var games: [RemoteGame] = []
    private let cacheKey = "dsgames.remote.catalog.v3"
    var onChange: (() -> Void)?
    var isSyncing = false

    private init() { loadCache() }

    func sync(completion: ((Bool) -> Void)? = nil) {
        guard !isSyncing else { completion?(false); return }
        isSyncing = true
        GamesAPI.shared.fetchGames { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isSyncing = false
                switch result {
                case .success(let response):
                    self.games = response.games.filter { $0.enabled }.sorted {
                        if $0.sortOrder == $1.sortOrder { return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
                        return $0.sortOrder < $1.sortOrder
                    }
                    if let data = try? JSONEncoder().encode(response) { UserDefaults.standard.set(data, forKey: self.cacheKey) }
                    self.onChange?()
                    completion?(true)
                case .failure:
                    completion?(false)
                }
            }
        }
    }

    private func loadCache() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let response = try? JSONDecoder().decode(GamesResponse.self, from: data) else {
            games = Self.fallbackGames
            return
        }
        games = response.games.filter { $0.enabled }.sorted { $0.sortOrder < $1.sortOrder }
    }

    static let fallbackGames: [RemoteGame] = [
        RemoteGame(id: "aov", name: "Arena of Valor", developer: "Liên Quân Mobile", icon: "aov", banner: "aov", description: "Liên Quân Mobile", version: "1.8", category: "MOBA", launchURL: nil, featured: true, enabled: true, sortOrder: 10, updatedAt: nil),
        RemoteGame(id: "standoff2", name: "Standoff 2", developer: "", icon: "standoff2", banner: nil, description: nil, version: nil, category: "FPS", launchURL: nil, featured: false, enabled: true, sortOrder: 20, updatedAt: nil),
        RemoteGame(id: "wildrift", name: "Wild Rift", developer: "", icon: "wildrift", banner: nil, description: nil, version: nil, category: "MOBA", launchURL: nil, featured: false, enabled: true, sortOrder: 30, updatedAt: nil),
        RemoteGame(id: "ffth", name: "Free Fire", developer: "", icon: "ffth", banner: nil, description: nil, version: nil, category: "Battle Royale", launchURL: nil, featured: false, enabled: true, sortOrder: 40, updatedAt: nil),
        RemoteGame(id: "ffmax", name: "Free Fire MAX", developer: "", icon: "ffmax", banner: nil, description: nil, version: nil, category: "Battle Royale", launchURL: nil, featured: false, enabled: true, sortOrder: 50, updatedAt: nil),
        RemoteGame(id: "cfm", name: "CrossFire Mobile", developer: "", icon: "cfm", banner: nil, description: nil, version: nil, category: "FPS", launchURL: nil, featured: false, enabled: true, sortOrder: 60, updatedAt: nil),
        RemoteGame(id: "8ballpool", name: "8 Ball Pool", developer: "", icon: "8ballpool", banner: nil, description: nil, version: nil, category: "Game", launchURL: nil, featured: false, enabled: true, sortOrder: 70, updatedAt: nil),
        RemoteGame(id: "codm", name: "Call of Duty Mobile", developer: "", icon: "codm", banner: nil, description: nil, version: nil, category: "FPS", launchURL: nil, featured: false, enabled: true, sortOrder: 80, updatedAt: nil)
    ]
}

// MARK: - App

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.backgroundColor = .systemBackground
        window.overrideUserInterfaceStyle = .unspecified
        window.rootViewController = MainViewController()
        self.window = window
        window.makeKeyAndVisible()
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) { GameStore.shared.sync() }
}

// MARK: - Main screen

final class MainViewController: UIViewController {
    private let store = GameStore.shared
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let cardsStack = UIStackView()
    private let bottomBar = UIView()
    private let gamesTab = UIButton(type: .system)
    private let appsTab = UIButton(type: .system)

    private let statusCard = UIView()
    private let statusIcon = UIImageView(image: UIImage(systemName: "checkmark.shield.fill"))
    private let statusTitle = UILabel()
    private let statusSubtitle = UILabel()
    private let statusDot = UIView()

    override var preferredStatusBarStyle: UIStatusBarStyle {
        traitCollection.userInterfaceStyle == .dark ? .lightContent : .darkContent
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor { tc in tc.userInterfaceStyle == .dark ? UIColor(red: 0.018, green: 0.020, blue: 0.025, alpha: 1) : UIColor(red: 0.965, green: 0.973, blue: 0.992, alpha: 1) }
        buildUI()
        store.onChange = { [weak self] in self?.renderGames() }
        renderGames()
        store.sync()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        view.backgroundColor = UIColor { tc in tc.userInterfaceStyle == .dark ? UIColor(red: 0.018, green: 0.020, blue: 0.025, alpha: 1) : UIColor(red: 0.965, green: 0.973, blue: 0.992, alpha: 1) }
        updateTheme()
    }

    private func buildUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.contentInsetAdjustmentBehavior = .never
        let refresh = UIRefreshControl()
        refresh.addTarget(self, action: #selector(refreshCatalog), for: .valueChanged)
        scrollView.refreshControl = refresh
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 0
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        let header = makeHeader()
        contentStack.addArrangedSubview(header)
        header.heightAnchor.constraint(equalToConstant: 82).isActive = true

        makeStatusCard()
        contentStack.addArrangedSubview(statusCard)
        statusCard.heightAnchor.constraint(equalToConstant: 70).isActive = true
        statusCard.topAnchor.constraint(equalTo: contentStack.topAnchor, constant: 0).isActive = false
        contentStack.setCustomSpacing(22, after: statusCard)

        let title = UILabel()
        title.text = "Chọn game"
        title.font = .systemFont(ofSize: 28, weight: .bold)
        title.adjustsFontSizeToFitWidth = true
        title.minimumScaleFactor = 0.8
        contentStack.addArrangedSubview(title)
        title.heightAnchor.constraint(equalToConstant: 34).isActive = true

        let desc = UILabel()
        desc.text = "ESP và menu nổi sẽ tự khởi động trước khi mở game."
        desc.font = .systemFont(ofSize: 16, weight: .regular)
        desc.textColor = .secondaryLabel
        desc.numberOfLines = 1
        desc.adjustsFontSizeToFitWidth = true
        desc.minimumScaleFactor = 0.72
        contentStack.addArrangedSubview(desc)
        desc.heightAnchor.constraint(equalToConstant: 28).isActive = true
        contentStack.setCustomSpacing(12, after: desc)

        cardsStack.axis = .vertical
        cardsStack.spacing = 9
        cardsStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(cardsStack)

        let bottomSpace = UIView()
        bottomSpace.heightAnchor.constraint(equalToConstant: 12).isActive = true
        contentStack.addArrangedSubview(bottomSpace)

        buildBottomBar()

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 6),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            scrollView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
        updateTheme()
    }

    private func makeHeader() -> UIView {
        let box = UIView()
        let title = UILabel()
        title.text = "DSGames"
        title.font = .systemFont(ofSize: 25, weight: .bold)

        let meta = UILabel()
        meta.text = "v1.8  ·  \(deviceName())  ·  iOS \(ProcessInfo.processInfo.operatingSystemVersionString.replacingOccurrences(of: "Version ", with: ""))"
        meta.font = .systemFont(ofSize: 14, weight: .regular)
        meta.textColor = .secondaryLabel
        meta.adjustsFontSizeToFitWidth = true
        meta.minimumScaleFactor = 0.65

        let left = UIStackView(arrangedSubviews: [title, meta])
        left.axis = .vertical
        left.spacing = 2
        left.alignment = .leading
        left.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(left)

        let language = UIButton(type: .system)
        var cfg = UIButton.Configuration.plain()
        cfg.title = "🇻🇳  VI ⌄"
        cfg.baseForegroundColor = .systemBlue
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)
        language.configuration = cfg
        language.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        language.layer.cornerRadius = 24
        language.layer.borderWidth = 1
        language.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(language)

        let more = UIButton(type: .system)
        more.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        more.tintColor = .systemBlue
        more.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.10)
        more.layer.cornerRadius = 18
        more.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(more)

        NSLayoutConstraint.activate([
            left.leadingAnchor.constraint(equalTo: box.leadingAnchor),
            left.centerYAnchor.constraint(equalTo: box.centerYAnchor),
            left.trailingAnchor.constraint(lessThanOrEqualTo: language.leadingAnchor, constant: -8),
            language.trailingAnchor.constraint(equalTo: more.leadingAnchor, constant: -9),
            language.centerYAnchor.constraint(equalTo: box.centerYAnchor),
            language.heightAnchor.constraint(equalToConstant: 48),
            more.trailingAnchor.constraint(equalTo: box.trailingAnchor),
            more.centerYAnchor.constraint(equalTo: box.centerYAnchor),
            more.widthAnchor.constraint(equalToConstant: 36),
            more.heightAnchor.constraint(equalToConstant: 36)
        ])
        return box
    }

    private func makeStatusCard() {
        statusCard.layer.cornerRadius = 22
        statusCard.layer.borderWidth = 1
        statusCard.translatesAutoresizingMaskIntoConstraints = false

        let circle = UIView()
        circle.layer.cornerRadius = 25
        circle.translatesAutoresizingMaskIntoConstraints = false
        statusCard.addSubview(circle)

        statusIcon.tintColor = .systemGreen
        statusIcon.translatesAutoresizingMaskIntoConstraints = false
        circle.addSubview(statusIcon)

        statusTitle.text = "Sẵn sàng"
        statusTitle.font = .systemFont(ofSize: 17, weight: .semibold)
        statusTitle.translatesAutoresizingMaskIntoConstraints = false
        statusCard.addSubview(statusTitle)

        statusSubtitle.text = "HSD: Còn 1 ngày 5 giờ"
        statusSubtitle.font = .systemFont(ofSize: 15, weight: .regular)
        statusSubtitle.textColor = .secondaryLabel
        statusSubtitle.translatesAutoresizingMaskIntoConstraints = false
        statusCard.addSubview(statusSubtitle)

        statusDot.layer.cornerRadius = 7
        statusDot.backgroundColor = .systemGreen
        statusDot.translatesAutoresizingMaskIntoConstraints = false
        statusCard.addSubview(statusDot)

        NSLayoutConstraint.activate([
            circle.leadingAnchor.constraint(equalTo: statusCard.leadingAnchor, constant: 13),
            circle.centerYAnchor.constraint(equalTo: statusCard.centerYAnchor),
            circle.widthAnchor.constraint(equalToConstant: 50), circle.heightAnchor.constraint(equalToConstant: 50),
            statusIcon.centerXAnchor.constraint(equalTo: circle.centerXAnchor), statusIcon.centerYAnchor.constraint(equalTo: circle.centerYAnchor),
            statusIcon.widthAnchor.constraint(equalToConstant: 26), statusIcon.heightAnchor.constraint(equalToConstant: 26),
            statusTitle.leadingAnchor.constraint(equalTo: circle.trailingAnchor, constant: 13),
            statusTitle.topAnchor.constraint(equalTo: statusCard.topAnchor, constant: 17),
            statusSubtitle.leadingAnchor.constraint(equalTo: statusTitle.leadingAnchor),
            statusSubtitle.topAnchor.constraint(equalTo: statusTitle.bottomAnchor, constant: 3),
            statusDot.trailingAnchor.constraint(equalTo: statusCard.trailingAnchor, constant: -17),
            statusDot.centerYAnchor.constraint(equalTo: statusCard.centerYAnchor),
            statusDot.widthAnchor.constraint(equalToConstant: 14), statusDot.heightAnchor.constraint(equalToConstant: 14)
        ])
    }

    private func buildBottomBar() {
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomBar)
        let tabs = UIStackView(arrangedSubviews: [gamesTab, appsTab])
        tabs.axis = .horizontal; tabs.distribution = .fillEqually; tabs.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(tabs)
        configureTab(gamesTab, title: "Games", symbol: "scope", selected: true)
        configureTab(appsTab, title: "Ứng dụng", symbol: "square.grid.2x2.fill", selected: false)
        gamesTab.addTarget(self, action: #selector(gamesSelected), for: .touchUpInside)
        appsTab.addTarget(self, action: #selector(appsSelected), for: .touchUpInside)
        NSLayoutConstraint.activate([
            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor), bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor), bottomBar.heightAnchor.constraint(equalToConstant: 74),
            tabs.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor), tabs.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor),
            tabs.topAnchor.constraint(equalTo: bottomBar.topAnchor), tabs.bottomAnchor.constraint(equalTo: bottomBar.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    private func configureTab(_ button: UIButton, title: String, symbol: String, selected: Bool) {
        var config = UIButton.Configuration.plain()
        config.title = title; config.image = UIImage(systemName: symbol); config.imagePlacement = .top; config.imagePadding = 3
        config.baseForegroundColor = selected ? .systemBlue : .secondaryLabel
        button.configuration = config
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .regular)
    }

    private func renderGames() {
        cardsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, game) in store.games.enumerated() {
            let card = GameCardView(game: game, accent: accentColor(for: index))
            card.onPlay = { [weak self] game in self?.play(game) }
            card.onInfo = { [weak self] game in self?.showInfo(game) }
            cardsStack.addArrangedSubview(card)
        }
        scrollView.refreshControl?.endRefreshing()
        updateTheme()
    }

    private func play(_ game: RemoteGame) {
        guard let raw = game.launchURL, !raw.isEmpty, let url = URL(string: raw) else { showInfo(game); return }
        UIApplication.shared.open(url)
    }

    private func showInfo(_ game: RemoteGame) {
        let parts = [game.developer, game.category, game.version.map { "v\($0)" }, game.description].compactMap { $0 }.filter { !$0.isEmpty }
        let alert = UIAlertController(title: game.displayName, message: parts.joined(separator: "\n"), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Đóng", style: .cancel))
        if let raw = game.launchURL, let url = URL(string: raw), !raw.isEmpty { alert.addAction(UIAlertAction(title: "Mở game", style: .default) { _ in UIApplication.shared.open(url) }) }
        present(alert, animated: true)
    }

    private func accentColor(for index: Int) -> UIColor {
        [.systemBlue, .systemOrange, .systemTeal, .systemRed, .systemYellow, .systemCyan, .systemGreen, .systemGreen][index % 8]
    }

    private func deviceName() -> String {
        #if targetEnvironment(simulator)
        return UIDevice.current.model
        #else
        return UIDevice.current.model
        #endif
    }

    private func updateTheme() {
        let dark = traitCollection.userInterfaceStyle == .dark
        statusCard.backgroundColor = dark ? UIColor(red: 0.115, green: 0.115, blue: 0.125, alpha: 1) : UIColor(red: 0.985, green: 0.988, blue: 0.995, alpha: 1)
        statusCard.layer.borderColor = UIColor.systemGreen.withAlphaComponent(dark ? 0.20 : 0.18).cgColor
        statusTitle.textColor = .label
        statusIcon.superview?.backgroundColor = UIColor.systemGreen.withAlphaComponent(dark ? 0.12 : 0.10)
        statusDot.backgroundColor = .systemGreen
        bottomBar.backgroundColor = dark ? UIColor(red: 0.115, green: 0.115, blue: 0.125, alpha: 0.98) : UIColor(white: 1, alpha: 0.98)
        bottomBar.layer.borderWidth = 0.5
        bottomBar.layer.borderColor = UIColor.separator.cgColor
        setNeedsStatusBarAppearanceUpdate()
    }

    @objc private func refreshCatalog() { store.sync() }
    @objc private func gamesSelected() { configureTab(gamesTab, title: "Games", symbol: "scope", selected: true); configureTab(appsTab, title: "Ứng dụng", symbol: "square.grid.2x2.fill", selected: false) }
    @objc private func appsSelected() { configureTab(gamesTab, title: "Games", symbol: "scope", selected: false); configureTab(appsTab, title: "Ứng dụng", symbol: "square.grid.2x2.fill", selected: true); let a = UIAlertController(title: "Ứng dụng", message: "Khu vực ứng dụng.", preferredStyle: .alert); a.addAction(UIAlertAction(title: "Đóng", style: .default)); present(a, animated: true) }
}

// MARK: - Game card

final class GameCardView: UIView {
    let game: RemoteGame
    let accent: UIColor
    var onPlay: ((RemoteGame) -> Void)?
    var onInfo: ((RemoteGame) -> Void)?
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let playButton = UIButton(type: .system)
    private let infoButton = UIButton(type: .system)

    init(game: RemoteGame, accent: UIColor) { self.game = game; self.accent = accent; super.init(frame: .zero); build() }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func build() {
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 66).isActive = true
        layer.cornerRadius = 20
        layer.borderWidth = 1
        clipsToBounds = true

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFill
        iconView.clipsToBounds = true
        iconView.layer.cornerRadius = 13
        iconView.backgroundColor = UIColor.secondarySystemFill
        iconView.image = UIImage(systemName: "square.dashed")
        iconView.tintColor = .tertiaryLabel
        addSubview(iconView)

        titleLabel.text = game.displayName
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        statusLabel.text = "●  \(game.id == "aov" ? "Chạm để quay lại game" : game.statusText)"
        statusLabel.font = .systemFont(ofSize: 14, weight: .regular)
        statusLabel.textColor = accent.withAlphaComponent(0.92)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(statusLabel)

        playButton.setImage(UIImage(systemName: game.id == "aov" ? "arrow.up.right.square.fill" : "play.fill"), for: .normal)
        playButton.tintColor = accent
        playButton.addTarget(self, action: #selector(playTapped), for: .touchUpInside)
        playButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(playButton)

        infoButton.setImage(UIImage(systemName: "info.circle.fill"), for: .normal)
        infoButton.tintColor = accent.withAlphaComponent(0.92)
        infoButton.addTarget(self, action: #selector(infoTapped), for: .touchUpInside)
        infoButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(infoButton)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 13), iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 42), iconView.heightAnchor.constraint(equalToConstant: 42),
            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12), titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: playButton.leadingAnchor, constant: -4),
            statusLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor), statusLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: playButton.leadingAnchor, constant: -4),
            playButton.trailingAnchor.constraint(equalTo: infoButton.leadingAnchor, constant: -4), playButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            playButton.widthAnchor.constraint(equalToConstant: 34), playButton.heightAnchor.constraint(equalToConstant: 40),
            infoButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8), infoButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            infoButton.widthAnchor.constraint(equalToConstant: 34), infoButton.heightAnchor.constraint(equalToConstant: 40)
        ])

        RemoteImageLoader.shared.load(game.icon, fallback: game.id) { [weak self] image in
            guard let self else { return }
            if let image { self.iconView.image = image; self.iconView.tintColor = nil }
        }
        updateTheme()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) { super.traitCollectionDidChange(previousTraitCollection); updateTheme() }

    private func updateTheme() {
        let dark = traitCollection.userInterfaceStyle == .dark
        backgroundColor = dark ? UIColor(red: 0.115, green: 0.115, blue: 0.125, alpha: 1) : UIColor(red: 0.985, green: 0.988, blue: 0.995, alpha: 1)
        layer.borderColor = accent.withAlphaComponent(dark ? 0.13 : 0.22).cgColor
        titleLabel.textColor = .label
        iconView.backgroundColor = dark ? UIColor(white: 0.16, alpha: 1) : UIColor(white: 0.985, alpha: 1)
    }

    @objc private func playTapped() { UIImpactFeedbackGenerator(style: .light).impactOccurred(); onPlay?(game) }
    @objc private func infoTapped() { onInfo?(game) }
}
