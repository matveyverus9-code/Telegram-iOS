import Foundation
import UIKit
import AVFoundation
import Display
import AsyncDisplayKit
import TelegramPresentationData

// MARK: - Shared helpers

private enum LuxuryUI {
    static let blue = UIColor(red: 0.12, green: 0.48, blue: 0.96, alpha: 1.0)
    static let cardRadius: CGFloat = 22.0

    static func color(hex: String, fallback: UIColor = .systemBlue) -> UIColor {
        var value = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if value.count == 8 {
            value = String(value.suffix(6))
        }
        guard value.count == 6, let number = UInt64(value, radix: 16) else {
            return fallback
        }
        return UIColor(
            red: CGFloat((number >> 16) & 0xff) / 255.0,
            green: CGFloat((number >> 8) & 0xff) / 255.0,
            blue: CGFloat(number & 0xff) / 255.0,
            alpha: 1.0
        )
    }

    static func label(_ text: String, size: CGFloat = 14, weight: UIFont.Weight = .regular, color: UIColor = .label) -> UILabel {
        let result = UILabel()
        result.text = text
        result.font = UIFont.systemFont(ofSize: size, weight: weight)
        result.textColor = color
        result.numberOfLines = 0
        return result
    }

    static func button(_ title: String, color: UIColor = LuxuryUI.blue) -> UIButton {
        let result = UIButton(type: .system)
        result.setTitle(title, for: .normal)
        result.setTitleColor(.white, for: .normal)
        result.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        result.backgroundColor = color
        result.layer.cornerRadius = 14
        result.contentEdgeInsets = UIEdgeInsets(top: 13, left: 16, bottom: 13, right: 16)
        result.clipsToBounds = true
        return result
    }

    static func card(background: UIColor = .secondarySystemBackground) -> UIView {
        let view = UIView()
        view.backgroundColor = background
        view.layer.cornerRadius = cardRadius
        view.layer.cornerCurve = .continuous
        return view
    }

    static func feedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
}

private enum LuxuryAPI {
    static let baseURL = URL(string: "https://tg-api.matveyverus9.workers.dev")!

    static func request(path: String, method: String = "POST", userId: Int, body: [String: Any] = [:], completion: @escaping (Result<[String: Any], Error>) -> Void) {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        if method == "GET" {
            components?.queryItems = [URLQueryItem(name: "user_id", value: String(userId))]
        }
        guard let url = components?.url else {
            completion(.failure(NSError(domain: "LuxuryAPI", code: -1)))
            return
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.timeoutInterval = 20
        if method != "GET" {
            var payload = body
            payload["user_id"] = userId
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            do {
                urlRequest.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
            } catch {
                completion(.failure(error))
                return
            }
        }
        URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode), let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "LuxuryAPI", code: (response as? HTTPURLResponse)?.statusCode ?? -2)))
                }
                return
            }
            do {
                let object = try JSONSerialization.jsonObject(with: data, options: [])
                guard let dictionary = object as? [String: Any] else {
                    throw NSError(domain: "LuxuryAPI", code: -3)
                }
                DispatchQueue.main.async { completion(.success(dictionary)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }.resume()
    }
}

// MARK: - Luxury style renderer

public final class LuxuryStyleHelper {
    private init() {}

    public static func applyNameStyle(to label: UILabel, name: String, style: String, fontStyle: String) {
        label.text = name
        label.layer.removeAnimation(forKey: "luxuryNameGradient")
        label.layer.sublayers?.filter { $0.name == "luxury-name-gradient" }.forEach { $0.removeFromSuperlayer() }
        label.layer.shadowOpacity = 0
        label.layer.shadowRadius = 0
        label.layer.shadowColor = nil
        label.textColor = .label

        switch fontStyle.lowercased() {
        case "pixel", "minecraft", "mono", "monospace":
            label.font = UIFont(name: "Menlo-Bold", size: label.font.pointSize) ?? UIFont.monospacedSystemFont(ofSize: label.font.pointSize, weight: .bold)
        case "rounded":
            label.font = UIFont.systemFont(ofSize: label.font.pointSize, weight: .bold).withDesign(.rounded) ?? label.font
        case "serif":
            label.font = UIFont(name: "Georgia-Bold", size: label.font.pointSize) ?? label.font
        default:
            label.font = UIFont.systemFont(ofSize: label.font.pointSize, weight: .semibold)
        }

        switch style.lowercased() {
        case "neon", "glow", "neon_glow":
            label.textColor = UIColor(red: 0.55, green: 0.88, blue: 1.0, alpha: 1)
            let shadow = NSShadow()
            shadow.shadowColor = UIColor.cyan
            shadow.shadowBlurRadius = 12
            label.attributedText = NSAttributedString(string: name, attributes: [
                .font: label.font as Any,
                .foregroundColor: label.textColor as Any,
                .shadow: shadow
            ])
            label.layer.shadowColor = UIColor.cyan.cgColor
            label.layer.shadowRadius = 8
            label.layer.shadowOpacity = 0.8
        case "gradient", "animated", "rainbow":
            label.textColor = .clear
            let gradient = CAGradientLayer()
            gradient.name = "luxury-name-gradient"
            gradient.colors = [
                UIColor.systemPink.cgColor,
                UIColor.systemPurple.cgColor,
                UIColor.systemBlue.cgColor,
                UIColor.systemTeal.cgColor,
                UIColor.systemPink.cgColor
            ]
            gradient.startPoint = CGPoint(x: 0, y: 0.5)
            gradient.endPoint = CGPoint(x: 1, y: 0.5)
            gradient.locations = [0, 0.25, 0.5, 0.75, 1]
            gradient.frame = label.bounds
            gradient.mask = textMask(for: label, name: name)
            label.layer.addSublayer(gradient)
            let animation = CABasicAnimation(keyPath: "locations")
            animation.fromValue = [-0.5, -0.25, 0, 0.25, 0.5]
            animation.toValue = [0.5, 0.75, 1, 1.25, 1.5]
            animation.duration = 3.2
            animation.repeatCount = .infinity
            gradient.add(animation, forKey: "luxuryNameGradient")
        default:
            label.textColor = .label
            label.attributedText = NSAttributedString(string: name, attributes: [.font: label.font as Any, .foregroundColor: UIColor.label])
        }
        label.setNeedsLayout()
    }

