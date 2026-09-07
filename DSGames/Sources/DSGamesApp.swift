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

    var subtitle: String {
        if !developer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return developer }
        return category ?? "Game"
    }
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
            if let error {
                completion(.failure(error))
                return
            }
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                completion(.failure(NSError(domain: "DSGames", code: code, userInfo: [NSLocalizedDescriptionKey: "HTTP \(code)"])))
                return
            }
            guard let data else {
                completion(.failure(NSError(domain: "DSGames", code: 2, userInfo: [NSLocalizedDescriptionKey: "Empty response"])))
                return
            }
            do {
                completion(.success(try JSONDecoder().decode(GamesResponse.self, from: data)))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}

final class RemoteImageLoader {
    static let shared = RemoteImageLoader()
    private let cache = NSCache<NSURL, UIImage>()

    func load(_ value: String?, fallback: String? = nil, completion: @escaping (UIImage?) -> Void) {
        if let value, !value.isEmpty, let url = URL(string: value), let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
            if let cached = cache.object(forKey: url as NSURL) {
                completion(cached)
                return
            }
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
    private let cacheKey = "dsgames.remote.catalog.v2"
    var onChange: (() -> Void)?
    var isSyncing = false

    private init() {
        loadCache()
    }

    func sync(completion: ((Bool) -> Void)? = nil) {
        guard !isSyncing else {
            completion?(false)
            return
        }
        isSyncing = true
        GamesAPI.shared.fetchGames { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isSyncing = false
                switch result {
                case .success(let response):
                    self.games = response.games
                        .filter { $0.enabled }
                        .sorted {
                            if $0.sortOrder == $1.sortOrder {
                                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                            }
                            return $0.sortOrder < $1.sortOrder
                        }
                    if let data = try? JSONEncoder().encode(response) {
                        UserDefaults.standard.set(data, forKey: self.cacheKey)
                    }
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
        RemoteGame(id: "aov", name: "Arena of Valor", developer: "Liên Quân Mobile", icon: "aov", banner: "aov", description: "Arena of Valor", version: "1.0", category: "MOBA", launchURL: nil, featured: true, enabled: true, sortOrder: 10, updatedAt: nil),
        RemoteGame(id: "cfm", name: "CrossFire Mobile", developer: "CrossFire Legends", icon: "cfm", banner: "cfm", description: "CrossFire Mobile", version: "1.0", category: "FPS", launchURL: nil, featured: false, enabled: true, sortOrder: 20, updatedAt: nil),
        RemoteGame(id: "ffmax", name: "Free Fire MAX", developer: "Garena", icon: "ffmax", banner: "ffmax", description: "Free Fire MAX", version: "1.0", category: "Battle Royale", launchURL: nil, featured: false, enabled: true, sortOrder: 30, updatedAt: nil)
    ]
}

// MARK: - App delegate

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.backgroundColor = .systemBackground
        window.rootViewController = MainViewController()
        self.window = window
        window.makeKeyAndVisible()
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        GameStore.shared.sync()
    }
}

// MARK: - Main UI

final class MainViewController: UIViewController {
    private let store = GameStore.shared
    private let scrollView = UIScrollView()
    private let content = UIStackView()
    private let gameStack = UIStackView()
    private let statusTitle = UILabel()
    private let statusDetail = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let syncIcon = UIImageView()
    private var gamesTab = UIButton(type: .system)
    private var appsTab = UIButton(type: .system)
    private let bottomBar = UIView()
    private var selectedTab = 0

    override var preferredStatusBarStyle: UIStatusBarStyle { .darkContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.985, green: 0.988, blue: 0.995, alpha: 1)
        buildUI()
        store.onChange = { [weak self] in self?.renderGames() }
        renderGames()
        store.sync()
    }

