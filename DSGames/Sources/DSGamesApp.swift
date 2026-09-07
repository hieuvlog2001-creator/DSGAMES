
import UIKit

// MARK: - Online catalog

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
}

struct GamesResponse: Codable {
    let version: Int
    let updatedAt: String?
    let expiresAt: String?
    let games: [RemoteGame]
}

private enum APIConfig {
    static let baseURL = "https://dsgames-catalog.hieuvlog2001.workers.dev"
    static let gamesURL = baseURL + "/api/games"
    static let requestTimeout: TimeInterval = 12
}

final class GamesAPI {
    static let shared = GamesAPI()
    private init() {}

    func fetchGames(completion: @escaping (Result<GamesResponse, Error>) -> Void) {
        guard let url = URL(string: APIConfig.gamesURL) else {
            completion(.failure(NSError(domain: "DSGames", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Invalid catalog URL"])))
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
                completion(.failure(NSError(domain: "DSGames", code: code, userInfo: [NSLocalizedDescriptionKey: "HTTP \(code)"])))
                return
            }
            guard let data else {
                completion(.failure(NSError(domain: "DSGames", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Empty catalog"])))
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



// MARK: - License Key

struct LicenseResponse: Codable {
    let valid: Bool
    let id: String?
    let label: String?
    let expiresAt: String?
    let error: String?
    let deviceModel: String?
    let iosVersion: String?
}

final class LicenseAPI {
    static let shared = LicenseAPI()
    private init() {}

    private func devicePayload() -> [String: Any] {
        ["deviceModel": DeviceInfo.modelName, "iosVersion": UIDevice.current.systemVersion]
    }

    private func request(path: String, key: String, completion: @escaping (Result<LicenseResponse, Error>) -> Void) {
        guard let url = URL(string: APIConfig.baseURL + path) else {
            completion(.failure(NSError(domain: "DSGames", code: 2001, userInfo: [NSLocalizedDescriptionKey: "Invalid license URL"])))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = APIConfig.requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body = devicePayload(); body["key"] = key
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error { completion(.failure(error)); return }
            guard let data else {
                completion(.failure(NSError(domain: "DSGames", code: 2002, userInfo: [NSLocalizedDescriptionKey: "Empty license response"])))
                return
            }
            do {
                let result = try JSONDecoder().decode(LicenseResponse.self, from: data)
                if result.valid { completion(.success(result)) }
                else {
                    let message = result.error ?? "License key không hợp lệ"
                    completion(.failure(NSError(domain: "DSGames", code: (response as? HTTPURLResponse)?.statusCode ?? 403, userInfo: [NSLocalizedDescriptionKey: message])))
                }
            } catch { completion(.failure(error)) }
        }.resume()
    }

    func activate(key: String, completion: @escaping (Result<LicenseResponse, Error>) -> Void) {
        request(path: "/api/license/activate", key: key, completion: completion)
    }

    func check(key: String, completion: @escaping (Result<LicenseResponse, Error>) -> Void) {
        request(path: "/api/license/check", key: key, completion: completion)
    }
}

enum DeviceInfo {
    static var modelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        let identifier = mirror.children.reduce(into: "") { result, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            result.append(String(UnicodeScalar(UInt8(value))))
        }
        let map: [String: String] = [
            "iPhone14,2": "iPhone 13 Pro", "iPhone14,3": "iPhone 13 Pro Max",
            "iPhone14,5": "iPhone 13", "iPhone14,7": "iPhone 14",
            "iPhone14,8": "iPhone 14 Plus", "iPhone15,2": "iPhone 14 Pro",
            "iPhone15,3": "iPhone 14 Pro Max", "iPhone15,4": "iPhone 15",
            "iPhone15,5": "iPhone 15 Plus", "iPhone16,1": "iPhone 15 Pro",
            "iPhone16,2": "iPhone 15 Pro Max", "iPhone17,1": "iPhone 16 Pro",
            "iPhone17,2": "iPhone 16 Pro Max", "iPhone17,3": "iPhone 16",
            "iPhone17,4": "iPhone 16 Plus", "iPhone17,5": "iPhone 16e",
            "iPhone18,1": "iPhone 17 Pro", "iPhone18,2": "iPhone 17 Pro Max",
            "iPhone18,3": "iPhone 17", "iPhone18,4": "iPhone Air"
        ]
        return map[identifier] ?? UIDevice.current.model
    }
}

final class LicenseStore {
    static let shared = LicenseStore()
    private let keyStorage = "dsgames.license.key"
    private(set) var key: String?
    private(set) var licenseID: String?
    private(set) var label: String?
    private(set) var expiresAt: Date?
    private(set) var active = false
    private(set) var lastError: String?
    var onChange: (() -> Void)?

    private init() { key = UserDefaults.standard.string(forKey: keyStorage) }

    var isValid: Bool {
        guard active else { return false }
        if let expiresAt { return expiresAt > Date() }
        return true
    }

    var expiryText: String {
        guard let expiresAt else { return "HSD: Không giới hạn" }
        let remaining = expiresAt.timeIntervalSinceNow
        if remaining <= 0 { return "HSD: Đã hết hạn" }
        let totalMinutes = Int(remaining / 60)
        let days = totalMinutes / 1440
        let hours = (totalMinutes % 1440) / 60
        let minutes = totalMinutes % 60
        if days > 0 { return "HSD: Còn \(days) ngày \(hours) giờ" }
        if hours > 0 { return "HSD: Còn \(hours) giờ \(minutes) phút" }
        return "HSD: Còn \(max(minutes, 1)) phút"
    }

    func activate(_ newKey: String, completion: @escaping (Bool, String) -> Void) {
        let normalized = newKey.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty else { completion(false, "Vui lòng nhập License Key."); return }
        LicenseAPI.shared.activate(key: normalized) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let response):
                    self.key = normalized
                    self.licenseID = response.id
                    self.label = response.label
                    self.expiresAt = Self.parseDate(response.expiresAt)
                    self.active = true
                    self.lastError = nil
                    UserDefaults.standard.set(normalized, forKey: self.keyStorage)
                    self.onChange?()
                    completion(true, "Kích hoạt thành công.")
                case .failure(let error):
                    self.active = false
                    self.lastError = error.localizedDescription
                    self.onChange?()
                    completion(false, error.localizedDescription)
                }
            }
        }
    }

    func check() {
        guard let key else { active = false; onChange?(); return }
        LicenseAPI.shared.check(key: key) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let response):
                    self.licenseID = response.id
                    self.label = response.label
                    self.expiresAt = Self.parseDate(response.expiresAt)
                    self.active = true
                    self.lastError = nil
                case .failure(let error):
                    self.active = false
                    self.lastError = error.localizedDescription
                }
                self.onChange?()
            }
        }
    }