    private static func textMask(for label: UILabel, name: String) -> CATextLayer {
        let mask = CATextLayer()
        mask.string = name
        mask.contentsScale = UIScreen.main.scale
        mask.alignmentMode = .left
        mask.truncationMode = .end
        mask.font = label.font
        mask.fontSize = label.font.pointSize
        mask.frame = label.bounds
        return mask
    }

    public static func buildBadgesStack(leftBadges: [String], isVerified: Bool) -> UIStackView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .fill
        stack.spacing = 4
        stack.setContentCompressionResistancePriority(.required, for: .horizontal)

        for badge in leftBadges {
            let normalized = badge.lowercased()
            guard normalized == "hold" || normalized == "major" else { continue }
            let item = UILabel()
            item.text = normalized == "hold" ? "HOLD" : "MAJOR"
            item.font = UIFont.systemFont(ofSize: 9, weight: .heavy)
            item.textColor = .white
            item.textAlignment = .center
            item.backgroundColor = normalized == "hold" ? UIColor.systemOrange : UIColor.systemPurple
            item.layer.cornerRadius = 5
            item.clipsToBounds = true
            item.translatesAutoresizingMaskIntoConstraints = false
            item.widthAnchor.constraint(greaterThanOrEqualToConstant: 31).isActive = true
            item.heightAnchor.constraint(equalToConstant: 17).isActive = true
            item.layoutMargins = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: 5)
            stack.addArrangedSubview(item)
        }

        if isVerified {
            let check = UILabel()
            check.text = "✓"
            check.font = UIFont.systemFont(ofSize: 12, weight: .heavy)
            check.textColor = .white
            check.textAlignment = .center
            check.backgroundColor = LuxuryUI.blue
            check.layer.cornerRadius = 8
            check.clipsToBounds = true
            check.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                check.widthAnchor.constraint(equalToConstant: 16),
                check.heightAnchor.constraint(equalToConstant: 16)
            ])
            stack.addArrangedSubview(check)
        }
        return stack
    }

    public static func applyAvatarFrame(to containerView: UIView, frameId: String, colorHex: String) {
        containerView.layer.sublayers?.filter { $0.name == "luxury-avatar-frame" }.forEach { $0.removeFromSuperlayer() }
        let color = LuxuryUI.color(hex: colorHex)
        let ring = CAShapeLayer()
        ring.name = "luxury-avatar-frame"
        ring.fillColor = UIColor.clear.cgColor
        ring.strokeColor = color.cgColor
        ring.lineWidth = frameId == "prestige_fire" ? 5 : 3
        ring.frame = containerView.bounds
        let inset: CGFloat = frameId == "cat_bed" ? 3 : 1.5
        ring.path = UIBezierPath(ovalIn: containerView.bounds.insetBy(dx: inset, dy: inset)).cgPath
        ring.shadowColor = color.cgColor
        ring.shadowRadius = 7
        ring.shadowOpacity = 0.8
        ring.shadowOffset = .zero
        containerView.layer.addSublayer(ring)

        let ornament: String
        switch frameId {
        case "wings": ornament = "🪽"
        case "blue_flame": ornament = "🔥"
        case "cat_bed": ornament = "🐱"
        case "roses": ornament = "🌹"
        case "bones": ornament = "🦴"
        case "tendrils": ornament = "〰️"
        case "scythe": ornament = "☠️"
        case "prestige_fire": ornament = "🔥"
        default: ornament = ""
        }
        if !ornament.isEmpty {
            let text = CATextLayer()
            text.name = "luxury-avatar-frame-ornament"
            text.string = ornament
            text.fontSize = max(13, containerView.bounds.width * 0.22)
            text.alignmentMode = .center
            text.contentsScale = UIScreen.main.scale
            text.frame = CGRect(x: 0, y: -containerView.bounds.height * 0.16, width: containerView.bounds.width, height: 24)
            containerView.layer.addSublayer(text)
        }
        let pulse = CABasicAnimation(keyPath: "shadowRadius")
        pulse.fromValue = 3
        pulse.toValue = 10
        pulse.duration = 1.4
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        ring.add(pulse, forKey: "luxuryFramePulse")
    }
}