    private func buildUI() {
        let top = UIStackView()
        top.axis = .horizontal
        top.alignment = .center
        top.translatesAutoresizingMaskIntoConstraints = false

        let titleStack = UIStackView()
        titleStack.axis = .vertical
        titleStack.spacing = 1

        let title = label("DSGames", size: 27, weight: .bold)
        let device = label(deviceSubtitle(), size: 12, weight: .regular)
        device.textColor = UIColor(white: 0.50, alpha: 1)
        titleStack.addArrangedSubview(title)
        titleStack.addArrangedSubview(device)

        let language = pillButton(title: "🇻🇳  VI ⌄")
        language.addTarget(self, action: #selector(languageTapped), for: .touchUpInside)
        let more = circleButton(symbol: "ellipsis")
        more.addTarget(self, action: #selector(moreTapped), for: .touchUpInside)

        top.addArrangedSubview(titleStack)
        top.addArrangedSubview(UIView())
        top.addArrangedSubview(language)
        top.setCustomSpacing(10, after: language)
        top.addArrangedSubview(more)
        view.addSubview(top)

        let statusCard = makeStatusCard()
        view.addSubview(statusCard)

        let heading = UIStackView()
        heading.axis = .vertical
        heading.spacing = 4
        let h = label("Chọn game", size: 28, weight: .bold)
        let sub = label("Danh sách game được đồng bộ tự động từ máy chủ.", size: 15, weight: .regular)
        sub.textColor = UIColor(white: 0.50, alpha: 1)
        heading.addArrangedSubview(h)
        heading.addArrangedSubview(sub)
        view.addSubview(heading)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        let refresh = UIRefreshControl()
        refresh.tintColor = .systemGray
        refresh.addTarget(self, action: #selector(refreshCatalog), for: .valueChanged)
        scrollView.refreshControl = refresh
        view.addSubview(scrollView)

        content.axis = .vertical
        content.spacing = 12
        content.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(content)

        gameStack.axis = .vertical
        gameStack.spacing = 12
        content.addArrangedSubview(gameStack)
        content.addArrangedSubview(UIView())

        buildBottomBar()

        NSLayoutConstraint.activate([
            top.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 13),
            top.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 25),
            top.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            top.heightAnchor.constraint(equalToConstant: 54),

            statusCard.topAnchor.constraint(equalTo: top.bottomAnchor, constant: 17),
            statusCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            statusCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            statusCard.heightAnchor.constraint(equalToConstant: 102),

            heading.topAnchor.constraint(equalTo: statusCard.bottomAnchor, constant: 22),
            heading.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 25),
            heading.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            scrollView.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 15),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),

            content.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 2),
            content.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 24),
            content.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -24),
            content.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            content.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -48)
        ])
    }

    private func makeStatusCard() -> UIView {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = UIColor(red: 0.96, green: 0.98, blue: 1.0, alpha: 1)
        card.layer.cornerRadius = 24
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor(red: 0.82, green: 0.88, blue: 0.95, alpha: 1).cgColor

        let iconHolder = UIView()
        iconHolder.translatesAutoresizingMaskIntoConstraints = false
        iconHolder.backgroundColor = UIColor(red: 0.88, green: 0.94, blue: 1, alpha: 1)
        iconHolder.layer.cornerRadius = 24

        syncIcon.image = UIImage(systemName: "gearshape.2.fill")
        syncIcon.tintColor = UIColor.systemBlue
        syncIcon.contentMode = .scaleAspectFit
        syncIcon.translatesAutoresizingMaskIntoConstraints = false
        iconHolder.addSubview(syncIcon)
        card.addSubview(iconHolder)

        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false
        statusTitle.text = "Đang chuẩn bị hệ thống"
        statusTitle.font = .systemFont(ofSize: 17, weight: .bold)
        statusTitle.textColor = UIColor(white: 0.12, alpha: 1)
        statusDetail.text = "Đang đồng bộ danh sách game..."
        statusDetail.font = .systemFont(ofSize: 14, weight: .regular)
        statusDetail.textColor = UIColor(white: 0.55, alpha: 1)
        textStack.addArrangedSubview(statusTitle)
        textStack.addArrangedSubview(statusDetail)
        card.addSubview(textStack)

        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.color = .systemGray
        spinner.startAnimating()
        card.addSubview(spinner)

        NSLayoutConstraint.activate([
            iconHolder.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 15),
            iconHolder.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            iconHolder.widthAnchor.constraint(equalToConstant: 48),
            iconHolder.heightAnchor.constraint(equalToConstant: 48),
            syncIcon.centerXAnchor.constraint(equalTo: iconHolder.centerXAnchor),
            syncIcon.centerYAnchor.constraint(equalTo: iconHolder.centerYAnchor),
            syncIcon.widthAnchor.constraint(equalToConstant: 25),
            syncIcon.heightAnchor.constraint(equalToConstant: 25),
            textStack.leadingAnchor.constraint(equalTo: iconHolder.trailingAnchor, constant: 14),
            textStack.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: spinner.leadingAnchor, constant: -10),
            spinner.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -17),
            spinner.centerYAnchor.constraint(equalTo: card.centerYAnchor)
        ])
        return card
    }

    private func buildBottomBar() {
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.backgroundColor = UIColor(white: 1, alpha: 0.97)
        bottomBar.layer.borderWidth = 0.5
        bottomBar.layer.borderColor = UIColor.systemGray5.cgColor
        view.addSubview(bottomBar)

        gamesTab = tabButton(title: "Games", symbol: "scope")
        appsTab = tabButton(title: "Ứng dụng", symbol: "square.grid.2x2.fill")
        gamesTab.addTarget(self, action: #selector(gamesSelected), for: .touchUpInside)
        appsTab.addTarget(self, action: #selector(appsSelected), for: .touchUpInside)

        let tabs = UIStackView(arrangedSubviews: [gamesTab, appsTab])
        tabs.axis = .horizontal
        tabs.distribution = .fillEqually
        tabs.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(tabs)

        NSLayoutConstraint.activate([
            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomBar.heightAnchor.constraint(equalToConstant: 84),
            tabs.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor),
            tabs.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor),
            tabs.topAnchor.constraint(equalTo: bottomBar.topAnchor, constant: 5),
            tabs.bottomAnchor.constraint(equalTo: bottomBar.safeAreaLayoutGuide.bottomAnchor, constant: -2)
        ])
        updateTabs()
    }

    private func renderGames() {
        gameStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if store.games.isEmpty {
            let empty = label("Chưa có game khả dụng", size: 16, weight: .semibold)
            empty.textAlignment = .center
            empty.textColor = UIColor.systemGray
            gameStack.addArrangedSubview(empty)
        } else {
            for (index, game) in store.games.enumerated() {
                let card = GameCardView(game: game, accent: accentColor(for: index))
                card.onPlay = { [weak self] game in self?.play(game) }
                card.onInfo = { [weak self] game in self?.showInfo(game) }
                gameStack.addArrangedSubview(card)
            }
        }

        statusTitle.text = "Đang chuẩn bị hệ thống"
        statusDetail.text = "Đã đồng bộ \(store.games.count) game"
        spinner.stopAnimating()
        scrollView.refreshControl?.endRefreshing()
    }

    private func play(_ game: RemoteGame) {
        guard let raw = game.launchURL, !raw.isEmpty, let url = URL(string: raw) else {
            showInfo(game)
            return
        }
        UIApplication.shared.open(url)
    }

    private func showInfo(_ game: RemoteGame) {
        let alert = UIAlertController(title: game.name, message: [game.subtitle, game.category, game.version.map { "v\($0)" }, game.description].compactMap { $0 }.joined(separator: "\n"), preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Đóng", style: .cancel))
        if let urlString = game.launchURL, let url = URL(string: urlString), !urlString.isEmpty {
            alert.addAction(UIAlertAction(title: "Mở game", style: .default) { _ in UIApplication.shared.open(url) })
        }
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.maxY - 100, width: 1, height: 1)
        }
        present(alert, animated: true)
    }

    private func deviceSubtitle() -> String {
        let version = UIDevice.current.systemVersion
        return "v1.9.1 · \(UIDevice.current.model) · iOS \(version)"
    }

    private func accentColor(for index: Int) -> UIColor {
        let colors: [UIColor] = [.systemTeal, .systemRed, .systemOrange, .systemBlue, .systemGreen, .systemPurple]
        return colors[index % colors.count]
    }

    private func label(_ text: String, size: CGFloat, weight: UIFont.Weight) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = .systemFont(ofSize: size, weight: weight)
        l.textColor = UIColor(white: 0.12, alpha: 1)
        l.numberOfLines = 0
        return l
    }

    private func pillButton(title: String) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.setTitleColor(.systemBlue, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        b.backgroundColor = .white
        b.layer.cornerRadius = 22
        b.layer.borderWidth = 1
        b.layer.borderColor = UIColor.systemGray5.cgColor
        b.contentEdgeInsets = UIEdgeInsets(top: 10, left: 15, bottom: 10, right: 15)
        return b
    }

    private func circleButton(symbol: String) -> UIButton {
        let b = UIButton(type: .system)
        b.setImage(UIImage(systemName: symbol), for: .normal)
        b.tintColor = .systemBlue
        b.backgroundColor = UIColor(red: 0.92, green: 0.96, blue: 1, alpha: 1)
        b.layer.cornerRadius = 21
        b.translatesAutoresizingMaskIntoConstraints = false
        b.widthAnchor.constraint(equalToConstant: 42).isActive = true
        b.heightAnchor.constraint(equalToConstant: 42).isActive = true
        return b
    }

    private func tabButton(title: String, symbol: String) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.setImage(UIImage(systemName: symbol), for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
        b.tintColor = .systemGray
        b.setTitleColor(.systemGray, for: .normal)
        b.configuration = .plain()
        b.configuration?.imagePlacement = .top
        b.configuration?.imagePadding = 5
        return b
    }

    private func updateTabs() {
        let selected = UIColor.systemBlue
        gamesTab.tintColor = selected
        gamesTab.setTitleColor(selected, for: .normal)
        appsTab.tintColor = selected
        appsTab.setTitleColor(selected, for: .normal)
        if selectedTab == 0 {
            gamesTab.alpha = 1
            appsTab.alpha = 0.65
        } else {
            gamesTab.alpha = 0.65
            appsTab.alpha = 1
        }
    }

    @objc private func refreshCatalog() {
        statusDetail.text = "Đang đồng bộ danh sách game..."
        spinner.startAnimating()
        store.sync()
    }

    @objc private func gamesSelected() {
        selectedTab = 0
        updateTabs()
    }

    @objc private func appsSelected() {
        selectedTab = 1
        updateTabs()
        let alert = UIAlertController(title: "Ứng dụng", message: "Khu vực ứng dụng sẽ hiển thị các tiện ích được quản lý từ hệ thống DSGames.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Đóng", style: .default))
        present(alert, animated: true)
    }

    @objc private func languageTapped() {
        let alert = UIAlertController(title: "Ngôn ngữ", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "🇻🇳  Tiếng Việt", style: .default))
        alert.addAction(UIAlertAction(title: "🇬🇧  English", style: .default))
        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.maxX - 80, y: 100, width: 1, height: 1)
        }
        present(alert, animated: true)
    }

    @objc private func moreTapped() {
        let alert = UIAlertController(title: "DSGames", message: "Danh mục game được cập nhật tự động từ Cloudflare.", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Đồng bộ ngay", style: .default) { [weak self] _ in self?.refreshCatalog() })
        alert.addAction(UIAlertAction(title: "Đóng", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.maxX - 40, y: 100, width: 1, height: 1)
        }
        present(alert, animated: true)
    }
}

