import UIKit

// MARK: - Remote catalog models

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
        if !developer.isEmpty { return developer }
        return category ?? "Game"
    }
}

struct GamesResponse: Codable {
    let version: Int
    let updatedAt: String?
    let games: [RemoteGame]
}

// Change this single URL after deploying the Cloudflare Worker.
// Example: https://your-worker.workers.dev/api/games
private enum APIConfig {
    static let gamesURL = "https://YOUR-DSGAMES-WORKER.workers.dev/api/games"
    static let requestTimeout: TimeInterval = 12
}

// MARK: - API client

final class GamesAPI {
    static let shared = GamesAPI()
    private init() {}

    func fetchGames(completion: @escaping (Result<GamesResponse, Error>) -> Void) {
        guard let url = URL(string: APIConfig.gamesURL), !APIConfig.gamesURL.contains("YOUR-DSGAMES") else {
            completion(.failure(NSError(domain: "DSGames", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Configure APIConfig.gamesURL in DSGamesApp.swift"])))
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = APIConfig.requestTimeout
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("DSGames-iOS/1.8", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error { completion(.failure(error)); return }
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                completion(.failure(NSError(domain: "DSGames", code: code, userInfo: [NSLocalizedDescriptionKey: "Server returned HTTP \(code)"])))
                return
            }
            guard let data else {
                completion(.failure(NSError(domain: "DSGames", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Empty response"])))
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

    func image(from string: String?, fallbackName: String? = nil, completion: @escaping (UIImage?) -> Void) {
        if let fallbackName, let local = UIImage(named: fallbackName) {
            if string?.isEmpty != false { completion(local); return }
        }
        guard let string, let url = URL(string: string), ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
            completion(fallbackName.flatMap(UIImage.init(named:)))
            return
        }
        if let cached = cache.object(forKey: url as NSURL) { completion(cached); return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            let image = data.flatMap(UIImage.init(data:))
            if let image { self?.cache.setObject(image, forKey: url as NSURL) }
            DispatchQueue.main.async { completion(image ?? fallbackName.flatMap(UIImage.init(named:))) }
        }.resume()
    }
}

// MARK: - Store

final class GameStore {
    static let shared = GameStore()
    private(set) var games: [RemoteGame] = []
    private let cacheKey = "dsgames.remote.catalog.v1"
    private(set) var lastSync: Date?
    var onChange: (() -> Void)?

    private init() {
        loadCache()
    }

    func sync(completion: ((Bool) -> Void)? = nil) {
        GamesAPI.shared.fetchGames { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self?.games = response.games.filter { $0.enabled }.sorted { lhs, rhs in
                        if lhs.sortOrder == rhs.sortOrder { return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending }
                        return lhs.sortOrder < rhs.sortOrder
                    }
                    self?.lastSync = Date()
                    self?.saveCache(response)
                    self?.onChange?()
                    completion?(true)
                case .failure:
                    completion?(false)
                }
            }
        }
    }

    private func saveCache(_ response: GamesResponse) {
        if let data = try? JSONEncoder().encode(response) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    private func loadCache() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey), let response = try? JSONDecoder().decode(GamesResponse.self, from: data) else {
            games = Self.fallbackGames
            return
        }
        games = response.games.filter { $0.enabled }.sorted { $0.sortOrder < $1.sortOrder }
    }

    static let fallbackGames: [RemoteGame] = [
        RemoteGame(id: "aov", name: "Arena of Valor", developer: "Liên Quân Mobile", icon: "aov", banner: "aov", description: "Arena of Valor", version: "1.0", category: "MOBA", launchURL: nil, featured: true, enabled: true, sortOrder: 10, updatedAt: nil),
        RemoteGame(id: "cfm", name: "CrossFire Mobile", developer: "CrossFire Legends", icon: "cfm", banner: "cfm", description: "CrossFire Mobile", version: "1.0", category: "FPS", launchURL: nil, featured: false, enabled: true, sortOrder: 20, updatedAt: nil),
        RemoteGame(id: "ffmax", name: "Free Fire MAX", developer: "Garena", icon: "ffmax", banner: "ffmax", description: "Free Fire MAX", version: "1.0", category: "Battle Royale", launchURL: nil, featured: false, enabled: true, sortOrder: 30, updatedAt: nil),
        RemoteGame(id: "wildrift", name: "Wild Rift", developer: "League of Legends", icon: "h_ahri", banner: "h_ahri", description: "League of Legends: Wild Rift", version: "1.0", category: "MOBA", launchURL: nil, featured: false, enabled: true, sortOrder: 40, updatedAt: nil)
    ]
}

// MARK: - App

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.backgroundColor = .black
        let root = MainViewController()
        window.rootViewController = root
        self.window = window
        window.makeKeyAndVisible()
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        GameStore.shared.sync()
    }
}

// MARK: - Main controller

final class MainViewController: UIViewController, UISearchBarDelegate, UIScrollViewDelegate {
    private let scrollView = UIScrollView()
    private let content = UIStackView()
    private let searchBar = UISearchBar()
    private let refresh = UIRefreshControl()
    private let tabBar = UIStackView()
    private let store = GameStore.shared
    private var selectedTab = 0
    private var query = ""
    private var library = Set<String>()
    private var recentlyViewed: [String] = []
    private var gameButtons: [String: UIButton] = [:]

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        loadLocalState()
        buildShell()
        store.onChange = { [weak self] in self?.renderCurrent() }
        renderCurrent()
        store.sync()
    }

    private func buildShell() {
        let header = UIStackView()
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = 8
        header.translatesAutoresizingMaskIntoConstraints = false

        let titleStack = UIStackView()
        titleStack.axis = .vertical
        titleStack.spacing = 1
        let title = makeLabel("DSGames", size: 25, weight: .bold)
        titleStack.addArrangedSubview(title)
        let subtitle = makeLabel("GAME CENTER", size: 9, weight: .bold)
        subtitle.textColor = UIColor(white: 0.52, alpha: 1)
        titleStack.addArrangedSubview(subtitle)
        header.addArrangedSubview(titleStack)
        header.addArrangedSubview(UIView())

        let bell = circleButton(symbol: "bell.fill")
        bell.addTarget(self, action: #selector(showNotifications), for: .touchUpInside)
        let avatar = circleButton(title: "T")
        avatar.addTarget(self, action: #selector(showProfile), for: .touchUpInside)
        header.addArrangedSubview(bell)
        header.addArrangedSubview(avatar)
        view.addSubview(header)

        searchBar.delegate = self
        searchBar.placeholder = "Search games"
        searchBar.searchBarStyle = .minimal
        searchBar.backgroundColor = UIColor(white: 0.07, alpha: 1)
        searchBar.layer.cornerRadius = 16
        searchBar.clipsToBounds = true
        searchBar.searchTextField.textColor = .white
        searchBar.searchTextField.attributedPlaceholder = NSAttributedString(string: "Search games", attributes: [.foregroundColor: UIColor(white: 0.42, alpha: 1)])
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchBar)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.keyboardDismissMode = .onDrag
        refresh.tintColor = .white
        refresh.addTarget(self, action: #selector(refreshCatalog), for: .valueChanged)
        scrollView.refreshControl = refresh
        view.addSubview(scrollView)

        content.axis = .vertical
        content.spacing = 14
        content.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(content)

        buildTabBar()
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            bell.widthAnchor.constraint(equalToConstant: 40), bell.heightAnchor.constraint(equalToConstant: 40),
            avatar.widthAnchor.constraint(equalToConstant: 40), avatar.heightAnchor.constraint(equalToConstant: 40),
            searchBar.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 14),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            searchBar.heightAnchor.constraint(equalToConstant: 48),
            scrollView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: tabBar.topAnchor),
            content.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 4),
            content.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 18),
            content.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -18),
            content.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -30),
            content.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -36),
            tabBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            tabBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            tabBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -5),
            tabBar.heightAnchor.constraint(equalToConstant: 56)
        ])
    }

    private func buildTabBar() {
        tabBar.axis = .horizontal
        tabBar.distribution = .fillEqually
        tabBar.spacing = 5
        tabBar.backgroundColor = UIColor(white: 0.07, alpha: 0.98)
        tabBar.layer.cornerRadius = 18
        tabBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tabBar)
        let items = [("house.fill", "Home"), ("square.stack.3d.up.fill", "Library"), ("person.3.fill", "Champions"), ("gearshape.fill", "Settings")]
        for (index, item) in items.enumerated() {
            let button = UIButton(type: .system)
            button.tag = index
            button.setImage(UIImage(systemName: item.0), for: .normal)
            button.setTitle("  " + item.1, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 10, weight: .semibold)
            button.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
            tabBar.addArrangedSubview(button)
        }
        updateTabAppearance()
    }

    @objc private func tabTapped(_ sender: UIButton) {
        selectedTab = sender.tag
        updateTabAppearance()
        searchBar.text = ""
        query = ""
        renderCurrent()
    }

    private func updateTabAppearance() {
        for case let button as UIButton in tabBar.arrangedSubviews {
            let active = button.tag == selectedTab
            let color = active ? UIColor.white : UIColor(white: 0.45, alpha: 1)
            button.tintColor = color
            button.setTitleColor(color, for: .normal)
        }
    }

    private func renderCurrent() {
        guard isViewLoaded else { return }
        content.arrangedSubviews.forEach { $0.removeFromSuperview() }
        gameButtons.removeAll()
        switch selectedTab {
        case 1: showLibrary()
        case 2: showChampions()
        case 3: showSettings()
        default: showHome()
        }
    }

    private func showHome() {
        addSectionTitle("Featured")
        let featured = filteredGames().first(where: { $0.featured }) ?? filteredGames().first
        if let game = featured { addFeaturedCard(game) }
        if !library.isEmpty {
            addSectionTitle("Quick access")
            let saved = store.games.filter { library.contains($0.id) }
            saved.prefix(3).forEach { addGameRow($0) }
        }
        addSectionTitle("Games")
        let games = filteredGames()
        if games.isEmpty { content.addArrangedSubview(emptyCard(title: "No games found", message: "Try another title or publisher.")) }
        games.forEach { addGameRow($0) }
        addSectionTitle("Champion library")
        addChampionPreview()
    }

    private func showLibrary() {
        addSectionTitle("My Library")
        let saved = store.games.filter { library.contains($0.id) }
        if saved.isEmpty { content.addArrangedSubview(emptyCard(title: "Your library is empty", message: "Tap + on a game to add it here.")) }
        saved.forEach { addGameRow($0) }
        addSectionTitle("Library overview")
        addQuickStats()
        let recent = recentlyViewed.compactMap { id in store.games.first(where: { $0.id == id }) }
        if !recent.isEmpty {
            addSectionTitle("Recently viewed")
            recent.prefix(3).forEach { addGameRow($0) }
        }
    }

    private func showChampions() {
        addSectionTitle("Champion library")
        let info = makeLabel("Explore champions included with DSGames.", size: 14, weight: .regular)
        info.textColor = UIColor(white: 0.55, alpha: 1)
        content.addArrangedSubview(info)
        addChampionGrid()
    }

    private func showSettings() {
        addSectionTitle("Settings")
        addSettingRow(icon: "arrow.clockwise", title: "Catalog sync", detail: "Updates automatically when the website changes")
        addSettingRow(icon: "wifi", title: "Last sync", detail: lastSyncText())
        addSettingRow(icon: "person.crop.circle", title: "Account", detail: "Tân Phương Nam")
        addSettingRow(icon: "moon.fill", title: "Appearance", detail: "Dark")
        addSettingRow(icon: "info.circle", title: "About DSGames", detail: "Version 1.8 • Online catalog")
        let footer = makeLabel("DSGames • Game Center", size: 12, weight: .medium)
        footer.textColor = UIColor(white: 0.35, alpha: 1)
        footer.textAlignment = .center
        content.addArrangedSubview(footer)
    }

    private func lastSyncText() -> String {
        guard let date = store.lastSync else { return "Not synced yet" }
        return DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .short)
    }

    private func filteredGames() -> [RemoteGame] {
        guard !query.isEmpty else { return store.games }
        return store.games.filter { $0.name.localizedCaseInsensitiveContains(query) || $0.developer.localizedCaseInsensitiveContains(query) || ($0.category ?? "").localizedCaseInsensitiveContains(query) }
    }

    private func addSectionTitle(_ text: String) {
        content.addArrangedSubview(makeLabel(text, size: 22, weight: .bold))
    }

    private func addFeaturedCard(_ game: RemoteGame) {
        let card = UIView()
        card.backgroundColor = UIColor(white: 0.045, alpha: 1)
        card.layer.cornerRadius = 25
        card.clipsToBounds = true
        card.heightAnchor.constraint(equalToConstant: 230).isActive = true
        let image = UIImageView()
        image.contentMode = .scaleAspectFill
        image.alpha = 0.58
        image.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(image)
        let overlay = UIView()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.30)
        overlay.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(overlay)
        let title = makeLabel(game.name, size: 26, weight: .bold)
        let sub = makeLabel(game.subtitle, size: 14, weight: .regular)
        sub.textColor = UIColor(white: 0.70, alpha: 1)
        let tag = makeLabel("RECOMMENDED", size: 11, weight: .bold)
        tag.textColor = .systemCyan
        let add = UIButton(type: .system)
        add.setTitle(library.contains(game.id) ? "✓ In library" : "Add to library", for: .normal)
        add.setTitleColor(.black, for: .normal)
        add.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        add.backgroundColor = .white
        add.layer.cornerRadius = 22
        add.contentEdgeInsets = UIEdgeInsets(top: 0, left: 18, bottom: 0, right: 18)
        add.tag = store.games.firstIndex(of: game) ?? 0
        add.addTarget(self, action: #selector(featuredLibraryTapped(_:)), for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [tag, title, sub, add])
        stack.axis = .vertical
        stack.spacing = 7
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            image.topAnchor.constraint(equalTo: card.topAnchor), image.bottomAnchor.constraint(equalTo: card.bottomAnchor), image.leadingAnchor.constraint(equalTo: card.leadingAnchor), image.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            overlay.topAnchor.constraint(equalTo: card.topAnchor), overlay.bottomAnchor.constraint(equalTo: card.bottomAnchor), overlay.leadingAnchor.constraint(equalTo: card.leadingAnchor), overlay.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20), stack.trailingAnchor.constraint(lessThanOrEqualTo: card.trailingAnchor, constant: -20), stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20)
        ])
        RemoteImageLoader.shared.image(from: game.banner ?? game.icon, fallbackName: game.icon) { image.image = $0 }
        let tap = UITapGestureRecognizer(target: self, action: #selector(featuredTapped(_:)))
        card.addGestureRecognizer(tap)
        card.isUserInteractionEnabled = true
        card.accessibilityIdentifier = game.id
        content.addArrangedSubview(card)
    }

    @objc private func featuredLibraryTapped(_ sender: UIButton) {
        let games = filteredGames()
        guard sender.tag < games.count else { return }
        toggleLibrary(games[sender.tag])
    }

    @objc private func featuredTapped(_ gesture: UITapGestureRecognizer) {
        guard let card = gesture.view, let id = card.accessibilityIdentifier, let game = store.games.first(where: { $0.id == id }) else { return }
        showGameDetail(game)
    }

    private func addGameRow(_ game: RemoteGame) {
        let row = UIControl()
        row.backgroundColor = UIColor(white: 0.045, alpha: 1)
        row.layer.cornerRadius = 18
        row.heightAnchor.constraint(equalToConstant: 82).isActive = true
        row.accessibilityIdentifier = game.id
        row.addTarget(self, action: #selector(gameRowTapped(_:)), for: .touchUpInside)

        let image = UIImageView()
        image.contentMode = .scaleAspectFill
        image.clipsToBounds = true
        image.layer.cornerRadius = 14
        image.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(image)
        let title = makeLabel(game.name, size: 16, weight: .semibold)
        let sub = makeLabel(game.subtitle, size: 13, weight: .regular)
        sub.textColor = UIColor(white: 0.58, alpha: 1)
        let texts = UIStackView(arrangedSubviews: [title, sub])
        texts.axis = .vertical
        texts.spacing = 4
        texts.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(texts)
        let plus = UIButton(type: .system)
        plus.setImage(UIImage(systemName: library.contains(game.id) ? "checkmark" : "plus"), for: .normal)
        plus.tintColor = .white
        plus.backgroundColor = UIColor(white: 0.10, alpha: 1)
        plus.layer.cornerRadius = 18
        plus.translatesAutoresizingMaskIntoConstraints = false
        plus.tag = store.games.firstIndex(of: game) ?? 0
        plus.addTarget(self, action: #selector(rowLibraryTapped(_:)), for: .touchUpInside)
        row.addSubview(plus)
        NSLayoutConstraint.activate([
            image.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 10), image.centerYAnchor.constraint(equalTo: row.centerYAnchor), image.widthAnchor.constraint(equalToConstant: 62), image.heightAnchor.constraint(equalToConstant: 62),
            texts.leadingAnchor.constraint(equalTo: image.trailingAnchor, constant: 14), texts.centerYAnchor.constraint(equalTo: row.centerYAnchor), texts.trailingAnchor.constraint(lessThanOrEqualTo: plus.leadingAnchor, constant: -8),
            plus.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -12), plus.centerYAnchor.constraint(equalTo: row.centerYAnchor), plus.widthAnchor.constraint(equalToConstant: 36), plus.heightAnchor.constraint(equalToConstant: 36)
        ])
        RemoteImageLoader.shared.image(from: game.icon, fallbackName: game.icon) { image.image = $0 }
        content.addArrangedSubview(row)
    }

    @objc private func gameRowTapped(_ sender: UIControl) {
        guard let id = sender.accessibilityIdentifier, let game = store.games.first(where: { $0.id == id }) else { return }
        recentlyViewed.removeAll { $0 == id }
        recentlyViewed.insert(id, at: 0)
        recentlyViewed = Array(recentlyViewed.prefix(12))
        UserDefaults.standard.set(recentlyViewed, forKey: "dsgames.recent")
        showGameDetail(game)
    }

    @objc private func rowLibraryTapped(_ sender: UIButton) {
        guard sender.tag < store.games.count else { return }
        toggleLibrary(store.games[sender.tag])
    }

    private func toggleLibrary(_ game: RemoteGame) {
        if library.contains(game.id) { library.remove(game.id) } else { library.insert(game.id) }
        UserDefaults.standard.set(Array(library), forKey: "dsgames.library")
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        renderCurrent()
    }

    private func addQuickStats() {
        let card = UIView()
        card.backgroundColor = UIColor(white: 0.045, alpha: 1)
        card.layer.cornerRadius = 18
        card.heightAnchor.constraint(equalToConstant: 76).isActive = true
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        let values = [("\(library.count)", "Saved"), ("\(store.games.count)", "Games"), ("\(recentlyViewed.count)", "Viewed")]
        for value in values {
            let s = UIStackView(arrangedSubviews: [makeLabel(value.0, size: 20, weight: .bold), makeLabel(value.1, size: 11, weight: .medium)])
            s.axis = .vertical; s.alignment = .center; s.spacing = 3
            stack.addArrangedSubview(s)
        }
        card.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: card.leadingAnchor), stack.trailingAnchor.constraint(equalTo: card.trailingAnchor), stack.topAnchor.constraint(equalTo: card.topAnchor), stack.bottomAnchor.constraint(equalTo: card.bottomAnchor)])
        content.addArrangedSubview(card)
    }

    private func addChampionPreview() {
        let names = ["h_ahri", "h_akali", "h_ashe", "h_kassadin", "h_jinx", "h_ekko"]
        let grid = UIStackView()
        grid.axis = .horizontal
        grid.spacing = 8
        for name in names {
            let image = UIImageView(image: UIImage(named: name))
            image.contentMode = .scaleAspectFill
            image.clipsToBounds = true
            image.layer.cornerRadius = 14
            image.widthAnchor.constraint(equalToConstant: 58).isActive = true
            image.heightAnchor.constraint(equalToConstant: 58).isActive = true
            grid.addArrangedSubview(image)
        }
        content.addArrangedSubview(grid)
    }

    private func addChampionGrid() {
        let names = ["h_ahri", "h_akali", "h_ashe", "h_kassadin", "h_jinx", "h_ekko", "h_yasuo", "h_lux", "h_garen", "h_zed", "h_jax", "h_sylas", "h_katarina", "h_kaisa", "h_vayne", "h_sett", "h_morgana", "h_malphite"]
        let scroll = UIScrollView()
        scroll.heightAnchor.constraint(equalToConstant: 240).isActive = true
        let grid = UIStackView()
        grid.axis = .vertical
        grid.spacing = 8
        for rowStart in stride(from: 0, to: names.count, by: 6) {
            let row = UIStackView(); row.axis = .horizontal; row.spacing = 8; row.distribution = .fillEqually
            for name in names[rowStart..<min(rowStart + 6, names.count)] {
                let image = UIImageView(image: UIImage(named: String(name)))
                image.contentMode = .scaleAspectFill; image.clipsToBounds = true; image.layer.cornerRadius = 14
                image.widthAnchor.constraint(equalToConstant: 48).isActive = true; image.heightAnchor.constraint(equalToConstant: 48).isActive = true
                row.addArrangedSubview(image)
            }
            grid.addArrangedSubview(row)
        }
        grid.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(grid)
        NSLayoutConstraint.activate([grid.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor), grid.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor), grid.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor), grid.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor), grid.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)])
        content.addArrangedSubview(scroll)
    }

    private func addSettingRow(icon: String, title: String, detail: String) {
        let row = UIView()
        row.backgroundColor = UIColor(white: 0.045, alpha: 1)
        row.layer.cornerRadius = 17
        row.heightAnchor.constraint(equalToConstant: 66).isActive = true
        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = .white
        iconView.contentMode = .center
        iconView.backgroundColor = UIColor(white: 0.09, alpha: 1)
        iconView.layer.cornerRadius = 12
        iconView.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(iconView)
        let titleLabel = makeLabel(title, size: 15, weight: .semibold)
        let detailLabel = makeLabel(detail, size: 12, weight: .regular)
        detailLabel.textColor = UIColor(white: 0.55, alpha: 1)
        let stack = UIStackView(arrangedSubviews: [titleLabel, detailLabel]); stack.axis = .vertical; stack.spacing = 3; stack.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(stack)
        NSLayoutConstraint.activate([iconView.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 10), iconView.centerYAnchor.constraint(equalTo: row.centerYAnchor), iconView.widthAnchor.constraint(equalToConstant: 44), iconView.heightAnchor.constraint(equalToConstant: 44), stack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12), stack.centerYAnchor.constraint(equalTo: row.centerYAnchor), stack.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -12)])
        content.addArrangedSubview(row)
    }

    private func showGameDetail(_ game: RemoteGame) {
        let vc = GameDetailViewController(game: game, isSaved: library.contains(game.id)) { [weak self] action in
            guard let self else { return }
            if action == .toggle { self.toggleLibrary(game) }
            if action == .launch, let raw = game.launchURL, let url = URL(string: raw), UIApplication.shared.canOpenURL(url) { UIApplication.shared.open(url) }
        }
        present(vc, animated: true)
    }

    @objc private func showNotifications() {
        let alert = UIAlertController(title: "Notifications", message: "Game catalog sync is enabled. New games added on your DSGames website will appear automatically after the next sync.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func showProfile() {
        let sheet = UIAlertController(title: "Tân Phương Nam", message: "DSGames account", preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Refresh game catalog", style: .default) { [weak self] _ in self?.refreshCatalog() })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let pop = sheet.popoverPresentationController { pop.sourceView = view; pop.sourceRect = CGRect(x: view.bounds.maxX - 70, y: 80, width: 1, height: 1) }
        present(sheet, animated: true)
    }

    @objc private func refreshCatalog() {
        refresh.beginRefreshing()
        store.sync { [weak self] _ in
            self?.refresh.endRefreshing()
        }
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if selectedTab == 0 { renderCurrent() }
    }

    private func loadLocalState() {
        library = Set(UserDefaults.standard.stringArray(forKey: "dsgames.library") ?? [])
        recentlyViewed = UserDefaults.standard.stringArray(forKey: "dsgames.recent") ?? []
    }

    private func makeLabel(_ text: String, size: CGFloat, weight: UIFont.Weight) -> UILabel {
        let label = UILabel(); label.text = text; label.font = .systemFont(ofSize: size, weight: weight); label.textColor = .white; label.numberOfLines = 0; return label
    }

    private func circleButton(symbol: String) -> UIButton {
        let b = UIButton(type: .system); b.setImage(UIImage(systemName: symbol), for: .normal); b.tintColor = .white; b.backgroundColor = UIColor(white: 0.08, alpha: 1); b.layer.cornerRadius = 20; return b
    }

    private func circleButton(title: String) -> UIButton {
        let b = UIButton(type: .system); b.setTitle(title, for: .normal); b.setTitleColor(.white, for: .normal); b.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold); b.backgroundColor = UIColor(white: 0.08, alpha: 1); b.layer.cornerRadius = 20; return b
    }

    private func emptyCard(title: String, message: String) -> UIView {
        let v = UIView(); v.backgroundColor = UIColor(white: 0.045, alpha: 1); v.layer.cornerRadius = 18; v.heightAnchor.constraint(equalToConstant: 110).isActive = true
        let s = UIStackView(arrangedSubviews: [makeLabel(title, size: 16, weight: .semibold), makeLabel(message, size: 12, weight: .regular)]); s.axis = .vertical; s.alignment = .center; s.spacing = 5; s.translatesAutoresizingMaskIntoConstraints = false; v.addSubview(s)
        NSLayoutConstraint.activate([s.centerXAnchor.constraint(equalTo: v.centerXAnchor), s.centerYAnchor.constraint(equalTo: v.centerYAnchor)])
        return v
    }
}

