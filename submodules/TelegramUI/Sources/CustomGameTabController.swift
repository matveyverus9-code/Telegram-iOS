import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData

public final class CustomGameTabController: ViewController {
    private let theme: PresentationTheme
    private let userId: Int
    private let tabKind: String
    private let api = URL(string: "https://tg-api.matveyverus9.workers.dev")!

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let segments = UISegmentedControl()
    private var section = 0
    private var gameMode = 0
    private var currency = "stars"
    private var multiplier = 1
    private var frameColor = "#7C5CFF"

    private var stars = 0
    private var ton = 0.0
    private var energy = 100
    private var maxEnergy = 100
    private var pendingTaps = 0
    private var tapWork: DispatchWorkItem?
    private var quests: [Quest] = []
    private var items: [Gift] = []
    private var selectedCase = "starter"
    private var selectedSource: Gift?
    private var selectedTarget: Gift?
    private var speedLevel = 1
    private var bagLevel = 1
    private var nextMouseCost = 100
    private var shieldUntil = 0
    private var crashTimer: Timer?

    private let gold = UIColor(red: 1, green: 0.72, blue: 0.12, alpha: 1)

    public init(theme: PresentationTheme, title: String, iconName: String, userId: Int) {
        self.theme = theme
        self.userId = userId
        self.tabKind = title
        let navData = NavigationBarPresentationData(
            theme: NavigationBarTheme(
                overallDarkAppearance: theme.overallDarkAppearance,
                buttonColor: theme.rootController.navigationBar.buttonColor,
                disabledButtonColor: theme.rootController.navigationBar.disabledButtonColor,
                primaryTextColor: theme.rootController.navigationBar.primaryTextColor,
                backgroundColor: theme.rootController.navigationBar.opaqueBackgroundColor,
                enableBackgroundBlur: true,
                separatorColor: theme.rootController.navigationBar.separatorColor,
                badgeBackgroundColor: theme.rootController.navigationBar.badgeBackgroundColor,
                badgeStrokeColor: theme.rootController.navigationBar.badgeStrokeColor,
                badgeTextColor: theme.rootController.navigationBar.badgeTextColor
            ),
            strings: NavigationBarStrings(back: "Назад", close: "Закрыть")
        )
        super.init(navigationBarPresentationData: navData)
        self.title = title
        self.tabBarItem.title = title
        self.tabBarItem.image = UIImage(systemName: iconName)
        self.tabBarItem.selectedImage = UIImage(systemName: iconName + ".fill") ?? UIImage(systemName: iconName)
    }

    required public init(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        tapWork?.cancel()
        crashTimer?.invalidate()
    }

    override public func displayNodeDidLoad() {
        super.displayNodeDidLoad()
        displayNode.backgroundColor = theme.list.blocksBackgroundColor
        buildLayout()
        if tabKind == "Тапалка" {
            showTapper()
        } else {
            showCases()
            loadInventory()
        }
    }

    // MARK: Layout