// MARK: - Game card

final class GameCardView: UIView {
    let game: RemoteGame
    let accent: UIColor
    var onPlay: ((RemoteGame) -> Void)?
    var onInfo: ((RemoteGame) -> Void)?

    private let iconView = UIImageView()

    init(game: RemoteGame, accent: UIColor) {
        self.game = game
        self.accent = accent
        super.init(frame: .zero)
        build()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func build() {
        backgroundColor = .white
        layer.cornerRadius = 21
        layer.borderWidth = 1
        layer.borderColor = accent.withAlphaComponent(0.16).cgColor
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 106).isActive = true

        let iconHolder = UIView()
        iconHolder.translatesAutoresizingMaskIntoConstraints = false
        iconHolder.backgroundColor = UIColor(white: 0.975, alpha: 1)
        iconHolder.layer.cornerRadius = 15
        iconHolder.clipsToBounds = true
        addSubview(iconHolder)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFill
        iconView.image = UIImage(systemName: "square.grid.3x3")
        iconView.tintColor = UIColor.systemGray3
        iconHolder.addSubview(iconView)

        let title = UILabel()
        title.text = game.name
        title.font = .systemFont(ofSize: 17, weight: .semibold)
        title.textColor = UIColor(white: 0.20, alpha: 1)
        title.numberOfLines = 1

        let status = UILabel()
        status.text = "●  Sẵn sàng"
        status.font = .systemFont(ofSize: 13, weight: .regular)
        status.textColor = accent.withAlphaComponent(0.65)

        let textStack = UIStackView(arrangedSubviews: [title, status])
        textStack.axis = .vertical
        textStack.spacing = 6
        textStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textStack)