// MARK: - Profile header

public final class LuxuryProfileHeaderView: UIView {
    public var onFriendTap: ((Int) -> Void)?
    public var onTONBalanceTap: (() -> Void)?
    public var onRaidResult: ((String) -> Void)?

    private let userId: Int
    private let profileUserId: Int
    private let isOwnProfile: Bool
    private let theme: PresentationTheme
    private let bannerHost = UIView()
    private let avatarView = UIImageView()
    private let nameLabel = UILabel()
    private let levelLabel = UILabel()
    private let clanLabel = UILabel()
    private let balanceButton = UIButton(type: .system)
    private let badgesLabel = UILabel()
    private let signatureLabel = UILabel()
    private let leftFriend = UIButton(type: .custom)
    private let rightFriend = UIButton(type: .custom)
    private let raidButton = UIButton(type: .system)
    private var queuePlayer: AVQueuePlayer?
    private var playerLooper: AVPlayerLooper?
    private var gifts: [(symbol: String, x: CGFloat, y: CGFloat)] = []
    private var friendIds: [Int] = []

    public init(
        theme: PresentationTheme,
        userId: Int,
        profileUserId: Int,
        name: String,
        avatar: UIImage? = nil,
        bannerVideoURL: URL? = nil,
        avatarFrameId: String = "",
        avatarFrameColor: String = "#4C9AFF",
        level: Int = 1,
        shieldColorHex: String = "#4C9AFF",
        clan: String = "",
        tonBalance: Double = 0,
        badges: [String] = [],
        isVerified: Bool = false,
        signature: String = "",
        friendIds: [Int] = [],
        giftOverlays: [(symbol: String, x: CGFloat, y: CGFloat)] = []
    ) {
        self.theme = theme
        self.userId = userId
        self.profileUserId = profileUserId
        self.isOwnProfile = userId == profileUserId
        self.friendIds = Array(friendIds.prefix(2))
        self.gifts = giftOverlays
        super.init(frame: .zero)
        backgroundColor = theme.list.blocksBackgroundColor
        configure(name: name, avatar: avatar, videoURL: bannerVideoURL, frameId: avatarFrameId, frameColor: avatarFrameColor, level: level, shieldColor: shieldColorHex, clan: clan, balance: tonBalance, badges: badges, verified: isVerified, signature: signature)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    private func configure(name: String, avatar: UIImage?, videoURL: URL?, frameId: String, frameColor: String, level: Int, shieldColor: String, clan: String, balance: Double, badges: [String], verified: Bool, signature: String) {
        bannerHost.translatesAutoresizingMaskIntoConstraints = false
        bannerHost.backgroundColor = UIColor.secondarySystemBackground
        bannerHost.layer.cornerRadius = 24
        bannerHost.clipsToBounds = true
        addSubview(bannerHost)

        if let url = videoURL {
            let item = AVPlayerItem(url: url)
            let player = AVQueuePlayer()
            player.isMuted = true
            playerLooper = AVPlayerLooper(player: player, templateItem: item)
            let playerLayer = AVPlayerLayer(player: player)
            playerLayer.videoGravity = .resizeAspectFill
            playerLayer.frame = bounds
            bannerHost.layer.addSublayer(playerLayer)
            queuePlayer = player
            player.play()
        } else {
            let gradient = CAGradientLayer()
            gradient.colors = [UIColor.systemIndigo.cgColor, UIColor.systemBlue.cgColor, UIColor.systemTeal.cgColor]
            gradient.startPoint = CGPoint(x: 0, y: 0)
            gradient.endPoint = CGPoint(x: 1, y: 1)
            bannerHost.layer.insertSublayer(gradient, at: 0)
            gradient.frame = CGRect(x: 0, y: 0, width: 360, height: 170)
        }

        avatarView.translatesAutoresizingMaskIntoConstraints = false
        avatarView.image = avatar ?? UIImage(systemName: "person.crop.circle.fill")
        avatarView.tintColor = .secondaryLabel
        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = 43
        bannerHost.addSubview(avatarView)

        nameLabel.font = UIFont.systemFont(ofSize: 21, weight: .bold)
        LuxuryStyleHelper.applyNameStyle(to: nameLabel, name: name, style: "normal", fontStyle: "system")
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(nameLabel)

        levelLabel.text = "УРОВЕНЬ \(level)"
        levelLabel.font = UIFont.systemFont(ofSize: 11, weight: .heavy)
        levelLabel.textColor = .white
        levelLabel.backgroundColor = LuxuryUI.color(hex: shieldColor)
        levelLabel.textAlignment = .center
        levelLabel.layer.cornerRadius = 9
        levelLabel.clipsToBounds = true
        levelLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(levelLabel)

        clanLabel.text = clan.isEmpty ? "Без клана" : "⚑ \(clan)"
        clanLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        clanLabel.textColor = .secondaryLabel
        clanLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(clanLabel)

        balanceButton.setTitle(String(format: "◈ %.3f TON", balance), for: .normal)
        balanceButton.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        balanceButton.setTitleColor(LuxuryUI.blue, for: .normal)
        balanceButton.backgroundColor = UIColor.tertiarySystemBackground
        balanceButton.layer.cornerRadius = 12
        balanceButton.addTarget(self, action: #selector(balancePressed), for: .touchUpInside)
        balanceButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(balanceButton)

        let badgeStack = LuxuryStyleHelper.buildBadgesStack(leftBadges: badges, isVerified: verified)
        badgeStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(badgeStack)
        badgesLabel.text = "Значки"
        badgesLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        badgesLabel.textColor = .secondaryLabel
        badgesLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(badgesLabel)

        signatureLabel.text = signature
        signatureLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        signatureLabel.textColor = .secondaryLabel
        signatureLabel.textAlignment = .center
        signatureLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(signatureLabel)

        raidButton.setTitle("🐭 Отправить мышку на набег", for: .normal)
        raidButton.setTitleColor(.white, for: .normal)
        raidButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        raidButton.backgroundColor = UIColor.systemPink
        raidButton.layer.cornerRadius = 13
        raidButton.addTarget(self, action: #selector(raidPressed), for: .touchUpInside)
        raidButton.translatesAutoresizingMaskIntoConstraints = false
        raidButton.isHidden = isOwnProfile
        addSubview(raidButton)

        leftFriend.translatesAutoresizingMaskIntoConstraints = false
        rightFriend.translatesAutoresizingMaskIntoConstraints = false
        for friend in [leftFriend, rightFriend] {
            friend.backgroundColor = .tertiarySystemBackground
            friend.layer.cornerRadius = 22
            friend.layer.borderWidth = 2
            friend.layer.borderColor = UIColor.systemOrange.cgColor
            friend.setTitle("🔥", for: .normal)
            friend.titleLabel?.font = UIFont.systemFont(ofSize: 20)
            friend.alpha = 0
            bannerHost.addSubview(friend)
        }
        leftFriend.addTarget(self, action: #selector(leftFriendPressed), for: .touchUpInside)
        rightFriend.addTarget(self, action: #selector(rightFriendPressed), for: .touchUpInside)

        NSLayoutConstraint.activate([
            bannerHost.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            bannerHost.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            bannerHost.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            bannerHost.heightAnchor.constraint(equalToConstant: 174),
            avatarView.centerXAnchor.constraint(equalTo: bannerHost.centerXAnchor),
            avatarView.centerYAnchor.constraint(equalTo: bannerHost.centerYAnchor, constant: 7),
            avatarView.widthAnchor.constraint(equalToConstant: 86),
            avatarView.heightAnchor.constraint(equalToConstant: 86),
            nameLabel.topAnchor.constraint(equalTo: bannerHost.bottomAnchor, constant: 13),
            nameLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            levelLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
            levelLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            levelLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 92),
            levelLabel.heightAnchor.constraint(equalToConstant: 23),
            clanLabel.topAnchor.constraint(equalTo: levelLabel.bottomAnchor, constant: 7),
            clanLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            balanceButton.topAnchor.constraint(equalTo: clanLabel.bottomAnchor, constant: 9),
            balanceButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            badgeStack.topAnchor.constraint(equalTo: balanceButton.bottomAnchor, constant: 10),
            badgeStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            badgesLabel.topAnchor.constraint(equalTo: badgeStack.bottomAnchor, constant: 3),
            badgesLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            raidButton.topAnchor.constraint(equalTo: badgesLabel.bottomAnchor, constant: 10),
            raidButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            raidButton.heightAnchor.constraint(equalToConstant: 42),
            signatureLabel.topAnchor.constraint(equalTo: raidButton.bottomAnchor, constant: 9),
            signatureLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            signatureLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            leftFriend.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),
            leftFriend.trailingAnchor.constraint(equalTo: avatarView.leadingAnchor, constant: 7),
            leftFriend.widthAnchor.constraint(equalToConstant: 44),
            leftFriend.heightAnchor.constraint(equalToConstant: 44),
            rightFriend.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),
            rightFriend.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: -7),
            rightFriend.widthAnchor.constraint(equalToConstant: 44),
            rightFriend.heightAnchor.constraint(equalToConstant: 44)
        ])

        LuxuryStyleHelper.applyAvatarFrame(to: avatarView, frameId: frameId, colorHex: frameColor)
        for gift in gifts {
            let giftView = UILabel()
            giftView.text = gift.symbol
            giftView.font = UIFont.systemFont(ofSize: 23)
            giftView.textAlignment = .center
            giftView.translatesAutoresizingMaskIntoConstraints = false
            bannerHost.addSubview(giftView)
            NSLayoutConstraint.activate([
                giftView.centerXAnchor.constraint(equalTo: bannerHost.centerXAnchor, constant: gift.x * 170),
                giftView.centerYAnchor.constraint(equalTo: bannerHost.centerYAnchor, constant: gift.y * 82),
                giftView.widthAnchor.constraint(equalToConstant: 34),
                giftView.heightAnchor.constraint(equalToConstant: 34)
            ])
        }
        if let playerLayer = bannerHost.layer.sublayers?.compactMap({ $0 as? AVPlayerLayer }).first {
            playerLayer.frame = CGRect(x: 0, y: 0, width: 360, height: 174)
        }
        layoutIfNeeded()
        animateFriends()
    }

    private func animateFriends() {
        guard !friendIds.isEmpty else { return }
        let buttons = [leftFriend, rightFriend]
        for (index, button) in buttons.enumerated() where index < friendIds.count {
            button.transform = CGAffineTransform(translationX: index == 0 ? 24 : -24, y: 0).scaledBy(x: 0.5, y: 0.5)
            UIView.animate(withDuration: 0.58, delay: Double(index) * 0.08, usingSpringWithDamping: 0.62, initialSpringVelocity: 0.8, options: [.curveEaseOut]) {
                button.transform = .identity
                button.alpha = 1
            }
        }
    }

    @objc private func balancePressed() {
        LuxuryUI.feedback()
        onTONBalanceTap?()
    }

    @objc private func leftFriendPressed() {
        guard let id = friendIds.first else { return }
        LuxuryUI.feedback()
        onFriendTap?(id)
    }

    @objc private func rightFriendPressed() {
        guard friendIds.count > 1 else { return }
        LuxuryUI.feedback()
        onFriendTap?(friendIds[1])
    }

    @objc private func raidPressed() {
        guard !isOwnProfile else { return }
        LuxuryUI.feedback(.medium)
        raidButton.isEnabled = false
        LuxuryAPI.request(path: "game/raid", userId: userId, body: ["target": String(profileUserId)]) { [weak self] result in
            guard let self else { return }
            self.raidButton.isEnabled = true
            switch result {
            case let .success(data):
                self.onRaidResult?(data["message"] as? String ?? "Набег завершён")
            case let .failure(error):
                self.onRaidResult?(error.localizedDescription)
            }
        }
    }

    deinit {
        queuePlayer?.pause()
        playerLooper = nil
    }
}

// MARK: - Base ViewController setup

private func luxuryNavigationData(theme: PresentationTheme) -> NavigationBarPresentationData {
    return NavigationBarPresentationData(
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
}

// MARK: - Asset sheet

public final class AssetSheetController: ViewController {
    private let theme: PresentationTheme
    private let userId: Int
    private let asset: String
    private let priceTON: Double
    private let priceUSD: Double?
    private let isTransferable: Bool
    private let kind: String
    private let contentView = UIView()
    private let statusLabel = UILabel()
    private let listButton = UIButton(type: .system)

    public init(theme: PresentationTheme, userId: Int, asset: String, priceTON: Double, priceUSD: Double? = nil, kind: String = "username", isTransferable: Bool? = nil) {
        self.theme = theme
        self.userId = userId
        self.asset = asset
        self.priceTON = priceTON
        self.priceUSD = priceUSD
        self.kind = kind
        if let isTransferable {
            self.isTransferable = isTransferable
        } else {
            self.isTransferable = asset == "+888" || (asset.hasPrefix("@") && kind == "username")
        }
        super.init(navigationBarPresentationData: luxuryNavigationData(theme: theme))
        self.title = "Коллекционный актив"
    }

    required init?(coder: NSCoder) {
        return nil
    }

    public override func displayNodeDidLoad() {
        super.displayNodeDidLoad()
        displayNode.backgroundColor = theme.list.blocksBackgroundColor
        let root = displayNode.view
        root.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: root.safeAreaLayoutGuide.topAnchor, constant: 18),
            contentView.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 18),
            contentView.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -18)
        ])

        let card = LuxuryUI.card()
        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])

        let title = LuxuryUI.label(asset, size: 34, weight: .bold)
        title.textAlignment = .center
        let subtitle = LuxuryUI.label(assetSubtitle(), size: 15, weight: .medium, color: .secondaryLabel)
        subtitle.textAlignment = .center
        let price = LuxuryUI.label(priceText(), size: 22, weight: .bold, color: LuxuryUI.blue)
        price.textAlignment = .center
        statusLabel.text = isTransferable ? "Можно передать другому пользователю" : "🔒 Непередаваемый эксклюзив"
        statusLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        statusLabel.textColor = isTransferable ? .secondaryLabel : .systemOrange
        statusLabel.textAlignment = .center
        let stack = UIStackView(arrangedSubviews: [title, subtitle, price, statusLabel])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 15
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 28),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -28)
        ])

        listButton.setTitle("Выставить на маркет", for: .normal)
        listButton.setTitleColor(.white, for: .normal)
        listButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        listButton.backgroundColor = LuxuryUI.blue
        listButton.layer.cornerRadius = 15
        listButton.translatesAutoresizingMaskIntoConstraints = false
        listButton.addTarget(self, action: #selector(listOnMarket), for: .touchUpInside)
        contentView.addSubview(listButton)
        listButton.isHidden = !isTransferable
        NSLayoutConstraint.activate([
            listButton.topAnchor.constraint(equalTo: card.bottomAnchor, constant: 16),
            listButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            listButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            listButton.heightAnchor.constraint(equalToConstant: 52),
            listButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    private func assetSubtitle() -> String {
        if asset == "+777" { return "Креаторский коллекционный номер" }
        if asset == "+666" { return "Мифический номер · оценка коллекции" }
        if asset == "+888" { return "Коллекционный номер Fragment" }
        return "Коллекционный юзернейм"
    }

    private func priceText() -> String {
        if asset == "+666" {
            return "133 333 333 TON  ($666,666,666)"
        }
        if let priceUSD {
            return String(format: "%.3f TON  ($%.2f)", priceTON, priceUSD)
        }
        return String(format: "%.3f TON  (USD-оценка не задана)", priceTON)
    }

    @objc private func listOnMarket() {
        guard isTransferable else { return }
        LuxuryUI.feedback(.medium)
        listButton.isEnabled = false
        LuxuryAPI.request(path: "market/list", userId: userId, body: ["asset": asset, "kind": kind, "price_ton": priceTON]) { [weak self] result in
            guard let self else { return }
            self.listButton.isEnabled = true
            let message: String
            switch result {
            case .success:
                message = "Лот отправлен на маркет"
            case let .failure(error):
                message = "Не удалось выставить лот: \(error.localizedDescription)"
            }
            let alert = UIAlertController(title: "Маркет", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }
}

// MARK: - TON wallet, premium and admin area

public final class TonWalletAndAdminController: ViewController {
    private let theme: PresentationTheme
    private let userId: Int
    private var balance: Double
    private let cardView = UIView()
    private let balanceLabel = UILabel()
    private let visibilitySwitch = UISwitch()
    private let promoField = UITextField()
    private let historyStack = UIStackView()
    private var history: [String] = []

    public init(theme: PresentationTheme, userId: Int, balanceTON: Double = 0) {
        self.theme = theme
        self.userId = userId
        self.balance = balanceTON
        super.init(navigationBarPresentationData: luxuryNavigationData(theme: theme))
        self.title = "TON Wallet"
    }

    required init?(coder: NSCoder) {
        return nil
    }

    public override func displayNodeDidLoad() {
        super.displayNodeDidLoad()
        displayNode.backgroundColor = theme.list.blocksBackgroundColor
        let root = displayNode.view
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: root.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: root.bottomAnchor)
        ])
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -18),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24)
        ])

        configureWalletCard()
        stack.addArrangedSubview(cardView)

        let visibilityRow = UIStackView()
        visibilityRow.axis = .horizontal
        visibilityRow.alignment = .center
        let visibilityText = LuxuryUI.label("Показывать баланс в профиле", size: 14, weight: .medium)
        visibilityRow.addArrangedSubview(visibilityText)
        visibilityRow.addArrangedSubview(UIView())
        visibilityRow.addArrangedSubview(visibilitySwitch)
        let visibilityCard = LuxuryUI.card()
        visibilityCard.layoutMargins = UIEdgeInsets(top: 13, left: 16, bottom: 13, right: 16)
        visibilityRow.translatesAutoresizingMaskIntoConstraints = false
        visibilityCard.addSubview(visibilityRow)
        NSLayoutConstraint.activate([
            visibilityRow.topAnchor.constraint(equalTo: visibilityCard.topAnchor, constant: 12),
            visibilityRow.leadingAnchor.constraint(equalTo: visibilityCard.leadingAnchor, constant: 14),
            visibilityRow.trailingAnchor.constraint(equalTo: visibilityCard.trailingAnchor, constant: -14),
            visibilityRow.bottomAnchor.constraint(equalTo: visibilityCard.bottomAnchor, constant: -12)
        ])
        visibilitySwitch.isOn = UserDefaults.standard.bool(forKey: "luxury.profile.showTON")
        visibilitySwitch.addTarget(self, action: #selector(visibilityChanged), for: .valueChanged)
        stack.addArrangedSubview(visibilityCard)

        let actions = UIStackView()
        actions.axis = .horizontal
        actions.spacing = 10
        actions.distribution = .fillEqually
        let moneyButton = LuxuryUI.button("Перейти к моим Деньгам")
        let promoButton = LuxuryUI.button("Ввести промокод")
        moneyButton.titleLabel?.numberOfLines = 2
        promoButton.titleLabel?.numberOfLines = 2
        moneyButton.addTarget(self, action: #selector(openMoney), for: .touchUpInside)
        promoButton.addTarget(self, action: #selector(enterPromo), for: .touchUpInside)
        actions.addArrangedSubview(moneyButton)
        actions.addArrangedSubview(promoButton)
        stack.addArrangedSubview(actions)

        let premiumCard = LuxuryUI.card()
        let premiumTitle = LuxuryUI.label("Telegram Premium", size: 18, weight: .bold)
        let premiumDescription = LuxuryUI.label("Премиальные возможности профиля и эксклюзивные визуальные настройки.", size: 13, color: .secondaryLabel)
        let premiumButton = LuxuryUI.button("Управление Premium")
        premiumButton.addTarget(self, action: #selector(openPremium), for: .touchUpInside)
        let premiumStack = UIStackView(arrangedSubviews: [premiumTitle, premiumDescription, premiumButton])
        premiumStack.axis = .vertical
        premiumStack.spacing = 12
        premiumStack.translatesAutoresizingMaskIntoConstraints = false
        premiumCard.addSubview(premiumStack)
        NSLayoutConstraint.activate([
            premiumStack.topAnchor.constraint(equalTo: premiumCard.topAnchor, constant: 18),
            premiumStack.leadingAnchor.constraint(equalTo: premiumCard.leadingAnchor, constant: 16),
            premiumStack.trailingAnchor.constraint(equalTo: premiumCard.trailingAnchor, constant: -16),
            premiumStack.bottomAnchor.constraint(equalTo: premiumCard.bottomAnchor, constant: -18)
        ])
        stack.addArrangedSubview(premiumCard)

        let promoCard = LuxuryUI.card()
        let promoTitle = LuxuryUI.label("Активация промокода", size: 17, weight: .bold)
        promoField.placeholder = "Введите промокод"
        promoField.borderStyle = .roundedRect
        promoField.autocapitalizationType = .allCharacters
        promoField.autocorrectionType = .no
        let activate = LuxuryUI.button("Активировать")
        activate.addTarget(self, action: #selector(activatePromo), for: .touchUpInside)
        let promoStack = UIStackView(arrangedSubviews: [promoTitle, promoField, activate])
        promoStack.axis = .vertical
        promoStack.spacing = 12
        promoStack.translatesAutoresizingMaskIntoConstraints = false
        promoCard.addSubview(promoStack)
        NSLayoutConstraint.activate([
            promoStack.topAnchor.constraint(equalTo: promoCard.topAnchor, constant: 17),
            promoStack.leadingAnchor.constraint(equalTo: promoCard.leadingAnchor, constant: 16),
            promoStack.trailingAnchor.constraint(equalTo: promoCard.trailingAnchor, constant: -16),
            promoStack.bottomAnchor.constraint(equalTo: promoCard.bottomAnchor, constant: -17)
        ])
        stack.addArrangedSubview(promoCard)

        let historyCard = LuxuryUI.card()
        let historyTitle = LuxuryUI.label("История операций", size: 17, weight: .bold)
        historyStack.axis = .vertical
        historyStack.spacing = 8
        let historyContainer = UIStackView(arrangedSubviews: [historyTitle, historyStack])
        historyContainer.axis = .vertical
        historyContainer.spacing = 12
        historyContainer.translatesAutoresizingMaskIntoConstraints = false
        historyCard.addSubview(historyContainer)
        NSLayoutConstraint.activate([
            historyContainer.topAnchor.constraint(equalTo: historyCard.topAnchor, constant: 17),
            historyContainer.leadingAnchor.constraint(equalTo: historyCard.leadingAnchor, constant: 16),
            historyContainer.trailingAnchor.constraint(equalTo: historyCard.trailingAnchor, constant: -16),
            historyContainer.bottomAnchor.constraint(equalTo: historyCard.bottomAnchor, constant: -17)
        ])
        addHistory("Кошелёк открыт")
        stack.addArrangedSubview(historyCard)

        let adminCard = LuxuryUI.card(background: UIColor.black)
        let adminTitle = LuxuryUI.label("BOSS777", size: 20, weight: .black, color: .white)
        let adminSubtitle = LuxuryUI.label("Закрытая административная зона", size: 13, color: UIColor.white.withAlphaComponent(0.7))
        let adminButton = LuxuryUI.button("Войти в админку", color: UIColor(red: 0.28, green: 0.28, blue: 0.32, alpha: 1))
        adminButton.addTarget(self, action: #selector(openAdmin), for: .touchUpInside)
        let adminStack = UIStackView(arrangedSubviews: [adminTitle, adminSubtitle, adminButton])
        adminStack.axis = .vertical
        adminStack.spacing = 12
        adminStack.translatesAutoresizingMaskIntoConstraints = false
        adminCard.addSubview(adminStack)
        NSLayoutConstraint.activate([
            adminStack.topAnchor.constraint(equalTo: adminCard.topAnchor, constant: 18),
            adminStack.leadingAnchor.constraint(equalTo: adminCard.leadingAnchor, constant: 16),
            adminStack.trailingAnchor.constraint(equalTo: adminCard.trailingAnchor, constant: -16),
            adminStack.bottomAnchor.constraint(equalTo: adminCard.bottomAnchor, constant: -18)
        ])
        stack.addArrangedSubview(adminCard)
    }

    private func configureWalletCard() {
        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.layer.cornerRadius = 26
        cardView.clipsToBounds = true
        let gradient = CAGradientLayer()
        gradient.colors = [UIColor.black.cgColor, UIColor(red: 0.08, green: 0.13, blue: 0.25, alpha: 1).cgColor, UIColor(red: 0.08, green: 0.28, blue: 0.48, alpha: 1).cgColor]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        gradient.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width - 36, height: 190)
        cardView.layer.insertSublayer(gradient, at: 0)

        let caption = LuxuryUI.label("TON WALLET", size: 11, weight: .bold, color: UIColor.white.withAlphaComponent(0.7))
        let symbol = LuxuryUI.label("◈", size: 28, weight: .bold, color: .white)
        balanceLabel.text = String(format: "%.4f TON", balance)
        balanceLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 30, weight: .bold)
        balanceLabel.textColor = .white
        let cardStack = UIStackView(arrangedSubviews: [caption, symbol, balanceLabel])
        cardStack.axis = .vertical
        cardStack.spacing = 12
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(cardStack)
        NSLayoutConstraint.activate([
            cardStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 22),
            cardStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 22),
            cardStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -22),
            cardStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -22)
        ])
    }

    private func addHistory(_ value: String) {
        history.insert(value, at: 0)
        let label = LuxuryUI.label("•  \(value)", size: 13, color: .secondaryLabel)
        historyStack.insertArrangedSubview(label, at: 0)
        while historyStack.arrangedSubviews.count > 8 {
            let last = historyStack.arrangedSubviews.last!
            historyStack.removeArrangedSubview(last)
            last.removeFromSuperview()
        }
    }

    @objc private func visibilityChanged() {
        LuxuryUI.feedback()
        UserDefaults.standard.set(visibilitySwitch.isOn, forKey: "luxury.profile.showTON")
    }

    @objc private func openMoney() {
        LuxuryUI.feedback()
        let alert = UIAlertController(title: "Мои Деньги", message: "Раздел кошелька TON", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func enterPromo() {
        promoField.becomeFirstResponder()
    }

    @objc private func activatePromo() {
        let code = (promoField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else {
            showMessage("Введите промокод")
            return
        }
        LuxuryUI.feedback(.medium)
        LuxuryAPI.request(path: "promo/activate", userId: userId, body: ["promo_code": code]) { [weak self] result in
            guard let self else { return }
            switch result {
            case let .success(data):
                if let newBalance = data["ton"] as? Double {
                    self.balance = newBalance
                    self.balanceLabel.text = String(format: "%.4f TON", self.balance)
                } else if let stars = data["stars"] as? Int {
                    self.addHistory("Промокод \(code): +\(stars) ⭐")
                }
                self.addHistory("Активирован промокод \(code)")
                self.promoField.text = ""
                self.showMessage(data["message"] as? String ?? "Промокод активирован")
            case let .failure(error):
                self.addHistory("Ошибка активации промокода")
                self.showMessage("Не удалось активировать: \(error.localizedDescription)")
            }
        }
    }

    @objc private func openPremium() {
        LuxuryUI.feedback()
        showMessage("Управление Premium доступно через настройки Telegram.")
    }

    @objc private func openAdmin() {
        LuxuryUI.feedback(.heavy)
        let alert = UIAlertController(title: "BOSS777", message: "Закрытая админка. Требуется серверная авторизация администратора.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Закрыть", style: .cancel))
        present(alert, animated: true)
    }

    private func showMessage(_ message: String) {
        let alert = UIAlertController(title: "TON Wallet", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