    private func buildLayout() {
        let root = displayNode.view
        root.backgroundColor = theme.list.blocksBackgroundColor
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
        root.addSubview(scrollView)

        let host = UIView()
        host.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(host)

        stack.axis = .vertical
        stack.spacing = 13
        stack.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: root.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            host.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            host.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            host.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            host.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            stack.topAnchor.constraint(equalTo: host.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: host.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: host.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: host.bottomAnchor, constant: -24)
        ])
    }

    private func clear() {
        stack.arrangedSubviews.forEach { stack.removeArrangedSubview($0); $0.removeFromSuperview() }
        view.endEditing(true)
    }

    private func configureSegments(_ titles: [String], selected: Int) {
        self.segments.removeAllSegments()
        for (i, title) in titles.enumerated() { self.segments.insertSegment(withTitle: title, at: i, animated: false) }
        self.segments.selectedSegmentIndex = selected
        self.segments.selectedSegmentTintColor = .systemBlue
        self.segments.backgroundColor = theme.list.itemBlocksBackgroundColor
        self.segments.removeTarget(self, action: #selector(changeSection), for: .valueChanged)
        self.segments.addTarget(self, action: #selector(changeSection), for: .valueChanged)
        stack.addArrangedSubview(self.segments)
    }

    @objc private func changeSection() {
        section = segments.selectedSegmentIndex
        if tabKind == "Тапалка" {
            [showTapper, showMouse, showQuests][max(0, min(2, section))]()
        } else {
            [showCases, showGames, showFrameShop, showInventory][max(0, min(3, section))]()
        }
    }

    private func card(_ heading: String? = nil) -> UIView {
        let v = UIView()
        v.backgroundColor = theme.list.itemBlocksBackgroundColor
        v.layer.cornerRadius = 18
        v.layer.cornerCurve = .continuous
        v.layer.borderWidth = 0.5
        v.layer.borderColor = UIColor.separator.withAlphaComponent(0.25).cgColor
        if let heading {
            let l = label(heading, 16, .bold)
            l.translatesAutoresizingMaskIntoConstraints = false
            v.addSubview(l)
            NSLayoutConstraint.activate([
                l.topAnchor.constraint(equalTo: v.topAnchor, constant: 14),
                l.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 15),
                l.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -15)
            ])
        }
        return v
    }

    private func label(_ text: String, _ size: CGFloat = 15, _ weight: UIFont.Weight = .regular, _ color: UIColor? = nil) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = .systemFont(ofSize: size, weight: weight)
        l.textColor = color ?? theme.list.itemPrimaryTextColor
        l.numberOfLines = 0
        return l
    }

    private func vstack(_ spacing: CGFloat = 8) -> UIStackView {
        let v = UIStackView()
        v.axis = .vertical
        v.spacing = spacing
        return v
    }

    private func button(_ title: String, _ color: UIColor = .systemBlue, _ action: Selector, enabled: Bool = true) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.setTitleColor(.white, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        b.titleLabel?.numberOfLines = 0
        b.backgroundColor = color
        b.layer.cornerRadius = 13
        b.layer.cornerCurve = .continuous
        b.contentEdgeInsets = UIEdgeInsets(top: 11, left: 12, bottom: 11, right: 12)
        b.isEnabled = enabled
        b.alpha = enabled ? 1 : 0.45
        b.addTarget(self, action: action, for: .touchUpInside)
        return b
    }

    private func field(_ placeholder: String, _ keyboard: UIKeyboardType = .default, id: String? = nil) -> UITextField {
        let f = UITextField()
        f.placeholder = placeholder
        f.keyboardType = keyboard
        f.autocorrectionType = .no
        f.autocapitalizationType = .none
        f.font = .systemFont(ofSize: 16)
        f.textColor = theme.list.itemPrimaryTextColor
        f.backgroundColor = theme.list.blocksBackgroundColor
        f.layer.cornerRadius = 11
        f.layer.borderWidth = 0.5
        f.layer.borderColor = UIColor.separator.cgColor
        f.heightAnchor.constraint(equalToConstant: 46).isActive = true
        f.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
        f.leftViewMode = .always
        f.accessibilityIdentifier = id
        return f
    }

    private func add(_ v: UIView) { stack.addArrangedSubview(v) }

    private func cardContent(_ heading: String, views: [UIView]) -> UIView {
        let c = card(heading)
        let s = vstack()
        views.forEach { s.addArrangedSubview($0) }
        s.translatesAutoresizingMaskIntoConstraints = false
        c.addSubview(s)
        NSLayoutConstraint.activate([
            s.topAnchor.constraint(equalTo: c.topAnchor, constant: 46),
            s.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 14),
            s.trailingAnchor.constraint(equalTo: c.trailingAnchor, constant: -14),
            s.bottomAnchor.constraint(equalTo: c.bottomAnchor, constant: -14)
        ])
        return c
    }

    private func status(_ text: String, error: Bool = false) {
        let l = label(text, 13, .medium, error ? .systemRed : .secondaryLabel)
        l.textAlignment = .center
        add(l)
    }

    private func feedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        let h = UIImpactFeedbackGenerator(style: style)
        h.prepare()
        h.impactOccurred()
    }

    private func setNewBadge() { DispatchQueue.main.async { self.tabBarItem.badgeValue = "Новое!" } }

    private func findField(_ id: String) -> UITextField? {
        func walk(_ v: UIView) -> UITextField? {
            if let f = v as? UITextField, f.accessibilityIdentifier == id { return f }
            for child in v.subviews { if let found = walk(child) { return found } }
            return nil
        }
        return walk(displayNode.view)
    }

    private static func dateString(_ timestamp: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(timestamp)))
    }

    // MARK: API

    private func send(_ path: String, method: String = "GET", body: [String: Any] = [:], completion: @escaping (Result<[String: Any], Error>) -> Void) {
        var components = URLComponents(url: api.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if method == "GET" && (path == "games/quests" || path == "inventory") {
            components.queryItems = [URLQueryItem(name: "user_id", value: "\(userId)")]
        }
        var req = URLRequest(url: components.url!)
        req.httpMethod = method
        req.timeoutInterval = 25
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if method != "GET" {
            var payload = body
            payload["user_id"] = userId
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            do { req.httpBody = try JSONSerialization.data(withJSONObject: payload) }
            catch { completion(.failure(error)); return }
        }
        URLSession.shared.dataTask(with: req) { data, response, error in
            if let error { DispatchQueue.main.async { completion(.failure(error)) }; return }
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), let data else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                DispatchQueue.main.async { completion(.failure(APIError.http(code))) }
                return
            }
            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      (json["ok"] as? Bool) != false else { throw APIError.badResponse }
                DispatchQueue.main.async { completion(.success(json)) }
            } catch { DispatchQueue.main.async { completion(.failure(error)) } }
        }.resume()
    }

    private func run(_ path: String, body: [String: Any] = [:], done: @escaping ([String: Any]) -> Void) {
        send(path, method: "POST", body: body) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let json): done(json)
            case .failure(let error): self.status("Ошибка: \(error.localizedDescription)", error: true)
            }
        }
    }

    private func getInt(_ j: [String: Any], _ k: String, _ fallback: Int = 0) -> Int {
        (j[k] as? NSNumber)?.intValue ?? fallback
    }
    private func getDouble(_ j: [String: Any], _ k: String, _ fallback: Double = 0) -> Double {
        (j[k] as? NSNumber)?.doubleValue ?? fallback
    }

    // MARK: Tapper

    private func balanceCards() -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 9
        row.distribution = .fillEqually
        for (title, value) in [("⭐️ Звёзды", "\(stars)"), ("💎 TON", String(format: "%.3f", ton))] {
            let c = cardContent(title, views: [label(value, 23, .bold)])
            row.addArrangedSubview(c)
        }
        return row
    }

    private func showTapper() {
        clear()
        configureSegments(["Тапалка", "Мышка", "Квесты"], selected: 0)
        add(balanceCards())
        let progress = UIProgressView(progressViewStyle: .default)
        progress.progressTintColor = .systemGreen
        progress.progress = maxEnergy > 0 ? Float(energy) / Float(maxEnergy) : 0
        add(cardContent("⚡ Энергия", views: [label("\(energy) / \(maxEnergy)", 13, .medium, .secondaryLabel), progress]))

        let star = UIButton(type: .system)
        star.setTitle("⭐️", for: .normal)
        star.titleLabel?.font = .systemFont(ofSize: 112)
        star.setTitleColor(gold, for: .normal)
        star.backgroundColor = gold.withAlphaComponent(0.10)
        star.layer.cornerRadius = 112
        star.layer.shadowColor = gold.cgColor
        star.layer.shadowOpacity = 0.5
        star.layer.shadowRadius = 20
        star.heightAnchor.constraint(equalToConstant: 225).isActive = true
        star.addTarget(self, action: #selector(tapStar(_:)), for: .touchUpInside)
        add(star)
        add(label("Нажимай на звезду — каждый тап приносит +1 ⭐️", 13, .medium, .secondaryLabel))
        add(button("Обновить баланс", .secondaryLabel, #selector(refreshTapData)))
    }

    @objc private func tapStar(_ sender: UIButton) {
        feedback(.medium)
        UIView.animate(withDuration: 0.11, animations: { sender.transform = CGAffineTransform(scaleX: 0.87, y: 0.87) }) { _ in
            UIView.animate(withDuration: 0.45, delay: 0, usingSpringWithDamping: 0.32, initialSpringVelocity: 0.8) { sender.transform = .identity }
        }
        let plus = UILabel()
        plus.text = "+1"
        plus.font = .systemFont(ofSize: 25, weight: .heavy)
        plus.textColor = gold
        plus.sizeToFit()
        plus.center = CGPoint(x: sender.bounds.midX + CGFloat.random(in: -30...30), y: sender.bounds.midY)
        sender.addSubview(plus)
        UIView.animate(withDuration: 0.7, animations: { plus.alpha = 0; plus.transform = CGAffineTransform(translationX: 0, y: -65) }) { _ in plus.removeFromSuperview() }
        pendingTaps += 1
        tapWork?.cancel()
        if pendingTaps >= 10 { flushTaps() }
        else {
            let work = DispatchWorkItem { [weak self] in self?.flushTaps() }
            tapWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
        }
    }

    private func flushTaps() {
        guard pendingTaps > 0 else { return }
        let count = pendingTaps
        pendingTaps = 0
        run("game/tap", body: ["taps": count]) { json in
            self.stars = self.getInt(json, "stars", self.stars)
            self.ton = self.getDouble(json, "ton", self.ton)
            self.energy = self.getInt(json, "energy", self.energy)
            self.maxEnergy = self.getInt(json, "max_energy", self.maxEnergy)
            self.showTapper()
            self.status("Отправлено тапов: \(count)")
        }
    }

    @objc private func refreshTapData() { flushTaps(); showTapper() }

    // MARK: Mouse

    private func showMouse() {
        clear()
        configureSegments(["Тапалка", "Мышка", "Квесты"], selected: 1)
        add(cardContent("🐭 Мышка-воришка", views: [
            label("⚡ Скорость: уровень \(speedLevel)", 16, .semibold),
            label("🎒 Рюкзак: уровень \(bagLevel)", 16, .semibold),
            label("Следующее улучшение: \(nextMouseCost) ⭐️", 13, .medium, .secondaryLabel)
        ]))
        let upgrades = UIStackView()
        upgrades.axis = .horizontal
        upgrades.spacing = 8
        upgrades.distribution = .fillEqually
        upgrades.addArrangedSubview(button("⚡ Скорость", .systemIndigo, #selector(upgradeSpeed)))
        upgrades.addArrangedSubview(button("🎒 Рюкзак", .systemIndigo, #selector(upgradeBag)))
        add(upgrades)
        let active = shieldUntil > Int(Date().timeIntervalSince1970)
        let shieldText = active ? "Щит активен до \(Self.dateString(shieldUntil))" : "Щит защищает от набегов в течение 24 часов."
        add(cardContent("🛡 Щит защиты", views: [
            label(shieldText, 14),
            button(active ? "Щит активен" : "Активировать щит", .systemTeal, #selector(buyShield), enabled: !active)
        ]))
        add(cardContent("🎯 Набег на игрока", views: [
            field("@username или +888", .default, id: "raidTarget"),
            button("🐭 Отправить мышку на набег", .systemOrange, #selector(sendRaid)),
            label("Откат набега: 24 часа", 12, .medium, .secondaryLabel)
        ]))
        send("inventory") { _ in }
    }

    @objc private func upgradeSpeed() { upgradeMouse("speed") }
    @objc private func upgradeBag() { upgradeMouse("bag") }

    private func upgradeMouse(_ stat: String) {
        run("game/mouse-upgrade", body: ["stat": stat]) { j in
            self.stars = self.getInt(j, "stars", self.stars)
            self.speedLevel = self.getInt(j, "speed_lvl", self.speedLevel)
            self.bagLevel = self.getInt(j, "bag_lvl", self.bagLevel)
            self.nextMouseCost = self.getInt(j, "next_cost", self.nextMouseCost)
            self.showMouse()
            self.status("Уровень питомца повышен")
        }
    }

    @objc private func buyShield() {
        run("game/buy-shield") { j in
            self.stars = self.getInt(j, "stars", self.stars)
            self.shieldUntil = self.getInt(j, "shield_until")
            self.showMouse()
            self.status("Щит активирован на 24 часа")
        }
    }

    @objc private func sendRaid() {
        guard let target = findField("raidTarget")?.text?.trimmingCharacters(in: .whitespacesAndNewlines), !target.isEmpty else {
            status("Укажи @username или +888", error: true); return
        }
        view.endEditing(true)
        run("game/raid", body: ["target": target]) { j in
            self.stars = self.getInt(j, "stars", self.stars)
            let outcome = j["outcome"] as? String ?? ""
            let stolen = self.getInt(j, "stolen")
            let message = j["message"] as? String ?? ""
            let title: String
            switch outcome {
            case "success": title = "Успешная кража: \(stolen) ⭐️"; self.setNewBadge()
            case "mousetrap": title = "Мышка попала в мышеловку. Добычи нет."
            case "shield": title = "Щит цели отбил набег."
            default: title = message.isEmpty ? "Набег завершён" : message
            }
            self.showMouse()
            self.status(message.isEmpty ? title : message)
        }
    }

    // MARK: Quests

    private func showQuests() {
        clear()
        configureSegments(["Тапалка", "Мышка", "Квесты"], selected: 2)
        add(label("🎯 Ежедневные квесты", 19, .bold))
        add(label("Выполняй задания и забирай награды в звёздах.", 13, .regular, .secondaryLabel))
        add(button("Обновить задания", .secondaryLabel, #selector(reloadQuests)))
        renderQuests()
        send("games/quests") { result in
            self.quests = (result["quests"] as? [[String: Any]] ?? []).map(Quest.init)
            self.renderQuests()
            if self.quests.contains(where: { $0.completed && !$0.claimed }) { self.setNewBadge() }
        }
    }

    private func renderQuests() {
        stack.arrangedSubviews.filter { $0.accessibilityIdentifier == "questRow" }.forEach {
            stack.removeArrangedSubview($0); $0.removeFromSuperview()
        }
        for quest in quests {
            let action = button(quest.claimed ? "Получено" : (quest.completed ? "Забрать награду" : "Выполняется"),
                                quest.completed && !quest.claimed ? .systemGreen : .secondaryLabel,
                                #selector(claimQuest(_:)), enabled: quest.completed && !quest.claimed)
            action.accessibilityIdentifier = quest.id
            let row = cardContent(quest.title, views: [label("Награда: \(quest.reward) ⭐️", 13, .medium, .secondaryLabel), action])
            row.accessibilityIdentifier = "questRow"
            add(row)
        }
    }

    @objc private func reloadQuests() { showQuests() }

    @objc private func claimQuest(_ sender: UIButton) {
        guard let id = sender.accessibilityIdentifier else { return }
        run("games/claim-quest", body: ["quest_id": id]) { j in
            self.stars = self.getInt(j, "stars", self.stars)
            if let i = self.quests.firstIndex(where: { $0.id == id }) { self.quests[i].claimed = true }
            self.showQuests()
            self.status("Награда получена!")
        }
    }

    // MARK: Cases

    private func showCases() {
        clear()
        configureSegments(["Кейсы", "Игры", "Магазин рамок", "Инвентарь"], selected: 0)
        add(cardContent("🔥 Последние дропы игроков", views: [
            label("⭐️ Rare   💎 Epic   🎁 Legendary   ·   Лента обновляется по мере открытия кейсов", 13, .medium, .secondaryLabel)
        ]))
        let cur = UISegmentedControl(items: ["Звёзды ⭐️", "VIP TON 💎"])
        cur.selectedSegmentIndex = currency == "stars" ? 0 : 1
        cur.addTarget(self, action: #selector(changeCurrency(_:)), for: .valueChanged)
        add(cur)
        let mult = UISegmentedControl(items: ["x1", "x2", "x3", "x4", "x5"])
        mult.selectedSegmentIndex = multiplier - 1
        mult.addTarget(self, action: #selector(changeMultiplier(_:)), for: .valueChanged)
        add(mult)
        add(button("⚔️ Батл кейсов", .systemPurple, #selector(battleCases)))
        add(label("Выбери кейс", 18, .bold))
        let catalog: [(String,String,String,String)] = [
            ("starter","Стартовый","🎁","50 ⭐️"), ("premium","Премиум","💎","250 ⭐️"),
            ("gold","Золотой","👑","1 TON"), ("legendary","Легендарный","🔥","3 TON"),
            ("vip","VIP","🌟","5 TON"), ("mystery","Мистический","🪄","750 ⭐️")
        ]
        for c in catalog {
            let b = button("\(c.2)  \(c.1) · \(c.3)", selectedCase == c.0 ? .systemIndigo : .secondaryLabel, #selector(selectCase(_:)))
            b.accessibilityIdentifier = c.0
            add(b)
        }
        add(button("🎰 Открыть кейс x\(multiplier)", .systemOrange, #selector(openCase)))
    }

    @objc private func changeCurrency(_ sender: UISegmentedControl) { currency = sender.selectedSegmentIndex == 0 ? "stars" : "ton" }
    @objc private func changeMultiplier(_ sender: UISegmentedControl) { multiplier = sender.selectedSegmentIndex + 1 }
    @objc private func selectCase(_ sender: UIButton) {
        guard let id = sender.accessibilityIdentifier else { return }
        selectedCase = id
        showCases()
    }
    @objc private func battleCases() { openCaseRequest(battle: true) }
    @objc private func openCase() { openCaseRequest(battle: false) }

    private func openCaseRequest(battle: Bool) {
        feedback(.medium)
        run("games/open-case", body: ["case_id": selectedCase, "multiplier": multiplier, "battle": battle]) { j in
            self.stars = self.getInt(j, "stars", self.stars)
            self.ton = self.getDouble(j, "ton", self.ton)
            let drops = (j["drops"] as? [[String: Any]] ?? []).map(Gift.init)
            self.items.append(contentsOf: drops)
            self.presentDrops(drops, title: battle ? "⚔️ Результат батла" : "🎉 Твой выигрыш")
        }
    }

    private func presentDrops(_ drops: [Gift], title: String) {
        let message = drops.isEmpty ? "Сервер не вернул предметы." : drops.map { "\($0.symbol) \($0.name)\nРедкость: \($0.rarity)" }.joined(separator: "\n\n")
        let a = UIAlertController(title: title, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "В инвентарь", style: .default) { _ in self.loadInventory(); self.showInventory() })
        a.addAction(UIAlertAction(title: "Продать за ⭐️", style: .default) { _ in if let item = drops.first { self.sell(item) } })
        a.addAction(UIAlertAction(title: "Улучшить", style: .default) { _ in
            if let item = drops.first { self.selectedSource = item; self.gameMode = 1; self.showGames() }
        })
        a.addAction(UIAlertAction(title: "Закрыть", style: .cancel))
        present(a, animated: true)
    }

    // MARK: Games

    private func showGames() {
        clear()
        configureSegments(["Кейсы", "Игры", "Магазин рамок", "Инвентарь"], selected: 1)
        let mode = UISegmentedControl(items: ["🚀 Краш / Ракета", "🎡 Апгрейдер NFT"])
        mode.selectedSegmentIndex = gameMode
        mode.addTarget(self, action: #selector(changeGameMode(_:)), for: .valueChanged)
        add(mode)
        if gameMode == 0 {
            add(cardContent("🚀 Краш / Ракета", views: [
                label("Результат раунда и выплата определяются сервером.", 13, .regular, .secondaryLabel),
                field("Ставка", .decimalPad, id: "crashBet"),
                field("Целевой множитель, например 2.0", .decimalPad, id: "crashTarget"),
                currencyControl(),
                button("Старт / Забрать результат", .systemOrange, #selector(startCrash))
            ]))
        } else {
            let source = selectedSource ?? items.first
            let target = selectedTarget ?? nftTargets[0]
            add(cardContent("🎡 Апгрейдер NFT", views: [
                label("Источник: \(source?.symbol ?? "🎁") \(source?.name ?? "выбери предмет")", 14, .semibold),
                button("Выбрать подарок из инвентаря", .secondaryLabel, #selector(chooseSource)),
                label("Цель: \(target.symbol) \(target.name)", 14, .semibold),
                button("Выбрать редкий NFT", .systemIndigo, #selector(chooseTarget)),
                label("◉", 84, .light, .systemPurple),
                button("🎡 Крутить", .systemPurple, #selector(runUpgrade))
            ]))
        }
    }

    private func currencyControl() -> UISegmentedControl {
        let c = UISegmentedControl(items: ["⭐️ Звёзды", "💎 TON"])
        c.selectedSegmentIndex = currency == "stars" ? 0 : 1
        c.addTarget(self, action: #selector(gameCurrencyChanged(_:)), for: .valueChanged)
        return c
    }

    @objc private func changeGameMode(_ sender: UISegmentedControl) { gameMode = sender.selectedSegmentIndex; showGames() }
    @objc private func gameCurrencyChanged(_ sender: UISegmentedControl) { currency = sender.selectedSegmentIndex == 0 ? "stars" : "ton" }

    @objc private func startCrash() {
        guard let b = findField("crashBet")?.text?.replacingOccurrences(of: ",", with: ".").flatMap(Double.init), b > 0,
              let t = findField("crashTarget")?.text?.replacingOccurrences(of: ",", with: ".").flatMap(Double.init), t >= 1.01 else {
            status("Введи корректную ставку и множитель", error: true); return
        }
        feedback(.medium)
        run("games/crash", body: ["bet": b, "currency": currency, "target_mult": t]) { j in
            self.stars = self.getInt(j, "stars", self.stars)
            self.ton = self.getDouble(j, "ton", self.ton)
            let won = j["won"] as? Bool ?? false
            let crash = self.getDouble(j, "crash_at")
            let payout = self.getDouble(j, "payout")
            let a = UIAlertController(title: won ? "🚀 Победа!" : "💥 Краш", message: String(format: "Множитель: x%.2f\nВыплата: %.3f", crash, payout), preferredStyle: .alert)
            a.addAction(UIAlertAction(title: "Продолжить", style: .default) { _ in self.showGames() })
            self.present(a, animated: true)
        }
    }

    @objc private func chooseSource() {
        if items.isEmpty { loadInventory(); status("Инвентарь пуст или ещё загружается"); return }
        let a = UIAlertController(title: "Выбери подарок", message: nil, preferredStyle: .actionSheet)
        items.forEach { gift in a.addAction(UIAlertAction(title: "\(gift.symbol) \(gift.name)", style: .default) { _ in self.selectedSource = gift; self.showGames() }) }
        a.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        present(a, animated: true)
    }

    @objc private func chooseTarget() {
        let a = UIAlertController(title: "Целевой NFT", message: nil, preferredStyle: .actionSheet)
        nftTargets.forEach { gift in a.addAction(UIAlertAction(title: "\(gift.symbol) \(gift.name)", style: .default) { _ in self.selectedTarget = gift; self.showGames() }) }
        a.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        present(a, animated: true)
    }

    @objc private func runUpgrade() {
        guard let source = selectedSource ?? items.first else { status("Нет подарка в инвентаре", error: true); return }
        let target = selectedTarget ?? nftTargets[0]
        feedback(.medium)
        run("games/upgrade", body: ["source_item_id": source.id, "target_item_id": target.id]) { j in
            let won = j["won"] as? Bool ?? false
            if won, let dict = j["new_item"] as? [String: Any] { self.presentDrops([Gift(dict)], title: "🎉 Апгрейд успешен") }
            else { self.status("Попытка не удалась") }
            self.loadInventory()
        }
    }

    // MARK: Frame shop

    private func showFrameShop() {
        clear()
        configureSegments(["Кейсы", "Игры", "Магазин рамок", "Инвентарь"], selected: 2)
        add(label("✨ Эксклюзивные рамки аватара", 19, .bold))
        add(label("Выбери расцветку и купи рамку за TON.", 13, .regular, .secondaryLabel))
        let colors = UISegmentedControl(items: ["Фиолетовый", "Синий", "Розовый", "Золотой"])
        colors.addTarget(self, action: #selector(changeFrameColor(_:)), for: .valueChanged)
        add(colors)
        let frames: [(String,String,String)] = [
            ("wings","Wings","🪽"), ("blue_flame","Blue Flame","🔥"), ("cat_bed","Cat Bed","🐈"),
            ("roses","Roses","🌹"), ("bones","Bones","🦴"), ("tendrils","Tendrils","🌿"), ("scythe","Scythe","⚔️")
        ]
        for f in frames {
            let b = button("\(f.2)  \(f.1) · Купить за TON", .systemPurple, #selector(buyFrame(_:)))
            b.accessibilityIdentifier = f.0
            add(b)
        }
    }

    @objc private func changeFrameColor(_ sender: UISegmentedControl) {
        frameColor = ["#7C5CFF", "#168BFF", "#FF65B8", "#E5A900"][max(0, sender.selectedSegmentIndex)]
    }

    @objc private func buyFrame(_ sender: UIButton) {
        guard let id = sender.accessibilityIdentifier else { return }
        run("shop/buy-frame", body: ["frame_id": id, "color_hex": frameColor]) { j in
            self.ton = self.getDouble(j, "ton", self.ton)
            self.status("Рамка приобретена!")
        }
    }

    // MARK: Inventory

    private func loadInventory() {
        send("inventory") { j in
            self.items = (j["items"] as? [[String: Any]] ?? []).map(Gift.init)
            if !self.items.isEmpty { self.setNewBadge() }
            if self.tabKind == "Кейсы" && self.section == 3 { self.renderInventory() }
        }
    }

    private func showInventory() {
        clear()
        configureSegments(["Кейсы", "Игры", "Магазин рамок", "Инвентарь"], selected: 3)
        add(label("🎒 Инвентарь подарков", 19, .bold))
        add(button("Обновить", .secondaryLabel, #selector(refreshInventory)))
        renderInventory()
        loadInventory()
    }

    @objc private func refreshInventory() { loadInventory() }

    private func renderInventory() {
        stack.arrangedSubviews.filter { $0.accessibilityIdentifier == "inventoryRow" }.forEach {
            stack.removeArrangedSubview($0); $0.removeFromSuperview()
        }
        if items.isEmpty {
            let empty = cardContent("Пока пусто", views: [label("Открой кейс, чтобы получить первый подарок.", 13, .regular, .secondaryLabel)])
            empty.accessibilityIdentifier = "inventoryRow"
            add(empty)
            return
        }
        for item in items {
            let row = cardContent("\(item.symbol) \(item.name)", views: [
                label("Редкость: \(item.rarity) · \(item.price) ⭐️", 12, .regular, .secondaryLabel),
                button("Вывести в профиль", .systemBlue, #selector(withdrawItem(_:)), enabled: true).tagged(item.id, selector: #selector(withdrawItem(_:))),
                button("Улучшить в NFT", .systemPurple, #selector(upgradeItem(_:))).tagged(item.id, selector: #selector(upgradeItem(_:))),
                button("Продать", .systemGreen, #selector(sellItem(_:))).tagged(item.id, selector: #selector(sellItem(_:)))
            ])
            row.accessibilityIdentifier = "inventoryRow"
            add(row)
        }
    }

    @objc private func withdrawItem(_ sender: UIButton) {
        guard let id = sender.accessibilityIdentifier else { return }
        run("inventory/withdraw", body: ["item_id": id]) { _ in
            self.items.removeAll { $0.id == id }
            self.renderInventory()
            self.status("Предмет выведен в профиль")
        }
    }

    @objc private func upgradeItem(_ sender: UIButton) {
        guard let id = sender.accessibilityIdentifier else { return }
        run("inventory/upgrade", body: ["item_id": id]) { j in
            let number = self.getInt(j, "nft_number")
            self.stars = self.getInt(j, "stars", self.stars)
            self.items.removeAll { $0.id == id }
            self.renderInventory()
            self.status("Улучшено в NFT №\(number)")
        }
    }

    @objc private func sellItem(_ sender: UIButton) {
        guard let id = sender.accessibilityIdentifier, let item = items.first(where: { $0.id == id }) else { return }
        sell(item)
    }

    private func sell(_ item: Gift) {
        run("inventory/sell", body: ["item_id": item.id]) { j in
            self.stars = self.getInt(j, "stars", self.stars)
            self.items.removeAll { $0.id == item.id }
            self.renderInventory()
            self.status("Продано за \(self.getInt(j, "stars")) ⭐️")
        }
    }
}

private enum APIError: LocalizedError {
    case http(Int)
    static let badResponse = APIError.http(-2)
    var errorDescription: String? {
        switch self {
        case .http(let code): return code == -2 ? "Некорректный ответ сервера" : "HTTP \(code)"
        }
    }
}

private struct Quest {
    let id: String
    let title: String
    let reward: Int
    let completed: Bool
    var claimed: Bool
    init(_ j: [String: Any]) {
        id = j["id"] as? String ?? UUID().uuidString
        title = j["title"] as? String ?? "Задание"
        reward = (j["reward_stars"] as? NSNumber)?.intValue ?? 0
        completed = j["completed"] as? Bool ?? false
        claimed = j["claimed"] as? Bool ?? false
    }
}

private struct Gift {
    let id: String
    let name: String
    let rarity: String
    let price: Int
    let symbol: String
    init(_ j: [String: Any]) {
        id = j["item_id"] as? String ?? UUID().uuidString
        name = j["name"] as? String ?? "Подарок"
        rarity = j["rarity"] as? String ?? "Common"
        price = (j["price_stars"] as? NSNumber)?.intValue ?? 0
        symbol = j["symbol"] as? String ?? "🎁"
    }
}

private let nftTargets: [Gift] = [
    Gift(["item_id":"rare_nft", "name":"Rare NFT", "rarity":"Rare", "symbol":"💎"]),
    Gift(["item_id":"epic_nft", "name":"Epic NFT", "rarity":"Epic", "symbol":"🟣"]),
    Gift(["item_id":"legendary_nft", "name":"Legendary NFT", "rarity":"Legendary", "symbol":"👑"])
]

private extension UIButton {
    @discardableResult
    func tagged(_ id: String, selector: Selector) -> UIButton {
        accessibilityIdentifier = id
        return self
    }
}