        let play = UIButton(type: .system)
        play.setImage(UIImage(systemName: "play.fill"), for: .normal)
        play.tintColor = accent.withAlphaComponent(0.55)
        play.addTarget(self, action: #selector(playTapped), for: .touchUpInside)
        play.translatesAutoresizingMaskIntoConstraints = false
        addSubview(play)

        let info = UIButton(type: .system)
        info.setImage(UIImage(systemName: "info.circle.fill"), for: .normal)
        info.tintColor = accent.withAlphaComponent(0.62)
        info.addTarget(self, action: #selector(infoTapped), for: .touchUpInside)
        info.translatesAutoresizingMaskIntoConstraints = false
        addSubview(info)

        NSLayoutConstraint.activate([
            iconHolder.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 15),
            iconHolder.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconHolder.widthAnchor.constraint(equalToConstant: 66),
            iconHolder.heightAnchor.constraint(equalToConstant: 66),
            iconView.leadingAnchor.constraint(equalTo: iconHolder.leadingAnchor),
            iconView.trailingAnchor.constraint(equalTo: iconHolder.trailingAnchor),
            iconView.topAnchor.constraint(equalTo: iconHolder.topAnchor),
            iconView.bottomAnchor.constraint(equalTo: iconHolder.bottomAnchor),
            textStack.leadingAnchor.constraint(equalTo: iconHolder.trailingAnchor, constant: 14),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: play.leadingAnchor, constant: -6),
            play.centerYAnchor.constraint(equalTo: centerYAnchor),
            play.trailingAnchor.constraint(equalTo: info.leadingAnchor, constant: -2),
            play.widthAnchor.constraint(equalToConstant: 32),
            play.heightAnchor.constraint(equalToConstant: 42),
            info.centerYAnchor.constraint(equalTo: centerYAnchor),
            info.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -13),
            info.widthAnchor.constraint(equalToConstant: 34),
            info.heightAnchor.constraint(equalToConstant: 42)
        ])

        RemoteImageLoader.shared.load(game.icon, fallback: game.id) { [weak self] image in
            guard let self else { return }
            if let image {
                self.iconView.image = image
                self.iconView.tintColor = nil
                self.iconView.contentMode = .scaleAspectFill
            }
        }
    }

    @objc private func playTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onPlay?(game)
    }

    @objc private func infoTapped() {
        onInfo?(game)
    }
}