    func clear() {
        key = nil
        licenseID = nil
        label = nil
        expiresAt = nil
        active = false
        lastError = nil
        UserDefaults.standard.removeObject(forKey: keyStorage)
        onChange?()
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        return ISO8601DateFormatter().date(from: value)
    }
}

final class RemoteImageLoader {
    static let shared = RemoteImageLoader()
    private let cache = NSCache<NSURL, UIImage>()

    func image(from value: String?, fallbackName: String?, completion: @escaping (UIImage?) -> Void) {
        if let fallbackName, let local = UIImage(named: fallbackName), (value == nil || value?.isEmpty == true || URL(string: value!)?.scheme == nil) {
            completion(local)
            return
        }

        guard let value, let url = URL(string: value),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            DispatchQueue.main.async { completion(fallbackName.flatMap { UIImage(named: $0) }) }
            return
        }

        if let cached = cache.object(forKey: url as NSURL) {
            DispatchQueue.main.async { completion(cached) }
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            let image = data.flatMap(UIImage.init(data:))
            if let image { self?.cache.setObject(image, forKey: url as NSURL) }
            DispatchQueue.main.async {
                completion(image ?? fallbackName.flatMap { UIImage(named: $0) })
            }
        }.resume()
    }
}

// MARK: - Store

final class GameStore {
    static let shared = GameStore()
    private let cacheKey = "dsgames.remote.catalog.v2"
    private(set) var games: [RemoteGame] = []
    private(set) var lastSync: Date?
    var onChange: (() -> Void)?
    private(set) var expiresAt: Date?

    private init() { loadCache() }