// MARK: - Detail

enum GameDetailAction { case toggle, launch }

final class GameDetailViewController: UIViewController {
    private let game: RemoteGame
    private let saved: Bool
    private let handler: (GameDetailAction) -> Void

    init(game: RemoteGame, isSaved: Bool, handler: @escaping (GameDetailAction) -> Void) {
        self.game = game; self.saved = isSaved; self.handler = handler
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad(); view.backgroundColor = .black
        let scroll = UIScrollView(); scroll.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(scroll)
        let stack = UIStackView(); stack.axis = .vertical; stack.spacing = 16; stack.translatesAutoresizingMaskIntoConstraints = false; scroll.addSubview(stack)
        let hero = UIImageView(); hero.contentMode = .scaleAspectFill; hero.clipsToBounds = true; hero.layer.cornerRadius = 24; hero.heightAnchor.constraint(equalToConstant: 260).isActive = true; stack.addArrangedSubview(hero)
        RemoteImageLoader.shared.image(from: game.banner ?? game.icon, fallbackName: game.icon) { hero.image = $0 }
        stack.addArrangedSubview(label(game.name, 27, .bold))
        stack.addArrangedSubview(label(game.subtitle, 15, .regular, .gray))
        if let category = game.category { stack.addArrangedSubview(label(category + (game.version.map { " • v\($0)" } ?? ""), 13, .medium, .gray)) }
        let action = UIButton(type: .system); action.setTitle(saved ? "✓ In library" : "Add to library", for: .normal); action.setTitleColor(.black, for: .normal); action.backgroundColor = .white; action.layer.cornerRadius = 22; action.heightAnchor.constraint(equalToConstant: 46).isActive = true; action.addTarget(self, action: #selector(toggleTapped), for: .touchUpInside); stack.addArrangedSubview(action)
        if game.launchURL != nil { let launch = UIButton(type: .system); launch.setTitle("Open game", for: .normal); launch.setTitleColor(.white, for: .normal); launch.backgroundColor = UIColor(white: 0.10, alpha: 1); launch.layer.cornerRadius = 22; launch.heightAnchor.constraint(equalToConstant: 46).isActive = true; launch.addTarget(self, action: #selector(launchTapped), for: .touchUpInside); stack.addArrangedSubview(launch) }
        if let description = game.description, !description.isEmpty { stack.addArrangedSubview(label(description, 15, .regular, .lightGray)) }
        NSLayoutConstraint.activate([scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16), scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18), scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18), scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor), stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor), stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor), stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor), stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -30), stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)])
        let close = UIButton(type: .system); close.setTitle("Done", for: .normal); close.setTitleColor(.white, for: .normal); close.addTarget(self, action: #selector(closeTapped), for: .touchUpInside); close.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(close); NSLayoutConstraint.activate([close.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8), close.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18)])
    }

    @objc private func closeTapped() { dismiss(animated: true) }
    @objc private func toggleTapped() { handler(.toggle); dismiss(animated: true) }
    @objc private func launchTapped() { handler(.launch) }
    private func label(_ text: String, _ size: CGFloat, _ weight: UIFont.Weight, _ color: UIColor = .white) -> UILabel { let l = UILabel(); l.text = text; l.font = .systemFont(ofSize: size, weight: weight); l.textColor = color; l.numberOfLines = 0; return l }
}