    func sync() {
        GamesAPI.shared.fetchGames { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let response):
                    self.expiresAt = Self.parseDate(response.expiresAt)
                    let newGames = response.games
                        .filter { $0.enabled }
                        .sorted {
                            if $0.sortOrder == $1.sortOrder {
                                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                            }
                            return $0.sortOrder < $1.sortOrder
                        }
                    let changed = newGames != self.games
                    self.games = newGames
                    self.lastSync = Date()
                    if let data = try? JSONEncoder().encode(response) {
                        UserDefaults.standard.set(data, forKey: self.cacheKey)
                    }
                    if changed { self.onChange?() }
                case .failure:
                    break
                }
            }
        }
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        return ISO8601DateFormatter().date(from: value)
    }

    private func loadCache() {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let response = try? JSONDecoder().decode(GamesResponse.self, from: data) {
            expiresAt = Self.parseDate(response.expiresAt)
            games = response.games.filter { $0.enabled }.sorted { $0.sortOrder < $1.sortOrder }
        } else {
            games = Self.fallbackGames
        }
    }

    static let fallbackGames: [RemoteGame] = [
        RemoteGame(id: "aov", name: "Liên Quân Mobile DS", developer: "", icon: "aov", banner: "aov", description: nil, version: "1.8", category: "MOBA", launchURL: nil, featured: true, enabled: true, sortOrder: 10, updatedAt: nil),
        RemoteGame(id: "standoff2", name: "Standoff 2 DS", developer: "", icon: nil, banner: nil, description: nil, version: "1.8", category: "FPS", launchURL: nil, featured: false, enabled: true, sortOrder: 20, updatedAt: nil),
        RemoteGame(id: "wildrift", name: "Wild Rift DS", developer: "", icon: "wr", banner: "wr", description: nil, version: "1.8", category: "MOBA", launchURL: nil, featured: false, enabled: true, sortOrder: 30, updatedAt: nil),
        RemoteGame(id: "ffth", name: "Free Fire DS", developer: "", icon: "ffth", banner: "ffth", description: nil, version: "1.8", category: "Battle Royale", launchURL: nil, featured: false, enabled: true, sortOrder: 40, updatedAt: nil),
        RemoteGame(id: "ffmax", name: "Free Fire MAX DS", developer: "", icon: "ffmax", banner: "ffmax", description: nil, version: "1.8", category: "Battle Royale", launchURL: nil, featured: false, enabled: true, sortOrder: 50, updatedAt: nil),
        RemoteGame(id: "cfm", name: "CrossFire Mobile DS", developer: "", icon: "cfm", banner: "cfm", description: nil, version: "1.8", category: "FPS", launchURL: nil, featured: false, enabled: true, sortOrder: 60, updatedAt: nil),
        RemoteGame(id: "8ball", name: "8 Ball Pool DS", developer: "", icon: nil, banner: nil, description: nil, version: "1.8", category: "Sports", launchURL: nil, featured: false, enabled: true, sortOrder: 70, updatedAt: nil),
        RemoteGame(id: "codm", name: "Call of Duty Mobile (VNG / Global) DS", developer: "", icon: nil, banner: nil, description: nil, version: "1.8", category: "FPS", launchURL: nil, featured: false, enabled: true, sortOrder: 80, updatedAt: nil)
    ]
}

// MARK: - App

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    private var syncTimer: Timer?
    private var expiryTimer: Timer?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.backgroundColor = .systemBackground
        window.rootViewController = MainViewController()
        self.window = window
        window.makeKeyAndVisible()
        startCatalogTimer()
        startExpiryTimer()
        LicenseStore.shared.check()
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        GameStore.shared.sync()
        LicenseStore.shared.check()
        startCatalogTimer()
        startExpiryTimer()
    }

    func applicationWillResignActive(_ application: UIApplication) {
        syncTimer?.invalidate()
        syncTimer = nil
        expiryTimer?.invalidate()
        expiryTimer = nil
    }

    private func startCatalogTimer() {
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            GameStore.shared.sync()
        }
    }

    private func startExpiryTimer() {
        expiryTimer?.invalidate()
        expiryTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .dsgamesExpiryTick, object: nil)
            }
        }
    }
}

extension Notification.Name {
    static let dsgamesExpiryTick = Notification.Name("DSGamesExpiryTick")
}

// MARK: - Main UI

final class MainViewController: UIViewController {
    private let store = GameStore.shared
    private let license = LicenseStore.shared
    private var didPromptForKey = false
    private let scrollView = UIScrollView()
    private let content = UIStackView()
    private let bottomBar = UIStackView()
    private var appsMode = false
    private var languageButton = UIButton(type: .system)

    override var preferredStatusBarStyle: UIStatusBarStyle {
        traitCollection.userInterfaceStyle == .dark ? .lightContent : .darkContent
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        buildUI()
        store.onChange = { [weak self] in self?.render() }
        license.onChange = { [weak self] in self?.render() }
        render()
        NotificationCenter.default.addObserver(self, selector: #selector(expiryTick), name: .dsgamesExpiryTick, object: nil)
        store.sync()
    }

    private func buildUI() {
        let header = UIStackView()
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = 8
        header.translatesAutoresizingMaskIntoConstraints = false

        let titleStack = UIStackView()
        titleStack.axis = .vertical
        titleStack.spacing = 1

        let title = label("DSGames", size: 25, weight: .bold)
        let device = UIDevice.current.model
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.8"
        let ios = UIDevice.current.systemVersion
        let subtitle = label("v\(version)  ·  \(device)  ·  iOS \(ios)", size: 12, weight: .regular)
        subtitle.textColor = .secondaryLabel
        titleStack.addArrangedSubview(title)
        titleStack.addArrangedSubview(subtitle)

        header.addArrangedSubview(titleStack)
        header.addArrangedSubview(UIView())

        languageButton = pillButton(title: "🇻🇳  VI ⌄")
        languageButton.addTarget(self, action: #selector(languageTapped), for: .touchUpInside)
        header.addArrangedSubview(languageButton)

        let more = UIButton(type: .system)
        more.setTitle("•••", for: .normal)
        more.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        more.setTitleColor(.systemBlue, for: .normal)
        more.backgroundColor = UIColor.systemBlue.withAlphaComponent(traitCollection.userInterfaceStyle == .dark ? 0.14 : 0.08)
        more.layer.cornerRadius = 23
        more.widthAnchor.constraint(equalToConstant: 46).isActive = true
        more.heightAnchor.constraint(equalToConstant: 46).isActive = true
        more.addTarget(self, action: #selector(moreTapped), for: .touchUpInside)
        header.addArrangedSubview(more)

        view.addSubview(header)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        content.axis = .vertical
        content.spacing = 12
        content.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(content)

        buildBottomBar()

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 18),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 18),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),

            content.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 2),
            content.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),
            content.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -22),
            content.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32),

            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomBar.heightAnchor.constraint(equalToConstant: 78)
        ])
    }

    private func buildBottomBar() {
        bottomBar.axis = .horizontal
        bottomBar.distribution = .fillEqually
        bottomBar.backgroundColor = UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(white: 0.12, alpha: 0.98) : .white
        }
        bottomBar.layer.borderWidth = 0.5
        bottomBar.layer.borderColor = UIColor.separator.cgColor
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomBar)

        let games = tabButton(icon: "crosshair", title: "Games", tag: 0)
        let apps = tabButton(icon: "square.grid.2x2.fill", title: "Ứng dụng", tag: 1)
        bottomBar.addArrangedSubview(games)
        bottomBar.addArrangedSubview(apps)
        updateTabs()
    }

    private func tabButton(icon: String, title: String, tag: Int) -> UIButton {
        let b = UIButton(type: .system)
        b.tag = tag
        b.setImage(UIImage(systemName: icon), for: .normal)
        b.setTitle(title, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        b.configuration = .plain()
        b.configuration?.imagePlacement = .top
        b.configuration?.imagePadding = 5
        b.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
        return b
    }

    private func updateTabs() {
        for case let b as UIButton in bottomBar.arrangedSubviews {
            let active = (b.tag == 0 && !appsMode) || (b.tag == 1 && appsMode)
            let c: UIColor = active ? .systemBlue : .secondaryLabel
            b.tintColor = c
            b.setTitleColor(c, for: .normal)
        }
    }

    @objc private func tabTapped(_ sender: UIButton) {
        appsMode = sender.tag == 1
        updateTabs()
        render()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        license.check()
        if license.key == nil && !didPromptForKey {
            didPromptForKey = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in self?.promptForLicenseKey() }
        }
    }

    @objc private func expiryTick() {
        render()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func render() {
        guard isViewLoaded else { return }
        content.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if appsMode {
            let heading = label("Ứng dụng", size: 28, weight: .bold)
            content.addArrangedSubview(heading)
            let empty = UIView()
            empty.heightAnchor.constraint(equalToConstant: 160).isActive = true
            let message = label("Các ứng dụng của DSGames sẽ hiển thị tại đây.", size: 15, weight: .regular)
            message.textColor = .secondaryLabel
            message.textAlignment = .center
            empty.addSubview(message)
            message.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                message.centerXAnchor.constraint(equalTo: empty.centerXAnchor),
                message.centerYAnchor.constraint(equalTo: empty.centerYAnchor)
            ])
            content.addArrangedSubview(empty)
            return
        }

        addReadyCard()
        content.addArrangedSubview(label("Chọn game", size: 27, weight: .bold))
        let info = label("ESP và menu nổi sẽ tự khởi động trước khi mở game.", size: 14, weight: .regular)
        info.textColor = .secondaryLabel
        content.addArrangedSubview(info)

        for (index, game) in store.games.enumerated() {
            addGameCard(game, index: index)
        }
    }

    private var isExpired: Bool {
        guard license.key != nil else { return false }
        return !license.isValid
    }

    private var expiryText: String {
        if license.key == nil { return "HSD: Chưa kích hoạt" }
        return license.expiryText
    }

    private func addReadyCard() {
        let card = UIView()
        card.backgroundColor = UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(white: 0.12, alpha: 1) : UIColor.white
        }
        card.layer.cornerRadius = 23
        card.layer.borderWidth = 1.2
        let expired = isExpired
        let stateColor: UIColor = license.isValid ? .systemGreen : (license.key == nil ? .systemOrange : .systemRed)
        card.layer.borderColor = stateColor.withAlphaComponent(0.25).cgColor
        card.heightAnchor.constraint(equalToConstant: 102).isActive = true

        let shield = UIView()
        shield.backgroundColor = stateColor.withAlphaComponent(0.14)
        shield.layer.cornerRadius = 30
        shield.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(shield)

        let icon = UIImageView(image: UIImage(systemName: "checkmark.shield.fill"))
        icon.tintColor = stateColor
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        shield.addSubview(icon)

        let titleText = license.isValid ? "Sẵn sàng" : (license.key == nil ? "Chưa kích hoạt" : "Đã hết hạn")
        let title = label(titleText, size: 18, weight: .semibold)
        let detail = label(expiryText, size: 15, weight: .regular)
        detail.textColor = .secondaryLabel
        let texts = UIStackView(arrangedSubviews: [title, detail])
        texts.axis = .vertical
        texts.spacing = 3
        texts.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(texts)

        let dot = UIView()
        dot.backgroundColor = stateColor
        dot.layer.cornerRadius = 8
        dot.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(dot)

        NSLayoutConstraint.activate([
            shield.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            shield.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            shield.widthAnchor.constraint(equalToConstant: 60),
            shield.heightAnchor.constraint(equalToConstant: 60),
            icon.leadingAnchor.constraint(equalTo: shield.leadingAnchor, constant: 15),
            icon.trailingAnchor.constraint(equalTo: shield.trailingAnchor, constant: -15),
            icon.topAnchor.constraint(equalTo: shield.topAnchor, constant: 15),
            icon.bottomAnchor.constraint(equalTo: shield.bottomAnchor, constant: -15),
            texts.leadingAnchor.constraint(equalTo: shield.trailingAnchor, constant: 14),
            texts.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            texts.trailingAnchor.constraint(lessThanOrEqualTo: dot.leadingAnchor, constant: -10),
            dot.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -17),
            dot.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 16),
            dot.heightAnchor.constraint(equalToConstant: 16)
        ])
        content.addArrangedSubview(card)
    }

    private func addGameCard(_ game: RemoteGame, index: Int) {
        let card = UIControl()
        card.backgroundColor = UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(white: 0.115, alpha: 1) : UIColor.white
        }
        card.layer.cornerRadius = 21
        card.layer.borderWidth = 1.0
        let accent = accentColor(for: index)
        card.layer.borderColor = accent.withAlphaComponent(0.26).cgColor
        card.heightAnchor.constraint(equalToConstant: 94).isActive = true
        card.accessibilityIdentifier = game.id
        card.addTarget(self, action: #selector(gameTapped(_:)), for: .touchUpInside)

        let image = UIImageView()
        image.contentMode = .scaleAspectFill
        image.clipsToBounds = true
        image.layer.cornerRadius = 15
        image.layer.borderWidth = 0.5
        image.layer.borderColor = UIColor.separator.cgColor
        image.backgroundColor = UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(white: 0.13, alpha: 1) : UIColor.white
        }
        image.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(image)

        let title = label(game.name, size: 16, weight: .semibold)
        title.numberOfLines = 1
        title.adjustsFontSizeToFitWidth = false

        let status = label(index == 0 ? "●  Chạm để quay lại game" : "●  Mở cùng menu overlay", size: 13, weight: .regular)
        status.textColor = accent
        status.numberOfLines = 1

        let texts = UIStackView(arrangedSubviews: [title, status])
        texts.axis = .vertical
        texts.spacing = 4
        texts.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(texts)

        let play = UIButton(type: .system)
        let playSymbol = index == 0 ? "arrow.up.right.square.fill" : "play.fill"
        play.setImage(UIImage(systemName: playSymbol), for: .normal)
        play.tintColor = accent
        play.contentHorizontalAlignment = .center
        play.translatesAutoresizingMaskIntoConstraints = false
        play.addTarget(self, action: #selector(playTapped(_:)), for: .touchUpInside)
        play.accessibilityIdentifier = game.id
        card.addSubview(play)

        let info = UIButton(type: .system)
        info.setImage(UIImage(systemName: "info.circle.fill"), for: .normal)
        info.tintColor = accent
        info.translatesAutoresizingMaskIntoConstraints = false
        info.addTarget(self, action: #selector(infoTapped(_:)), for: .touchUpInside)
        info.accessibilityIdentifier = game.id
        card.addSubview(info)

        NSLayoutConstraint.activate([
            image.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            image.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            image.widthAnchor.constraint(equalToConstant: 56),
            image.heightAnchor.constraint(equalToConstant: 56),

            texts.leadingAnchor.constraint(equalTo: image.trailingAnchor, constant: 12),
            texts.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            texts.trailingAnchor.constraint(lessThanOrEqualTo: play.leadingAnchor, constant: -8),

            play.trailingAnchor.constraint(equalTo: info.leadingAnchor, constant: -10),
            play.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            play.widthAnchor.constraint(equalToConstant: 30),
            play.heightAnchor.constraint(equalToConstant: 40),

            info.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            info.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            info.widthAnchor.constraint(equalToConstant: 34),
            info.heightAnchor.constraint(equalToConstant: 40)
        ])

        let fallback = localAssetName(for: game)
        image.tintColor = .tertiaryLabel
        image.image = UIImage(systemName: "square.grid.3x3")
        RemoteImageLoader.shared.image(from: game.icon, fallbackName: fallback) { loaded in
            image.image = loaded ?? UIImage(systemName: "square.grid.3x3")
            image.tintColor = loaded == nil ? .tertiaryLabel : nil
        }

        content.addArrangedSubview(card)
    }

    private func localAssetName(for game: RemoteGame) -> String? {
        if let icon = game.icon, UIImage(named: icon) != nil { return icon }
        switch game.id.lowercased() {
        case "aov": return "aov"
        case "wildrift": return "wr"
        case "ffth": return "ffth"
        case "ffmax": return "ffmax"
        case "cfm": return "cfm"
        default: return nil
        }
    }

    private func accentColor(for index: Int) -> UIColor {
        switch index % 7 {
        case 0: return .systemBlue
        case 1: return .systemOrange
        case 2: return .systemTeal
        case 3: return .systemRed
        case 4: return .systemOrange
        case 5: return .systemCyan
        default: return .systemGreen
        }
    }

    @objc private func gameTapped(_ sender: UIControl) {
        guard let id = sender.accessibilityIdentifier, let game = store.games.first(where: { $0.id == id }) else { return }
        showInfo(for: game)
    }

    @objc private func playTapped(_ sender: UIButton) {
        guard let id = sender.accessibilityIdentifier, let game = store.games.first(where: { $0.id == id }) else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if !license.isValid {
            promptForLicenseKey()
            return
        }
        if let raw = game.launchURL, let url = URL(string: raw) {
            UIApplication.shared.open(url)
        } else {
            let alert = UIAlertController(title: game.name, message: "Chưa cấu hình Launch URL cho game này.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }

    @objc private func infoTapped(_ sender: UIButton) {
        guard let id = sender.accessibilityIdentifier, let game = store.games.first(where: { $0.id == id }) else { return }
        showInfo(for: game)
    }

    private func showInfo(for game: RemoteGame) {
        let alert = UIAlertController(title: game.name, message: game.description ?? "Game được quản lý từ DSGames Catalog.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Đóng", style: .cancel))
        if let raw = game.launchURL, let url = URL(string: raw) {
            alert.addAction(UIAlertAction(title: "Mở game", style: .default) { _ in
                UIApplication.shared.open(url)
            })
        }
        present(alert, animated: true)
    }

    @objc private func languageTapped() {
        let alert = UIAlertController(title: "Ngôn ngữ", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "🇻🇳  Tiếng Việt", style: .default))
        alert.addAction(UIAlertAction(title: "English", style: .default))
        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        if let pop = alert.popoverPresentationController {
            pop.sourceView = languageButton
            pop.sourceRect = languageButton.bounds
        }
        present(alert, animated: true)
    }

    @objc private func moreTapped() {
        let alert = UIAlertController(title: "DSGames", message: license.key == nil ? "Chưa kích hoạt License Key." : "Key: \(license.licenseID ?? "-")\n\(license.expiryText)", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "🔑 Nhập / đổi License Key", style: .default) { [weak self] _ in self?.promptForLicenseKey() })
        if license.key != nil {
            alert.addAction(UIAlertAction(title: "Xóa License Key", style: .destructive) { [weak self] _ in
                self?.license.clear()
                self?.didPromptForKey = false
            })
        }
        alert.addAction(UIAlertAction(title: "Đồng bộ game", style: .default) { _ in GameStore.shared.sync() })
        alert.addAction(UIAlertAction(title: "Đóng", style: .cancel))
        if let pop = alert.popoverPresentationController {
            pop.sourceView = languageButton
            pop.sourceRect = languageButton.bounds
        }
        present(alert, animated: true)
    }

    private func promptForLicenseKey() {
        let alert = UIAlertController(title: "License Key", message: "Nhập key được cấp để kích hoạt DSGames.", preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "DSG-XXXX-XXXX-XXXX-XXXX-XXXXXXXX"
            field.autocapitalizationType = .allCharacters
            field.autocorrectionType = .no
            field.text = self.license.key
        }
        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        alert.addAction(UIAlertAction(title: "Kích hoạt", style: .default) { [weak self, weak alert] _ in
            guard let self, let text = alert?.textFields?.first?.text else { return }
            self.license.activate(text) { [weak self] success, message in
                guard let self else { return }
                if !success {
                    let error = UIAlertController(title: "Không thể kích hoạt", message: message, preferredStyle: .alert)
                    error.addAction(UIAlertAction(title: "Nhập lại", style: .default) { _ in self.promptForLicenseKey() })
                    error.addAction(UIAlertAction(title: "Đóng", style: .cancel))
                    self.present(error, animated: true)
                }
            }
        })
        present(alert, animated: true)
    }

    private func pillButton(title: String) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        b.setTitleColor(.systemBlue, for: .normal)
        b.backgroundColor = UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(white: 0.08, alpha: 1) : UIColor.white
        }
        b.layer.cornerRadius = 23
        b.layer.borderWidth = 0.8
        b.layer.borderColor = UIColor.separator.cgColor
        b.contentEdgeInsets = UIEdgeInsets(top: 0, left: 13, bottom: 0, right: 13)
        b.heightAnchor.constraint(equalToConstant: 46).isActive = true
        return b
    }

    private func label(_ text: String, size: CGFloat, weight: UIFont.Weight) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = .systemFont(ofSize: size, weight: weight)
        l.textColor = .label
        l.numberOfLines = 1
        return l
    }
}
