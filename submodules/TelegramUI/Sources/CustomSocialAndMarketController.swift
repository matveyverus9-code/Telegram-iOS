import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData

// MARK: - Shared API

private enum SocialMarketAPI {
    static let baseURL = URL(string: "https://tg-api.matveyverus9.workers.dev")!

    static func request(
        path: String,
        method: String = "GET",
        userId: Int,
        query: [String: String] = [:],
        body: [String: Any] = [:],
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )

        var queryItems = query.map {
            URLQueryItem(name: $0.key, value: $0.value)
        }

        if method == "GET" {
            queryItems.append(URLQueryItem(name: "user_id", value: String(userId)))
        }

        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }

        guard let url = components?.url else {
            DispatchQueue.main.async {
                completion(.failure(NSError(
                    domain: "SocialMarketAPI",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Некорректный URL"]
                )))
            }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 25

        if method != "GET" {
            var payload = body
            payload["user_id"] = userId

            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            do {
                request.httpBody = try JSONSerialization.data(
                    withJSONObject: payload,
                    options: []
                )
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard
                let httpResponse = response as? HTTPURLResponse,
                (200 ... 299).contains(httpResponse.statusCode),
                let data
            else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -2
                DispatchQueue.main.async {
                    completion(.failure(NSError(
                        domain: "SocialMarketAPI",
                        code: statusCode,
                        userInfo: [
                            NSLocalizedDescriptionKey: "Ошибка сервера (\(statusCode))"
                        ]
                    )))
                }
                return
            }

            do {
                let object = try JSONSerialization.jsonObject(
                    with: data,
                    options: []
                )

                guard let dictionary = object as? [String: Any] else {
                    throw NSError(
                        domain: "SocialMarketAPI",
                        code: -3,
                        userInfo: [
                            NSLocalizedDescriptionKey: "Сервер вернул некорректный ответ"
                        ]
                    )
                }

                DispatchQueue.main.async {
                    completion(.success(dictionary))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
}

// MARK: - Shared UI

private enum SocialMarketUI {
    static let blue = UIColor(
        red: 0.12,
        green: 0.47,
        blue: 0.96,
        alpha: 1.0
    )

    static let gold = UIColor(
        red: 0.91,
        green: 0.68,
        blue: 0.20,
        alpha: 1.0
    )

    static func feedback(
        _ style: UIImpactFeedbackGenerator.FeedbackStyle = .light
    ) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    static func label(
        _ text: String,
        size: CGFloat = 14,
        weight: UIFont.Weight = .regular,
        color: UIColor = .label
    ) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.numberOfLines = 0
        return label
    }

    static func button(
        _ title: String,
        color: UIColor = SocialMarketUI.blue
    ) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(
            ofSize: 15,
            weight: .semibold
        )
        button.backgroundColor = color
        button.layer.cornerRadius = 13
        button.layer.cornerCurve = .continuous
        button.contentEdgeInsets = UIEdgeInsets(
            top: 12,
            left: 16,
            bottom: 12,
            right: 16
        )
        return button
    }

    static func card() -> UIView {
        let view = UIView()
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 19
        view.layer.cornerCurve = .continuous
        return view
    }

    static func image(
        systemName: String,
        size: CGFloat = 18,
        color: UIColor = .secondaryLabel
    ) -> UIImageView {
        let view = UIImageView(
            image: UIImage(systemName: systemName)
        )
        view.tintColor = color
        view.contentMode = .scaleAspectFit
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: size),
            view.heightAnchor.constraint(equalToConstant: size)
        ])
        return view
    }

    static func string(
        _ value: Any?,
        default fallback: String = ""
    ) -> String {
        guard let value, !(value is NSNull) else {
            return fallback
        }

        if let string = value as? String {
            return string
        }

        if let number = value as? NSNumber {
            return number.stringValue
        }

        return fallback
    }

    static func integer(
        _ value: Any?,
        default fallback: Int = 0
    ) -> Int {
        if let number = value as? Int {
            return number
        }

        if let number = value as? NSNumber {
            return number.intValue
        }

        if let string = value as? String,
           let number = Int(string) {
            return number
        }

        return fallback
    }

    static func double(
        _ value: Any?,
        default fallback: Double = 0
    ) -> Double {
        if let number = value as? Double {
            return number
        }

        if let number = value as? NSNumber {
            return number.doubleValue
        }

        if let string = value as? String,
           let number = Double(string) {
            return number
        }

        return fallback
    }

    static func bool(
        _ value: Any?,
        default fallback: Bool = false
    ) -> Bool {
        if let value = value as? Bool {
            return value
        }

        if let number = value as? NSNumber {
            return number.boolValue
        }

        return fallback
    }

    static func array(
        _ value: Any?
    ) -> [[String: Any]] {
        return value as? [[String: Any]] ?? []
    }

    static func showAlert(
        on controller: UIViewController,
        title: String,
        message: String
    ) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )

        alert.addAction(
            UIAlertAction(title: "OK", style: .default)
        )

        controller.present(alert, animated: true)
    }
}

// MARK: - Navigation bar

private func socialMarketNavigationData(
    theme: PresentationTheme
) -> NavigationBarPresentationData {
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
        strings: NavigationBarStrings(
            back: "Назад",
            close: "Закрыть"
        )
    )
}

// MARK: - Feed model

private struct SocialFeedPost {
    let id: String
    let authorId: Int
    let authorName: String
    let text: String
    let likes: Int
    let isLiked: Bool
    let isVerified: Bool
    let badges: [String]
    let nameStyle: String
    let fontStyle: String
    let avatarFrameId: String
    let avatarFrameColor: String
    let createdAt: String

    init(dictionary: [String: Any]) {
        self.id = SocialMarketUI.string(
            dictionary["id"] ?? dictionary["post_id"]
        )

        self.authorId = SocialMarketUI.integer(
            dictionary["author_id"] ?? dictionary["user_id"]
        )

        self.authorName = SocialMarketUI.string(
            dictionary["author_name"] ??
            dictionary["username"] ??
            dictionary["name"],
            default: "Пользователь"
        )

        self.text = SocialMarketUI.string(
            dictionary["text"] ?? dictionary["content"]
        )

        self.likes = SocialMarketUI.integer(
            dictionary["likes"] ?? dictionary["likes_count"]
        )

        self.isLiked = SocialMarketUI.bool(
            dictionary["liked"] ?? dictionary["is_liked"]
        )

        self.isVerified = SocialMarketUI.bool(
            dictionary["is_verified"] ?? dictionary["verified"]
        )

        self.badges = dictionary["badges"] as? [String] ?? []

        self.nameStyle = SocialMarketUI.string(
            dictionary["name_style"],
            default: "normal"
        )

        self.fontStyle = SocialMarketUI.string(
            dictionary["font_style"],
            default: "system"
        )

        self.avatarFrameId = SocialMarketUI.string(
            dictionary["avatar_frame_id"] ??
            dictionary["frame_id"]
        )

        self.avatarFrameColor = SocialMarketUI.string(
            dictionary["avatar_frame_color"] ??
            dictionary["frame_color"],
            default: "#4C9AFF"
        )

        self.createdAt = SocialMarketUI.string(
            dictionary["created_at"] ??
            dictionary["date"]
        )
    }
}

// MARK: - Feed post card

private final class SocialFeedPostView: UIView {
    var onLike: (() -> Void)?
    var onComments: (() -> Void)?
    var onAuthor: (() -> Void)?

    private let post: SocialFeedPost
    private let avatarContainer = UIView()
    private let avatarView = UIImageView()
    private let authorLabel = UILabel()
    private let badgeStack: UIStackView
    private let contentLabel = UILabel()
    private let dateLabel = UILabel()
    private let likeButton = UIButton(type: .system)
    private let commentsButton = UIButton(type: .system)

    init(post: SocialFeedPost) {
        self.post = post

        self.badgeStack = LuxuryStyleHelper.buildBadgesStack(
            leftBadges: post.badges,
            isVerified: post.isVerified
        )

        super.init(frame: .zero)

        configure()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    private func configure() {
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 19
        layer.cornerCurve = .continuous

        avatarContainer.translatesAutoresizingMaskIntoConstraints = false
        avatarContainer.clipsToBounds = false
        addSubview(avatarContainer)

        avatarView.translatesAutoresizingMaskIntoConstraints = false
        avatarView.image = UIImage(
            systemName: "person.crop.circle.fill"
        )
        avatarView.tintColor = .tertiaryLabel
        avatarView.backgroundColor = .tertiarySystemBackground
        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = 22
        avatarContainer.addSubview(avatarView)

        authorLabel.font = UIFont.systemFont(
            ofSize: 15,
            weight: .bold
        )
        authorLabel.translatesAutoresizingMaskIntoConstraints = false

        LuxuryStyleHelper.applyNameStyle(
            to: authorLabel,
            name: post.authorName,
            style: post.nameStyle,
            fontStyle: post.fontStyle
        )

        badgeStack.translatesAutoresizingMaskIntoConstraints = false

        let authorRow = UIStackView(
            arrangedSubviews: [authorLabel, badgeStack]
        )
        authorRow.axis = .horizontal
        authorRow.alignment = .center
        authorRow.spacing = 6
        authorRow.translatesAutoresizingMaskIntoConstraints = false

        dateLabel.text = post.createdAt
        dateLabel.font = UIFont.systemFont(
            ofSize: 11,
            weight: .regular
        )
        dateLabel.textColor = .secondaryLabel

        let authorColumn = UIStackView(
            arrangedSubviews: [authorRow, dateLabel]
        )
        authorColumn.axis = .vertical
        authorColumn.alignment = .leading
        authorColumn.spacing = 3
        authorColumn.translatesAutoresizingMaskIntoConstraints = false

        let header = UIStackView(
            arrangedSubviews: [avatarContainer, authorColumn]
        )
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = 10
        header.translatesAutoresizingMaskIntoConstraints = false

        contentLabel.text = post.text
        contentLabel.font = UIFont.systemFont(
            ofSize: 15,
            weight: .regular
        )
        contentLabel.textColor = .label
        contentLabel.numberOfLines = 0

        likeButton.setTitle(
            "\(post.isLiked ? "♥" : "♡")  \(post.likes)",
            for: .normal
        )
        likeButton.setTitleColor(
            post.isLiked ? .systemPink : .secondaryLabel,
            for: .normal
        )
        likeButton.titleLabel?.font = UIFont.systemFont(
            ofSize: 14,
            weight: .semibold
        )
        likeButton.addTarget(
            self,
            action: #selector(likePressed),
            for: .touchUpInside
        )

        commentsButton.setTitle("Комментарии", for: .normal)
        commentsButton.setTitleColor(
            SocialMarketUI.blue,
            for: .normal
        )
        commentsButton.titleLabel?.font = UIFont.systemFont(
            ofSize: 13,
            weight: .semibold
        )
        commentsButton.addTarget(
            self,
            action: #selector(commentsPressed),
            for: .touchUpInside
        )

        let actions = UIStackView(
            arrangedSubviews: [likeButton, commentsButton]
        )
        actions.axis = .horizontal
        actions.alignment = .center
        actions.spacing = 18

        let mainStack = UIStackView(
            arrangedSubviews: [header, contentLabel, actions]
        )
        mainStack.axis = .vertical
        mainStack.alignment = .fill
        mainStack.spacing = 13
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(
                equalTo: topAnchor,
                constant: 15
            ),
            mainStack.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: 15
            ),
            mainStack.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -15
            ),
            mainStack.bottomAnchor.constraint(
                equalTo: bottomAnchor,
                constant: -14
            ),

            avatarContainer.widthAnchor.constraint(
                equalToConstant: 44
            ),
            avatarContainer.heightAnchor.constraint(
                equalToConstant: 44
            ),

            avatarView.topAnchor.constraint(
                equalTo: avatarContainer.topAnchor,
                constant: 2
            ),
            avatarView.leadingAnchor.constraint(
                equalTo: avatarContainer.leadingAnchor,
                constant: 2
            ),
            avatarView.trailingAnchor.constraint(
                equalTo: avatarContainer.trailingAnchor,
                constant: -2
            ),
            avatarView.bottomAnchor.constraint(
                equalTo: avatarContainer.bottomAnchor,
                constant: -2
            )
        ])

        LuxuryStyleHelper.applyAvatarFrame(
            to: avatarContainer,
            frameId: post.avatarFrameId,
            colorHex: post.avatarFrameColor
        )

        let authorTap = UITapGestureRecognizer(
            target: self,
            action: #selector(authorPressed)
        )
        authorColumn.isUserInteractionEnabled = true
        authorColumn.addGestureRecognizer(authorTap)
    }

    @objc private func likePressed() {
        SocialMarketUI.feedback()
        onLike?()
    }

    @objc private func commentsPressed() {
        SocialMarketUI.feedback()
        onComments?()
    }

    @objc private func authorPressed() {
        SocialMarketUI.feedback()
        onAuthor?()
    }

    func updateLikes(_ likes: Int, isLiked: Bool) {
        likeButton.setTitle(
            "\(isLiked ? "♥" : "♡")  \(likes)",
            for: .normal
        )
        likeButton.setTitleColor(
            isLiked ? .systemPink : .secondaryLabel,
            for: .normal
        )
    }
}

// MARK: - Social feed controller

public final class SocialFeedController: ViewController {
    private let theme: PresentationTheme
    private let userId: Int

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let composerCard = UIView()
    private let composerTextView = UITextView()
    private let publishButton = UIButton(type: .system)
    private let refreshControl = UIRefreshControl()

    private var posts: [SocialFeedPost] = []
    private var postViews: [String: SocialFeedPostView] = [:]
    private var isPublishing = false

    public init(
        theme: PresentationTheme,
        userId: Int
    ) {
        self.theme = theme
        self.userId = userId

        super.init(
            navigationBarPresentationData: socialMarketNavigationData(
                theme: theme
            )
        )

        self.title = "Лента"
    }

    required init?(coder: NSCoder) {
        return nil
    }

    public override func displayNodeDidLoad() {
        super.displayNodeDidLoad()

        displayNode.backgroundColor = theme.list.blocksBackgroundColor

        let root = displayNode.view

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        root.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(
                equalTo: root.safeAreaLayoutGuide.topAnchor
            ),
            scrollView.leadingAnchor.constraint(
                equalTo: root.leadingAnchor
            ),
            scrollView.trailingAnchor.constraint(
                equalTo: root.trailingAnchor
            ),
            scrollView.bottomAnchor.constraint(
                equalTo: root.bottomAnchor
            )
        ])

        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.spacing = 14
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.topAnchor,
                constant: 14
            ),
            contentStack.leadingAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.leadingAnchor,
                constant: 14
            ),
            contentStack.trailingAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.trailingAnchor,
                constant: -14
            ),
            contentStack.bottomAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.bottomAnchor,
                constant: -22
            )
        ])

        configureComposer()

        refreshControl.addTarget(
            self,
            action: #selector(refreshPulled),
            for: .valueChanged
        )
        scrollView.refreshControl = refreshControl

        loadFeed()
    }

    private func configureComposer() {
        composerCard.backgroundColor = .secondarySystemBackground
        composerCard.layer.cornerRadius = 19
        composerCard.layer.cornerCurve = .continuous
        composerCard.translatesAutoresizingMaskIntoConstraints = false

        composerTextView.font = UIFont.systemFont(ofSize: 15)
        composerTextView.textColor = .label
        composerTextView.backgroundColor = .tertiarySystemBackground
        composerTextView.layer.cornerRadius = 12
        composerTextView.textContainerInset = UIEdgeInsets(
            top: 11,
            left: 10,
            bottom: 11,
            right: 10
        )
        composerTextView.translatesAutoresizingMaskIntoConstraints = false
        composerTextView.heightAnchor.constraint(
            greaterThanOrEqualToConstant: 82
        ).isActive = true

        publishButton.setTitle("Опубликовать", for: .normal)
        publishButton.setTitleColor(.white, for: .normal)
        publishButton.titleLabel?.font = UIFont.systemFont(
            ofSize: 14,
            weight: .semibold
        )
        publishButton.backgroundColor = SocialMarketUI.blue
        publishButton.layer.cornerRadius = 12
        publishButton.contentEdgeInsets = UIEdgeInsets(
            top: 11,
            left: 17,
            bottom: 11,
            right: 17
        )
        publishButton.addTarget(
            self,
            action: #selector(publishPressed),
            for: .touchUpInside
        )

        let title = SocialMarketUI.label(
            "Новая публикация",
            size: 16,
            weight: .bold
        )

        let stack = UIStackView(
            arrangedSubviews: [
                title,
                composerTextView,
                publishButton
            ]
        )
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 11
        stack.translatesAutoresizingMaskIntoConstraints = false

        composerCard.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(
                equalTo: composerCard.topAnchor,
                constant: 14
            ),
            stack.leadingAnchor.constraint(
                equalTo: composerCard.leadingAnchor,
                constant: 14
            ),
            stack.trailingAnchor.constraint(
                equalTo: composerCard.trailingAnchor,
                constant: -14
            ),
            stack.bottomAnchor.constraint(
                equalTo: composerCard.bottomAnchor,
                constant: -14
            )
        ])

        contentStack.addArrangedSubview(composerCard)
    }

    @objc private func refreshPulled() {
        loadFeed()
    }

    private func loadFeed() {
        SocialMarketAPI.request(
            path: "feed",
            method: "GET",
            userId: userId
        ) { [weak self] result in
            guard let self else { return }

            self.refreshControl.endRefreshing()

            switch result {
            case let .success(response):
                let rawPosts = SocialMarketUI.array(
                    response["posts"] ??
                    response["items"] ??
                    response["feed"]
                )

                self.posts = rawPosts.map {
                    SocialFeedPost(dictionary: $0)
                }

                self.renderPosts()

            case let .failure(error):
                SocialMarketUI.showAlert(
                    on: self,
                    title: "Лента",
                    message: "Не удалось загрузить публикации: \(error.localizedDescription)"
                )
            }
        }
    }

    private func renderPosts() {
        for view in Array(contentStack.arrangedSubviews.dropFirst()) {
            contentStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        postViews.removeAll()

        if posts.isEmpty {
            let empty = SocialMarketUI.label(
                "Пока нет публикаций. Будьте первым!",
                size: 14,
                color: .secondaryLabel
            )
            empty.textAlignment = .center
            empty.heightAnchor.constraint(
                greaterThanOrEqualToConstant: 80
            ).isActive = true
            contentStack.addArrangedSubview(empty)
            return
        }

        for post in posts {
            let postView = SocialFeedPostView(post: post)

            postView.onLike = { [weak self, weak postView] in
                guard let self, let postView else { return }
                self.likePost(post, in: postView)
            }

            postView.onComments = { [weak self] in
                guard let self else { return }
                self.openComments(for: post)
            }

            postView.onAuthor = { [weak self] in
                guard let self else { return }
                self.openAuthor(post)
            }

            postViews[post.id] = postView
            contentStack.addArrangedSubview(postView)
        }
    }

    @objc private func publishPressed() {
        let text = composerTextView.text.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !text.isEmpty else {
            SocialMarketUI.showAlert(
                on: self,
                title: "Новая публикация",
                message: "Введите текст публикации."
            )
            return
        }

        guard !isPublishing else {
            return
        }

        SocialMarketUI.feedback(.medium)

        isPublishing = true
        publishButton.isEnabled = false
        publishButton.setTitle("Публикуем…", for: .normal)

        SocialMarketAPI.request(
            path: "feed/create",
            method: "POST",
            userId: userId,
            body: ["text": text]
        ) { [weak self] result in
            guard let self else { return }

            self.isPublishing = false
            self.publishButton.isEnabled = true
            self.publishButton.setTitle(
                "Опубликовать",
                for: .normal
            )

            switch result {
            case .success:
                self.composerTextView.text = ""
                self.loadFeed()

            case let .failure(error):
                SocialMarketUI.showAlert(
                    on: self,
                    title: "Ошибка публикации",
                    message: error.localizedDescription
                )
            }
        }
    }

    private func likePost(
        _ post: SocialFeedPost,
        in postView: SocialFeedPostView
    ) {
        SocialMarketAPI.request(
            path: "feed/like",
            method: "POST",
            userId: userId,
            body: ["post_id": post.id]
        ) { [weak self, weak postView] result in
            guard let self, let postView else { return }

            switch result {
            case let .success(response):
                let likes = SocialMarketUI.integer(
                    response["likes"] ?? response["likes_count"],
                    default: post.likes + (post.isLiked ? -1 : 1)
                )

                let liked = SocialMarketUI.bool(
                    response["liked"] ?? response["is_liked"],
                    default: !post.isLiked
                )

                postView.updateLikes(likes, isLiked: liked)

            case let .failure(error):
                SocialMarketUI.showAlert(
                    on: self,
                    title: "Лайк",
                    message: error.localizedDescription
                )
            }
        }
    }

    private func openComments(for post: SocialFeedPost) {
        let alert = UIAlertController(
            title: "Комментарии",
            message: "Публикация \(post.id)",
            preferredStyle: .alert
        )

        alert.addAction(
            UIAlertAction(title: "Закрыть", style: .cancel)
        )

        present(alert, animated: true)
    }

    private func openAuthor(_ post: SocialFeedPost) {
        let alert = UIAlertController(
            title: post.authorName,
            message: "ID пользователя: \(post.authorId)",
            preferredStyle: .alert
        )

        alert.addAction(
            UIAlertAction(title: "Закрыть", style: .default)
        )

        present(alert, animated: true)
    }
}

// MARK: - Leaderboard model

private struct LeaderboardEntry {
    let id: String
    let name: String
    let value: String
    let position: Int
    let isVerified: Bool
    let badges: [String]
    let nameStyle: String
    let fontStyle: String
    let avatarFrameId: String
    let avatarFrameColor: String

    init(dictionary: [String: Any], fallbackPosition: Int) {
        id = SocialMarketUI.string(
            dictionary["id"] ??
            dictionary["user_id"] ??
            dictionary["clan_id"],
            default: "\(fallbackPosition)"
        )

        name = SocialMarketUI.string(
            dictionary["name"] ??
            dictionary["username"] ??
            dictionary["title"] ??
            dictionary["clan_name"],
            default: "Игрок"
        )

        position = SocialMarketUI.integer(
            dictionary["position"] ??
            dictionary["rank"],
            default: fallbackPosition
        )

        isVerified = SocialMarketUI.bool(
            dictionary["verified"] ??
            dictionary["is_verified"]
        )

        badges = dictionary["badges"] as? [String] ?? []

        nameStyle = SocialMarketUI.string(
            dictionary["name_style"],
            default: "normal"
        )

        fontStyle = SocialMarketUI.string(
            dictionary["font_style"],
            default: "system"
        )

        avatarFrameId = SocialMarketUI.string(
            dictionary["avatar_frame_id"] ??
            dictionary["frame_id"]
        )

        avatarFrameColor = SocialMarketUI.string(
            dictionary["avatar_frame_color"] ??
            dictionary["frame_color"],
            default: "#4C9AFF"
        )

        let amount = dictionary["net_worth"] ??
            dictionary["balance"] ??
            dictionary["stars_stolen"] ??
            dictionary["stolen"] ??
            dictionary["clan_points"] ??
            dictionary["points"] ??
            dictionary["score"] ??
            dictionary["amount"]

        if let amount {
            if let number = amount as? NSNumber {
                if dictionary["ton"] != nil ||
                    dictionary["net_worth"] != nil ||
                    dictionary["balance"] != nil {
                    value = String(format: "%.3f TON", number.doubleValue)
                } else {
                    value = number.stringValue
                }
            } else {
                value = SocialMarketUI.string(amount)
            }
        } else {
            value = "—"
        }
    }
}

// MARK: - Leaderboard row

private final class LeaderboardEntryView: UIView {
    private let entry: LeaderboardEntry

    init(entry: LeaderboardEntry) {
        self.entry = entry
        super.init(frame: .zero)
        configure()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    private func configure() {
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 16
        layer.cornerCurve = .continuous

        let medal: String
        switch entry.position {
        case 1: medal = "🥇"
        case 2: medal = "🥈"
        case 3: medal = "🥉"
        default: medal = "\(entry.position)."
        }

        let positionLabel = SocialMarketUI.label(
            medal,
            size: 19,
            weight: .bold
        )
        positionLabel.textAlignment = .center
        positionLabel.widthAnchor.constraint(
            equalToConstant: 38
        ).isActive = true

        let avatarContainer = UIView()
        avatarContainer.translatesAutoresizingMaskIntoConstraints = false
        avatarContainer.widthAnchor.constraint(
            equalToConstant: 42
        ).isActive = true
        avatarContainer.heightAnchor.constraint(
            equalToConstant: 42
        ).isActive = true

        let avatar = UIImageView(
            image: UIImage(systemName: "person.crop.circle.fill")
        )
        avatar.translatesAutoresizingMaskIntoConstraints = false
        avatar.tintColor = .tertiaryLabel
        avatar.backgroundColor = .tertiarySystemBackground
        avatar.contentMode = .scaleAspectFill
        avatar.clipsToBounds = true
        avatar.layer.cornerRadius = 19
        avatarContainer.addSubview(avatar)

        NSLayoutConstraint.activate([
            avatar.topAnchor.constraint(
                equalTo: avatarContainer.topAnchor,
                constant: 2
            ),
            avatar.leadingAnchor.constraint(
                equalTo: avatarContainer.leadingAnchor,
                constant: 2
            ),
            avatar.trailingAnchor.constraint(
                equalTo: avatarContainer.trailingAnchor,
                constant: -2
            ),
            avatar.bottomAnchor.constraint(
                equalTo: avatarContainer.bottomAnchor,
                constant: -2
            )
        ])

        LuxuryStyleHelper.applyAvatarFrame(
            to: avatarContainer,
            frameId: entry.avatarFrameId,
            colorHex: entry.avatarFrameColor
        )

        let nameLabel = UILabel()
        nameLabel.font = UIFont.systemFont(
            ofSize: 14,
            weight: .bold
        )

        LuxuryStyleHelper.applyNameStyle(
            to: nameLabel,
            name: entry.name,
            style: entry.nameStyle,
            fontStyle: entry.fontStyle
        )

        let badges = LuxuryStyleHelper.buildBadgesStack(
            leftBadges: entry.badges,
            isVerified: entry.isVerified
        )

        let nameRow = UIStackView(
            arrangedSubviews: [nameLabel, badges]
        )
        nameRow.axis = .horizontal
        nameRow.alignment = .center
        nameRow.spacing = 5

        let valueLabel = SocialMarketUI.label(
            entry.value,
            size: 12,
            weight: .semibold,
            color: .secondaryLabel
        )

        let textColumn = UIStackView(
            arrangedSubviews: [nameRow, valueLabel]
        )
        textColumn.axis = .vertical
        textColumn.alignment = .leading
        textColumn.spacing = 4

        let row = UIStackView(
            arrangedSubviews: [
                positionLabel,
                avatarContainer,
                textColumn
            ]
        )
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 9
        row.translatesAutoresizingMaskIntoConstraints = false

        addSubview(row)

        NSLayoutConstraint.activate([
            row.topAnchor.constraint(
                equalTo: topAnchor,
                constant: 11
            ),
            row.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: 12
            ),
            row.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -12
            ),
            row.bottomAnchor.constraint(
                equalTo: bottomAnchor,
                constant: -11
            )
        ])
    }
}

// MARK: - Global leaderboard controller

public final class GlobalLeaderboardController: ViewController {
    private enum Tab: Int {
        case forbes = 0
        case thieves = 1
        case clans = 2

        var apiValue: String {
            switch self {
            case .forbes:
                return "forbes"
            case .thieves:
                return "thieves"
            case .clans:
                return "clans"
            }
        }

        var title: String {
            switch self {
            case .forbes:
                return "🏆 Форбс"
            case .thieves:
                return "🐭 Топ Воришек"
            case .clans:
                return "⚔️ Кланы"
            }
        }
    }

    private let theme: PresentationTheme
    private let userId: Int

    private let segmentedControl = UISegmentedControl(
        items: [
            "🏆 Форбс",
            "🐭 Топ Воришек",
            "⚔️ Кланы"
        ]
    )

    private let scrollView = UIScrollView()
    private let listStack = UIStackView()
    private let loadingIndicator = UIActivityIndicatorView(
        style: .medium
    )

    private var selectedTab: Tab = .forbes

    public init(
        theme: PresentationTheme,
        userId: Int
    ) {
        self.theme = theme
        self.userId = userId

        super.init(
            navigationBarPresentationData: socialMarketNavigationData(
                theme: theme
            )
        )

        self.title = "Лидерборд"
    }

    required init?(coder: NSCoder) {
        return nil
    }

    public override func displayNodeDidLoad() {
        super.displayNodeDidLoad()

        displayNode.backgroundColor = theme.list.blocksBackgroundColor

        let root = displayNode.view

        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(
            self,
            action: #selector(tabChanged),
            for: .valueChanged
        )
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(segmentedControl)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        root.addSubview(scrollView)

        listStack.axis = .vertical
        listStack.alignment = .fill
        listStack.spacing = 9
        listStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(listStack)

        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.hidesWhenStopped = true
        root.addSubview(loadingIndicator)

        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(
                equalTo: root.safeAreaLayoutGuide.topAnchor,
                constant: 12
            ),
            segmentedControl.leadingAnchor.constraint(
                equalTo: root.leadingAnchor,
                constant: 12
            ),
            segmentedControl.trailingAnchor.constraint(
                equalTo: root.trailingAnchor,
                constant: -12
            ),

            scrollView.topAnchor.constraint(
                equalTo: segmentedControl.bottomAnchor,
                constant: 14
            ),
            scrollView.leadingAnchor.constraint(
                equalTo: root.leadingAnchor,
                constant: 14
            ),
            scrollView.trailingAnchor.constraint(
                equalTo: root.trailingAnchor,
                constant: -14
            ),
            scrollView.bottomAnchor.constraint(
                equalTo: root.bottomAnchor
            ),

            listStack.topAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.topAnchor
            ),
            listStack.leadingAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.leadingAnchor
            ),
            listStack.trailingAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.trailingAnchor
            ),
            listStack.bottomAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.bottomAnchor,
                constant: -20
            ),

            loadingIndicator.centerXAnchor.constraint(
                equalTo: root.centerXAnchor
            ),
            loadingIndicator.centerYAnchor.constraint(
                equalTo: root.centerYAnchor
            )
        ])

        loadLeaderboard()
    }

    @objc private func tabChanged() {
        guard let tab = Tab(
            rawValue: segmentedControl.selectedSegmentIndex
        ) else {
            return
        }

        SocialMarketUI.feedback()
        selectedTab = tab
        loadLeaderboard()
    }

    private func loadLeaderboard() {
        loadingIndicator.startAnimating()

        SocialMarketAPI.request(
            path: "leaderboard",
            method: "GET",
            userId: userId,
            query: ["tab": selectedTab.apiValue]
        ) { [weak self] result in
            guard let self else { return }

            self.loadingIndicator.stopAnimating()

            switch result {
            case let .success(response):
                let rawEntries = SocialMarketUI.array(
                    response["entries"] ??
                    response["items"] ??
                    response["players"] ??
                    response["leaders"] ??
                    response["clans"]
                )

                let entries = rawEntries.enumerated().map {
                    LeaderboardEntry(
                        dictionary: $0.element,
                        fallbackPosition: $0.offset + 1
                    )
                }

                self.render(entries: entries)

            case let .failure(error):
                self.render(entries: [])
                SocialMarketUI.showAlert(
                    on: self,
                    title: "Лидерборд",
                    message: "Не удалось загрузить рейтинг: \(error.localizedDescription)"
                )
            }
        }
    }

    private func render(entries: [LeaderboardEntry]) {
        for view in listStack.arrangedSubviews {
            listStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        if entries.isEmpty {
            let empty = SocialMarketUI.label(
                "Пока нет данных для этой категории.",
                size: 14,
                color: .secondaryLabel
            )
            empty.textAlignment = .center
            empty.heightAnchor.constraint(
                greaterThanOrEqualToConstant: 90
            ).isActive = true
            listStack.addArrangedSubview(empty)
            return
        }

        let heading = SocialMarketUI.label(
            selectedTab.title,
            size: 19,
            weight: .bold
        )
        heading.textAlignment = .left
        listStack.addArrangedSubview(heading)

        for entry in entries {
            let row = LeaderboardEntryView(entry: entry)
            listStack.addArrangedSubview(row)
        }
    }
}
// MARK: - Clan models

private struct ClanMember {
    let id: Int
    let name: String
    let role: String
    let points: Int
    let isVerified: Bool
    let badges: [String]
    let nameStyle: String
    let fontStyle: String
    let avatarFrameId: String
    let avatarFrameColor: String

    init(dictionary: [String: Any], index: Int) {
        id = SocialMarketUI.integer(
            dictionary["user_id"] ?? dictionary["id"]
        )

        name = SocialMarketUI.string(
            dictionary["name"] ??
            dictionary["username"],
            default: "Участник \(index + 1)"
        )

        role = SocialMarketUI.string(
            dictionary["role"],
            default: "member"
        )

        points = SocialMarketUI.integer(
            dictionary["points"] ??
            dictionary["score"]
        )

        isVerified = SocialMarketUI.bool(
            dictionary["is_verified"] ??
            dictionary["verified"]
        )

        badges = dictionary["badges"] as? [String] ?? []

        nameStyle = SocialMarketUI.string(
            dictionary["name_style"],
            default: "normal"
        )

        fontStyle = SocialMarketUI.string(
            dictionary["font_style"],
            default: "system"
        )

        avatarFrameId = SocialMarketUI.string(
            dictionary["avatar_frame_id"] ??
            dictionary["frame_id"]
        )

        avatarFrameColor = SocialMarketUI.string(
            dictionary["avatar_frame_color"] ??
            dictionary["frame_color"],
            default: "#4C9AFF"
        )
    }

    var roleTitle: String {
        switch role.lowercased() {
        case "leader", "owner", "chief", "head":
            return "👑 глава"
        case "deputy", "vice", "moderator":
            return "🛡 зам."
        default:
            return "Участник"
        }
    }
}

// MARK: - Clan member row

private final class ClanMemberRow: UIView {
    init(member: ClanMember) {
        super.init(frame: .zero)
        configure(member: member)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    private func configure(member: ClanMember) {
        backgroundColor = .tertiarySystemBackground
        layer.cornerRadius = 13

        let avatarContainer = UIView()
        avatarContainer.translatesAutoresizingMaskIntoConstraints = false
        avatarContainer.widthAnchor.constraint(
            equalToConstant: 38
        ).isActive = true
        avatarContainer.heightAnchor.constraint(
            equalToConstant: 38
        ).isActive = true

        let avatar = UIImageView(
            image: UIImage(systemName: "person.crop.circle.fill")
        )
        avatar.translatesAutoresizingMaskIntoConstraints = false
        avatar.tintColor = .tertiaryLabel
        avatar.contentMode = .scaleAspectFill
        avatar.clipsToBounds = true
        avatar.layer.cornerRadius = 18
        avatarContainer.addSubview(avatar)

        NSLayoutConstraint.activate([
            avatar.topAnchor.constraint(
                equalTo: avatarContainer.topAnchor,
                constant: 2
            ),
            avatar.leadingAnchor.constraint(
                equalTo: avatarContainer.leadingAnchor,
                constant: 2
            ),
            avatar.trailingAnchor.constraint(
                equalTo: avatarContainer.trailingAnchor,
                constant: -2
            ),
            avatar.bottomAnchor.constraint(
                equalTo: avatarContainer.bottomAnchor,
                constant: -2
            )
        ])

        LuxuryStyleHelper.applyAvatarFrame(
            to: avatarContainer,
            frameId: member.avatarFrameId,
            colorHex: member.avatarFrameColor
        )

        let name = UILabel()
        name.font = UIFont.systemFont(
            ofSize: 14,
            weight: .semibold
        )

        LuxuryStyleHelper.applyNameStyle(
            to: name,
            name: member.name,
            style: member.nameStyle,
            fontStyle: member.fontStyle
        )

        let badges = LuxuryStyleHelper.buildBadgesStack(
            leftBadges: member.badges,
            isVerified: member.isVerified
        )

        let nameRow = UIStackView(
            arrangedSubviews: [name, badges]
        )
        nameRow.axis = .horizontal
        nameRow.alignment = .center
        nameRow.spacing = 5

        let role = SocialMarketUI.label(
            member.roleTitle,
            size: 11,
            weight: .medium,
            color: .secondaryLabel
        )

        let points = SocialMarketUI.label(
            "\(member.points) очков",
            size: 11,
            weight: .medium,
            color: .secondaryLabel
        )

        let details = UIStackView(
            arrangedSubviews: [nameRow, role]
        )
        details.axis = .vertical
        details.alignment = .leading
        details.spacing = 3

        let row = UIStackView(
            arrangedSubviews: [
                avatarContainer,
                details,
                UIView(),
                points
            ]
        )
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 9
        row.translatesAutoresizingMaskIntoConstraints = false

        addSubview(row)

        NSLayoutConstraint.activate([
            row.topAnchor.constraint(
                equalTo: topAnchor,
                constant: 9
            ),
            row.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: 10
            ),
            row.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -10
            ),
            row.bottomAnchor.constraint(
                equalTo: bottomAnchor,
                constant: -9
            )
        ])
    }
}

// MARK: - Clan hub controller

public final class ClanHubController: ViewController {
    private let theme: PresentationTheme
    private let userId: Int

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let clanCard = UIView()
    private let membersStack = UIStackView()

    private let emblemLabel = UILabel()
    private let clanNameLabel = UILabel()
    private let clanTagLabel = UILabel()
    private let ratingLabel = UILabel()
    private let warScoreLabel = UILabel()
    private let membersCountLabel = UILabel()

    private let createButton = UIButton(type: .system)
    private let joinButton = UIButton(type: .system)

    private var clanId: String?
    private var clanName: String = "Ваш клан"
    private var clanTag: String = ""
    private var clanRating: Int = 0
    private var clanWarScore: Int = 0
    private var members: [ClanMember] = []

    public init(
        theme: PresentationTheme,
        userId: Int
    ) {
        self.theme = theme
        self.userId = userId

        super.init(
            navigationBarPresentationData: socialMarketNavigationData(
                theme: theme
            )
        )

        self.title = "Кланы"
    }

    required init?(coder: NSCoder) {
        return nil
    }

    public override func displayNodeDidLoad() {
        super.displayNodeDidLoad()

        displayNode.backgroundColor = theme.list.blocksBackgroundColor

        let root = displayNode.view

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        root.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(
                equalTo: root.safeAreaLayoutGuide.topAnchor
            ),
            scrollView.leadingAnchor.constraint(
                equalTo: root.leadingAnchor
            ),
            scrollView.trailingAnchor.constraint(
                equalTo: root.trailingAnchor
            ),
            scrollView.bottomAnchor.constraint(
                equalTo: root.bottomAnchor
            )
        ])

        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.spacing = 15
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.topAnchor,
                constant: 15
            ),
            contentStack.leadingAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.leadingAnchor,
                constant: 15
            ),
            contentStack.trailingAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.trailingAnchor,
                constant: -15
            ),
            contentStack.bottomAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.bottomAnchor,
                constant: -25
            )
        ])

        configureClanCard()
        configureActions()
        configureMembers()

        contentStack.addArrangedSubview(clanCard)

        let actionRow = UIStackView(
            arrangedSubviews: [createButton, joinButton]
        )
        actionRow.axis = .horizontal
        actionRow.distribution = .fillEqually
        actionRow.spacing = 10
        contentStack.addArrangedSubview(actionRow)

        let membersCard = SocialMarketUI.card()
        let membersTitle = SocialMarketUI.label(
            "Участники клана",
            size: 17,
            weight: .bold
        )

        let membersContainer = UIStackView(
            arrangedSubviews: [membersTitle, membersStack]
        )
        membersContainer.axis = .vertical
        membersContainer.spacing = 12
        membersContainer.translatesAutoresizingMaskIntoConstraints = false

        membersCard.addSubview(membersContainer)

        NSLayoutConstraint.activate([
            membersContainer.topAnchor.constraint(
                equalTo: membersCard.topAnchor,
                constant: 15
            ),
            membersContainer.leadingAnchor.constraint(
                equalTo: membersCard.leadingAnchor,
                constant: 13
            ),
            membersContainer.trailingAnchor.constraint(
                equalTo: membersCard.trailingAnchor,
                constant: -13
            ),
            membersContainer.bottomAnchor.constraint(
                equalTo: membersCard.bottomAnchor,
                constant: -13
            )
        ])

        contentStack.addArrangedSubview(membersCard)

        renderClan()
    }

    private func configureClanCard() {
        clanCard.backgroundColor = .secondarySystemBackground
        clanCard.layer.cornerRadius = 22
        clanCard.layer.cornerCurve = .continuous

        emblemLabel.text = "🛡️"
        emblemLabel.font = UIFont.systemFont(ofSize: 46)
        emblemLabel.textAlignment = .center

        clanNameLabel.font = UIFont.systemFont(
            ofSize: 21,
            weight: .bold
        )
        clanNameLabel.textAlignment = .center

        clanTagLabel.font = UIFont.systemFont(
            ofSize: 13,
            weight: .semibold
        )
        clanTagLabel.textColor = SocialMarketUI.blue
        clanTagLabel.textAlignment = .center

        ratingLabel.font = UIFont.systemFont(
            ofSize: 14,
            weight: .semibold
        )
        ratingLabel.textAlignment = .center

        warScoreLabel.font = UIFont.systemFont(
            ofSize: 13,
            weight: .medium
        )
        warScoreLabel.textColor = .secondaryLabel
        warScoreLabel.textAlignment = .center

        membersCountLabel.font = UIFont.systemFont(
            ofSize: 12,
            weight: .medium
        )
        membersCountLabel.textColor = .secondaryLabel
        membersCountLabel.textAlignment = .center

        let stack = UIStackView(
            arrangedSubviews: [
                emblemLabel,
                clanNameLabel,
                clanTagLabel,
                ratingLabel,
                warScoreLabel,
                membersCountLabel
            ]
        )
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 9
        stack.translatesAutoresizingMaskIntoConstraints = false

        clanCard.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(
                equalTo: clanCard.topAnchor,
                constant: 21
            ),
            stack.leadingAnchor.constraint(
                equalTo: clanCard.leadingAnchor,
                constant: 16
            ),
            stack.trailingAnchor.constraint(
                equalTo: clanCard.trailingAnchor,
                constant: -16
            ),
            stack.bottomAnchor.constraint(
                equalTo: clanCard.bottomAnchor,
                constant: -21
            )
        ])
    }

    private func configureActions() {
        createButton.setTitle("＋ Создать клан", for: .normal)
        createButton.setTitleColor(.white, for: .normal)
        createButton.backgroundColor = SocialMarketUI.blue
        createButton.layer.cornerRadius = 13
        createButton.titleLabel?.font = UIFont.systemFont(
            ofSize: 14,
            weight: .semibold
        )
        createButton.contentEdgeInsets = UIEdgeInsets(
            top: 13,
            left: 10,
            bottom: 13,
            right: 10
        )
        createButton.addTarget(
            self,
            action: #selector(createClanPressed),
            for: .touchUpInside
        )

        joinButton.setTitle("Вступить", for: .normal)
        joinButton.setTitleColor(.white, for: .normal)
        joinButton.backgroundColor = UIColor.systemGreen
        joinButton.layer.cornerRadius = 13
        joinButton.titleLabel?.font = UIFont.systemFont(
            ofSize: 14,
            weight: .semibold
        )
        joinButton.contentEdgeInsets = UIEdgeInsets(
            top: 13,
            left: 10,
            bottom: 13,
            right: 10
        )
        joinButton.addTarget(
            self,
            action: #selector(joinClanPressed),
            for: .touchUpInside
        )
    }

    private func configureMembers() {
        membersStack.axis = .vertical
        membersStack.alignment = .fill
        membersStack.spacing = 8
    }

    private func renderClan() {
        clanNameLabel.text = clanName
        clanTagLabel.text = clanTag.isEmpty ? "Клан не выбран" : "[\(clanTag)]"
        ratingLabel.text = "🏆 Рейтинг: \(clanRating)"
        warScoreLabel.text = "⚔️ Счёт клановой войны: \(clanWarScore)"
        membersCountLabel.text = "👥 \(members.count) / 200 участников"

        for view in membersStack.arrangedSubviews {
            membersStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        if members.isEmpty {
            let empty = SocialMarketUI.label(
                "Список участников пока пуст.",
                size: 13,
                color: .secondaryLabel
            )
            membersStack.addArrangedSubview(empty)
        } else {
            for member in members.prefix(200) {
                membersStack.addArrangedSubview(
                    ClanMemberRow(member: member)
                )
            }
        }
    }

    @objc private func createClanPressed() {
        SocialMarketUI.feedback(.medium)

        let alert = UIAlertController(
            title: "Создать клан",
            message: "Введите название и тег нового клана.",
            preferredStyle: .alert
        )

        alert.addTextField { field in
            field.placeholder = "Название клана"
            field.autocapitalizationType = .words
        }

        alert.addTextField { field in
            field.placeholder = "Тег, например BOSS"
            field.autocapitalizationType = .allCharacters
        }

        alert.addAction(
            UIAlertAction(title: "Отмена", style: .cancel)
        )

        alert.addAction(
            UIAlertAction(title: "Создать", style: .default) { [weak self, weak alert] _ in
                guard let self, let alert else { return }

                let name = alert.textFields?.first?.text?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                let tag = alert.textFields?.dropFirst().first?.text?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                guard !name.isEmpty, !tag.isEmpty else {
                    SocialMarketUI.showAlert(
                        on: self,
                        title: "Создание клана",
                        message: "Заполните название и тег."
                    )
                    return
                }

                self.createClan(name: name, tag: tag)
            }
        )

        present(alert, animated: true)
    }

    private func createClan(name: String, tag: String) {
        SocialMarketAPI.request(
            path: "clan/create",
            method: "POST",
            userId: userId,
            body: [
                "name": name,
                "tag": tag
            ]
        ) { [weak self] result in
            guard let self else { return }

            switch result {
            case let .success(response):
                self.clanId = SocialMarketUI.string(
                    response["clan_id"] ?? response["id"]
                )
                self.clanName = SocialMarketUI.string(
                    response["name"],
                    default: name
                )
                self.clanTag = SocialMarketUI.string(
                    response["tag"],
                    default: tag
                )
                self.clanRating = SocialMarketUI.integer(
                    response["rating"]
                )
                self.clanWarScore = SocialMarketUI.integer(
                    response["war_score"]
                )
                self.renderClan()

                SocialMarketUI.showAlert(
                    on: self,
                    title: "Клан создан",
                    message: "Клан \(self.clanName) успешно создан."
                )

            case let .failure(error):
                SocialMarketUI.showAlert(
                    on: self,
                    title: "Ошибка",
                    message: error.localizedDescription
                )
            }
        }
    }

    @objc private func joinClanPressed() {
        SocialMarketUI.feedback(.medium)

        let alert = UIAlertController(
            title: "Вступить в клан",
            message: "Введите ID или тег клана.",
            preferredStyle: .alert
        )

        alert.addTextField { field in
            field.placeholder = "ID или тег клана"
            field.autocapitalizationType = .allCharacters
        }

        alert.addAction(
            UIAlertAction(title: "Отмена", style: .cancel)
        )

        alert.addAction(
            UIAlertAction(title: "Вступить", style: .default) { [weak self, weak alert] _ in
                guard let self, let alert else { return }

                let clan = alert.textFields?.first?.text?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                guard !clan.isEmpty else {
                    SocialMarketUI.showAlert(
                        on: self,
                        title: "Вступление в клан",
                        message: "Введите ID или тег клана."
                    )
                    return
                }

                self.joinClan(identifier: clan)
            }
        )

        present(alert, animated: true)
    }

    private func joinClan(identifier: String) {
        SocialMarketAPI.request(
            path: "clan/join",
            method: "POST",
            userId: userId,
            body: [
                "clan_id": identifier
            ]
        ) { [weak self] result in
            guard let self else { return }

            switch result {
            case let .success(response):
                self.clanId = SocialMarketUI.string(
                    response["clan_id"] ?? response["id"],
                    default: identifier
                )

                self.clanName = SocialMarketUI.string(
                    response["clan_name"] ?? response["name"],
                    default: self.clanName
                )

                self.clanTag = SocialMarketUI.string(
                    response["tag"],
                    default: self.clanTag
                )

                self.clanRating = SocialMarketUI.integer(
                    response["rating"],
                    default: self.clanRating
                )

                self.clanWarScore = SocialMarketUI.integer(
                    response["war_score"],
                    default: self.clanWarScore
                )

                let rawMembers = SocialMarketUI.array(
                    response["members"]
                )

                if !rawMembers.isEmpty {
                    self.members = rawMembers.prefix(200).enumerated().map {
                        ClanMember(
                            dictionary: $0.element,
                            index: $0.offset
                        )
                    }
                }

                self.renderClan()

                SocialMarketUI.showAlert(
                    on: self,
                    title: "Клан",
                    message: "Запрос на вступление обработан сервером."
                )

            case let .failure(error):
                SocialMarketUI.showAlert(
                    on: self,
                    title: "Не удалось вступить",
                    message: error.localizedDescription
                )
            }
        }
    }
}

// MARK: - Marketplace models

private struct MarketListing {
    let id: String
    let title: String
    let category: String
    let priceTON: Double
    let priceUSD: Double?
    let seller: String
    let description: String
    let symbol: String

    init(dictionary: [String: Any]) {
        id = SocialMarketUI.string(
            dictionary["id"] ??
            dictionary["listing_id"] ??
            dictionary["lot_id"]
        )

        title = SocialMarketUI.string(
            dictionary["title"] ??
            dictionary["asset"] ??
            dictionary["name"],
            default: "Коллекционный актив"
        )

        category = SocialMarketUI.string(
            dictionary["category"] ??
            dictionary["type"],
            default: "nft"
        ).lowercased()

        priceTON = SocialMarketUI.double(
            dictionary["price_ton"] ??
            dictionary["price"]
        )

        if let usd = dictionary["price_usd"] {
            priceUSD = SocialMarketUI.double(usd)
        } else {
            priceUSD = nil
        }

        seller = SocialMarketUI.string(
            dictionary["seller_name"] ??
            dictionary["seller"],
            default: "Продавец"
        )

        description = SocialMarketUI.string(
            dictionary["description"]
        )

        symbol = SocialMarketUI.string(
            dictionary["symbol"] ??
            dictionary["emoji"],
            default: "🎁"
        )
    }
}

private struct GiftCatalogItem {
    let id: String
    let name: String
    let symbol: String
    let rarity: String
    let supply: Int
    let priceStars: Int
    let priceTON: Double
    let isExclusive: Bool

    init(dictionary: [String: Any]) {
        id = SocialMarketUI.string(
            dictionary["gift_id"] ??
            dictionary["id"] ??
            dictionary["item_id"]
        )

        name = SocialMarketUI.string(
            dictionary["name"] ??
            dictionary["title"],
            default: "Подарок"
        )

        symbol = SocialMarketUI.string(
            dictionary["symbol"] ??
            dictionary["emoji"],
            default: "🎁"
        )

        rarity = SocialMarketUI.string(
            dictionary["rarity"],
            default: "common"
        )

        supply = SocialMarketUI.integer(
            dictionary["supply"] ??
            dictionary["remaining"]
        )

        priceStars = SocialMarketUI.integer(
            dictionary["price_stars"] ??
            dictionary["stars"]
        )

        priceTON = SocialMarketUI.double(
            dictionary["price_ton"] ??
            dictionary["ton"]
        )

        isExclusive = SocialMarketUI.bool(
            dictionary["exclusive"] ??
            dictionary["is_exclusive"]
        ) || rarity.lowercased() == "legendary" ||
            rarity.lowercased() == "mythic" ||
            rarity.lowercased() == "exclusive"
    }
}

// MARK: - Marketplace listing card

private final class MarketListingView: UIView {
    var onBuy: (() -> Void)?

    private let listing: MarketListing
    private let buyButton = UIButton(type: .system)

    init(listing: MarketListing) {
        self.listing = listing
        super.init(frame: .zero)
        configure()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    private func configure() {
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 18
        layer.cornerCurve = .continuous

        let symbol = SocialMarketUI.label(
            listing.symbol,
            size: 36,
            weight: .regular
        )
        symbol.textAlignment = .center
        symbol.widthAnchor.constraint(
            equalToConstant: 52
        ).isActive = true

        let title = SocialMarketUI.label(
            listing.title,
            size: 15,
            weight: .bold
        )

        let category = SocialMarketUI.label(
            listing.category.uppercased(),
            size: 10,
            weight: .heavy,
            color: .secondaryLabel
        )

        let seller = SocialMarketUI.label(
            "Продавец: \(listing.seller)",
            size: 11,
            color: .secondaryLabel
        )

        let priceText: String
        if let usd = listing.priceUSD {
            priceText = String(
                format: "%.3f TON  ·  $%.2f",
                listing.priceTON,
                usd
            )
        } else {
            priceText = String(
                format: "%.3f TON",
                listing.priceTON
            )
        }

        let price = SocialMarketUI.label(
            priceText,
            size: 13,
            weight: .bold,
            color: SocialMarketUI.blue
        )

        let details = UIStackView(
            arrangedSubviews: [
                title,
                category,
                seller,
                price
            ]
        )
        details.axis = .vertical
        details.alignment = .leading
        details.spacing = 4

        buyButton.setTitle("Купить", for: .normal)
        buyButton.setTitleColor(.white, for: .normal)
        buyButton.backgroundColor = SocialMarketUI.blue
        buyButton.layer.cornerRadius = 11
        buyButton.titleLabel?.font = UIFont.systemFont(
            ofSize: 13,
            weight: .semibold
        )
        buyButton.contentEdgeInsets = UIEdgeInsets(
            top: 9,
            left: 15,
            bottom: 9,
            right: 15
        )
        buyButton.addTarget(
            self,
            action: #selector(buyPressed),
            for: .touchUpInside
        )

        let content = UIStackView(
            arrangedSubviews: [
                symbol,
                details,
                buyButton
            ]
        )
        content.axis = .horizontal
        content.alignment = .center
        content.spacing = 10
        content.translatesAutoresizingMaskIntoConstraints = false

        addSubview(content)

        NSLayoutConstraint.activate([
            content.topAnchor.constraint(
                equalTo: topAnchor,
                constant: 13
            ),
            content.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: 12
            ),
            content.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -12
            ),
            content.bottomAnchor.constraint(
                equalTo: bottomAnchor,
                constant: -13
            )
        ])
    }

    @objc private func buyPressed() {
        SocialMarketUI.feedback(.medium)
        onBuy?()
    }

    func setBuying(_ buying: Bool) {
        buyButton.isEnabled = !buying
        buyButton.setTitle(
            buying ? "Покупка…" : "Купить",
            for: .normal
        )
    }
}

// MARK: - Gift catalog card

private final class GiftCatalogCardView: UIView {
    var onBuyStars: (() -> Void)?
    var onBuyTON: (() -> Void)?

    private let gift: GiftCatalogItem
    private let starsButton = UIButton(type: .system)
    private let tonButton = UIButton(type: .system)

    init(gift: GiftCatalogItem) {
        self.gift = gift
        super.init(frame: .zero)
        configure()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    private func configure() {
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 18
        layer.cornerCurve = .continuous
        clipsToBounds = true

        let symbol = SocialMarketUI.label(
            gift.symbol,
            size: 39
        )
        symbol.textAlignment = .center

        let title = SocialMarketUI.label(
            gift.name,
            size: 14,
            weight: .bold
        )
        title.textAlignment = .center
        title.numberOfLines = 2

        let rarity = SocialMarketUI.label(
            gift.rarity.capitalized,
            size: 10,
            weight: .semibold,
            color: .secondaryLabel
        )
        rarity.textAlignment = .center

        let supply = SocialMarketUI.label(
            "Тираж: \(gift.supply)",
            size: 11,
            weight: .medium,
            color: .secondaryLabel
        )
        supply.textAlignment = .center

        let contentStack = UIStackView(
            arrangedSubviews: [
                symbol,
                title,
                rarity,
                supply
            ]
        )
        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.spacing = 6
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(contentStack)

        starsButton.setTitle(
            "⭐ \(gift.priceStars)",
            for: .normal
        )
        starsButton.setTitleColor(.white, for: .normal)
        starsButton.titleLabel?.font = UIFont.systemFont(
            ofSize: 12,
            weight: .bold
        )
        starsButton.backgroundColor = UIColor.systemOrange
        starsButton.layer.cornerRadius = 9
        starsButton.addTarget(
            self,
            action: #selector(starsPressed),
            for: .touchUpInside
        )

        tonButton.setTitle(
            String(format: "◈ %.3f", gift.priceTON),
            for: .normal
        )
        tonButton.setTitleColor(.white, for: .normal)
        tonButton.titleLabel?.font = UIFont.systemFont(
            ofSize: 12,
            weight: .bold
        )
        tonButton.backgroundColor = SocialMarketUI.blue
        tonButton.layer.cornerRadius = 9
        tonButton.addTarget(
            self,
            action: #selector(tonPressed),
            for: .touchUpInside
        )

        let buttons = UIStackView(
            arrangedSubviews: [starsButton, tonButton]
        )
        buttons.axis = .horizontal
        buttons.distribution = .fillEqually
        buttons.spacing = 6
        buttons.translatesAutoresizingMaskIntoConstraints = false

        addSubview(buttons)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(
                equalTo: topAnchor,
                constant: 13
            ),
            contentStack.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: 9
            ),
            contentStack.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -9
            ),

            buttons.topAnchor.constraint(
                equalTo: contentStack.bottomAnchor,
                constant: 11
            ),
            buttons.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: 9
            ),
            buttons.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -9
            ),
            buttons.heightAnchor.constraint(
                equalToConstant: 34
            ),
            buttons.bottomAnchor.constraint(
                equalTo: bottomAnchor,
                constant: -11
            )
        ])

        if gift.isExclusive {
            let badge = UILabel()
            badge.text = "ЭКСКЛЮЗИВНЫЙ"
            badge.font = UIFont.systemFont(
                ofSize: 8,
                weight: .heavy
            )
            badge.textColor = UIColor.black
            badge.backgroundColor = SocialMarketUI.gold
            badge.textAlignment = .center
            badge.layer.cornerRadius = 6
            badge.clipsToBounds = true
            badge.translatesAutoresizingMaskIntoConstraints = false

            addSubview(badge)

            NSLayoutConstraint.activate([
                badge.topAnchor.constraint(
                    equalTo: topAnchor,
                    constant: 7
                ),
                badge.trailingAnchor.constraint(
                    equalTo: trailingAnchor,
                    constant: -7
                ),
                badge.heightAnchor.constraint(
                    equalToConstant: 17
                ),
                badge.widthAnchor.constraint(
                    greaterThanOrEqualToConstant: 77
                )
            ])
        }
    }

    @objc private func starsPressed() {
        SocialMarketUI.feedback(.medium)
        onBuyStars?()
    }

    @objc private func tonPressed() {
        SocialMarketUI.feedback(.medium)
        onBuyTON?()
    }

    func setBuying(_ buying: Bool) {
        starsButton.isEnabled = !buying
        tonButton.isEnabled = !buying
        starsButton.alpha = buying ? 0.5 : 1
        tonButton.alpha = buying ? 0.5 : 1
    }
}

// MARK: - Confetti emitter

private final class GiftConfettiView: UIView {
    override class var layerClass: AnyClass {
        CAEmitterLayer.self
    }

    func start() {
        let emitter = layer as! CAEmitterLayer

        emitter.emitterPosition = CGPoint(
            x: bounds.midX,
            y: -10
        )

        emitter.emitterShape = .line
        emitter.emitterSize = CGSize(
            width: bounds.width,
            height: 1
        )

        let colors: [UIColor] = [
            .systemPink,
            .systemYellow,
            .systemGreen,
            .systemBlue,
            .systemPurple,
            .systemOrange
        ]

        let cells: [CAEmitterCell] = colors.map { color in
            let cell = CAEmitterCell()
            cell.birthRate = 5
            cell.lifetime = 3
            cell.velocity = 150
            cell.velocityRange = 60
            cell.emissionLongitude = .pi
            cell.emissionRange = .pi / 4
            cell.spin = 3
            cell.spinRange = 4
            cell.scale = 0.08
            cell.scaleRange = 0.05
            cell.color = color.cgColor
            cell.contents = Self.makeConfettiImage().cgImage
            return cell
        }

        emitter.emitterCells = cells

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            emitter.birthRate = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            self.removeFromSuperview()
        }
    }

    private static func makeConfettiImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: 10, height: 14)
        )

        return renderer.image { context in
            UIColor.white.setFill()
            context.cgContext.fill(
                CGRect(x: 0, y: 0, width: 10, height: 14)
            )
        }
    }
}

// MARK: - Fragment market and gifts controller

public final class FragmentMarketAndGiftsController: ViewController {
    private enum Section: Int {
        case market = 0
        case gifts = 1
    }

    private enum MarketCategory: Int {
        case numbers = 0
        case usernames = 1
        case nft = 2

        var apiValue: String {
            switch self {
            case .numbers:
                return "numbers"
            case .usernames:
                return "usernames"
            case .nft:
                return "nft"
            }
        }

        var title: String {
            switch self {
            case .numbers:
                return "Номера"
            case .usernames:
                return "Юзы"
            case .nft:
                return "NFT"
            }
        }
    }

    private let theme: PresentationTheme
    private let userId: Int

    private let sectionControl = UISegmentedControl(
        items: [
            "Маркет",
            "Каталог подарков"
        ]
    )

    private let categoryControl = UISegmentedControl(
        items: [
            "Номера",
            "Юзы",
            "NFT"
        ]
    )

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let loadingIndicator = UIActivityIndicatorView(
        style: .medium
    )

    private var section: Section = .market
    private var marketCategory: MarketCategory = .numbers
    private var listings: [MarketListing] = []
    private var gifts: [GiftCatalogItem] = []

    public init(
        theme: PresentationTheme,
        userId: Int
    ) {
        self.theme = theme
        self.userId = userId

        super.init(
            navigationBarPresentationData: socialMarketNavigationData(
                theme: theme
            )
        )

        self.title = "Маркет и подарки"
    }

    required init?(coder: NSCoder) {
        return nil
    }

    public override func displayNodeDidLoad() {
        super.displayNodeDidLoad()

        displayNode.backgroundColor = theme.list.blocksBackgroundColor

        let root = displayNode.view

        sectionControl.selectedSegmentIndex = Section.market.rawValue
        sectionControl.addTarget(
            self,
            action: #selector(sectionChanged),
            for: .valueChanged
        )
        sectionControl.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(sectionControl)

        categoryControl.selectedSegmentIndex = MarketCategory.numbers.rawValue
        categoryControl.addTarget(
            self,
            action: #selector(categoryChanged),
            for: .valueChanged
        )
        categoryControl.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(categoryControl)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        root.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.spacing = 12
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.hidesWhenStopped = true
        root.addSubview(loadingIndicator)

        NSLayoutConstraint.activate([
            sectionControl.topAnchor.constraint(
                equalTo: root.safeAreaLayoutGuide.topAnchor,
                constant: 11
            ),
            sectionControl.leadingAnchor.constraint(
                equalTo: root.leadingAnchor,
                constant: 12
            ),
            sectionControl.trailingAnchor.constraint(
                equalTo: root.trailingAnchor,
                constant: -12
            ),

            categoryControl.topAnchor.constraint(
                equalTo: sectionControl.bottomAnchor,
                constant: 10
            ),
            categoryControl.leadingAnchor.constraint(
                equalTo: root.leadingAnchor,
                constant: 12
            ),
            categoryControl.trailingAnchor.constraint(
                equalTo: root.trailingAnchor,
                constant: -12
            ),

            scrollView.topAnchor.constraint(
                equalTo: categoryControl.bottomAnchor,
                constant: 12
            ),
            scrollView.leadingAnchor.constraint(
                equalTo: root.leadingAnchor,
                constant: 13
            ),
            scrollView.trailingAnchor.constraint(
                equalTo: root.trailingAnchor,
                constant: -13
            ),
            scrollView.bottomAnchor.constraint(
                equalTo: root.bottomAnchor
            ),

            contentStack.topAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.topAnchor
            ),
            contentStack.leadingAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.leadingAnchor
            ),
            contentStack.trailingAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.trailingAnchor
            ),
            contentStack.bottomAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.bottomAnchor,
                constant: -22
            ),

            loadingIndicator.centerXAnchor.constraint(
                equalTo: root.centerXAnchor
            ),
            loadingIndicator.centerYAnchor.constraint(
                equalTo: root.centerYAnchor
            )
        ])

        updateControls()
        loadCurrentSection()
    }

    @objc private func sectionChanged() {
        guard let newSection = Section(
            rawValue: sectionControl.selectedSegmentIndex
        ) else {
            return
        }

        SocialMarketUI.feedback()
        section = newSection
        updateControls()
        loadCurrentSection()
    }

    @objc private func categoryChanged() {
        guard let category = MarketCategory(
            rawValue: categoryControl.selectedSegmentIndex
        ) else {
            return
        }

        SocialMarketUI.feedback()
        marketCategory = category
        loadListings()
    }

    private func updateControls() {
        categoryControl.isHidden = section == .gifts
    }

    private func loadCurrentSection() {
        switch section {
        case .market:
            loadListings()
        case .gifts:
            loadGiftCatalog()
        }
    }

    private func clearContent() {
        for view in contentStack.arrangedSubviews {
            contentStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
    }

    private func loadListings() {
        loadingIndicator.startAnimating()

        SocialMarketAPI.request(
            path: "market/listings",
            method: "GET",
            userId: userId,
            query: [
                "category": marketCategory.apiValue
            ]
        ) { [weak self] result in
            guard let self else { return }

            self.loadingIndicator.stopAnimating()

            switch result {
            case let .success(response):
                let rawListings = SocialMarketUI.array(
                    response["listings"] ??
                    response["items"] ??
                    response["lots"]
                )

                self.listings = rawListings.map {
                    MarketListing(dictionary: $0)
                }

                self.renderListings()

            case let .failure(error):
                self.listings = []
                self.renderListings()

                SocialMarketUI.showAlert(
                    on: self,
                    title: "Маркет",
                    message: "Не удалось загрузить лоты: \(error.localizedDescription)"
                )
            }
        }
    }

    private func renderListings() {
        clearContent()

        let heading = SocialMarketUI.label(
            "Маркет · \(marketCategory.title)",
            size: 19,
            weight: .bold
        )
        contentStack.addArrangedSubview(heading)

        if listings.isEmpty {
            let empty = SocialMarketUI.label(
                "Активных лотов пока нет.",
                size: 14,
                color: .secondaryLabel
            )
            empty.textAlignment = .center
            empty.heightAnchor.constraint(
                greaterThanOrEqualToConstant: 100
            ).isActive = true
            contentStack.addArrangedSubview(empty)
            return
        }

        for listing in listings {
            let card = MarketListingView(listing: listing)

            card.onBuy = { [weak self, weak card] in
                guard let self, let card else { return }
                self.buyListing(listing, card: card)
            }

            contentStack.addArrangedSubview(card)
        }
    }

    private func buyListing(
        _ listing: MarketListing,
        card: MarketListingView
    ) {
        guard !listing.id.isEmpty else {
            SocialMarketUI.showAlert(
                on: self,
                title: "Покупка",
                message: "В ответе сервера отсутствует ID лота."
            )
            return
        }

        card.setBuying(true)

        SocialMarketAPI.request(
            path: "market/buy",
            method: "POST",
            userId: userId,
            body: [
                "listing_id": listing.id
            ]
        ) { [weak self, weak card] result in
            guard let self, let card else { return }

            card.setBuying(false)

            switch result {
            case let .success(response):
                let message = SocialMarketUI.string(
                    response["message"],
                    default: "Покупка успешно обработана."
                )

                SocialMarketUI.showAlert(
                    on: self,
                    title: "Маркет",
                    message: message
                )

                self.loadListings()

            case let .failure(error):
                SocialMarketUI.showAlert(
                    on: self,
                    title: "Не удалось купить",
                    message: error.localizedDescription
                )
            }
        }
    }

    private func loadGiftCatalog() {
        loadingIndicator.startAnimating()

        SocialMarketAPI.request(
            path: "gifts/catalog",
            method: "GET",
            userId: userId
        ) { [weak self] result in
            guard let self else { return }

            self.loadingIndicator.stopAnimating()

            switch result {
            case let .success(response):
                let rawGifts = SocialMarketUI.array(
                    response["gifts"] ??
                    response["items"] ??
                    response["catalog"]
                )

                self.gifts = rawGifts.map {
                    GiftCatalogItem(dictionary: $0)
                }

                self.renderGiftCatalog()

            case let .failure(error):
                self.gifts = []
                self.renderGiftCatalog()

                SocialMarketUI.showAlert(
                    on: self,
                    title: "Каталог подарков",
                    message: "Не удалось загрузить каталог: \(error.localizedDescription)"
                )
            }
        }
    }

    private func renderGiftCatalog() {
        clearContent()

        let heading = SocialMarketUI.label(
            "Каталог подарков",
            size: 19,
            weight: .bold
        )
        contentStack.addArrangedSubview(heading)

        let subtitle = SocialMarketUI.label(
            "Выберите подарок и способ оплаты.",
            size: 12,
            color: .secondaryLabel
        )
        contentStack.addArrangedSubview(subtitle)

        if gifts.isEmpty {
            let empty = SocialMarketUI.label(
                "Подарки пока не добавлены.",
                size: 14,
                color: .secondaryLabel
            )
            empty.textAlignment = .center
            empty.heightAnchor.constraint(
                greaterThanOrEqualToConstant: 100
            ).isActive = true
            contentStack.addArrangedSubview(empty)
            return
        }

        let grid = UIStackView()
        grid.axis = .vertical
        grid.alignment = .fill
        grid.spacing = 10

        var index = 0

        while index < gifts.count {
            let row = UIStackView()
            row.axis = .horizontal
            row.alignment = .fill
            row.distribution = .fillEqually
            row.spacing = 10

            for offset in 0 ..< 2 {
                let itemIndex = index + offset

                if itemIndex < gifts.count {
                    let gift = gifts[itemIndex]
                    let card = GiftCatalogCardView(gift: gift)

                    card.onBuyStars = { [weak self, weak card] in
                        guard let self, let card else { return }
                        self.buyGift(
                            gift,
                            currency: "stars",
                            card: card
                        )
                    }

                    card.onBuyTON = { [weak self, weak card] in
                        guard let self, let card else { return }
                        self.buyGift(
                            gift,
                            currency: "ton",
                            card: card
                        )
                    }

                    row.addArrangedSubview(card)
                } else {
                    let spacer = UIView()
                    spacer.backgroundColor = .clear
                    row.addArrangedSubview(spacer)
                }
            }

            grid.addArrangedSubview(row)
            index += 2
        }

        contentStack.addArrangedSubview(grid)
    }

    private func buyGift(
        _ gift: GiftCatalogItem,
        currency: String,
        card: GiftCatalogCardView
    ) {
        guard !gift.id.isEmpty else {
            SocialMarketUI.showAlert(
                on: self,
                title: "Покупка подарка",
                message: "В каталоге отсутствует ID подарка."
            )
            return
        }

        card.setBuying(true)

        SocialMarketAPI.request(
            path: "gifts/buy",
            method: "POST",
            userId: userId,
            body: [
                "gift_id": gift.id,
                "currency": currency
            ]
        ) { [weak self, weak card] result in
            guard let self, let card else { return }

            card.setBuying(false)

            switch result {
            case let .success(response):
                let delivered = SocialMarketUI.bool(
                    response["delivered"],
                    default: true
                )

                let message = SocialMarketUI.string(
                    response["message"],
                    default: delivered
                        ? "Подарок отправлен в системный чат Telegram."
                        : "Покупка обработана сервером."
                )

                self.showGiftDelivery(message: message)

                self.loadGiftCatalog()

            case let .failure(error):
                SocialMarketUI.showAlert(
                    on: self,
                    title: "Ошибка покупки",
                    message: error.localizedDescription
                )
            }
        }
    }

    private func showGiftDelivery(message: String) {
        let confetti = GiftConfettiView()
        confetti.translatesAutoresizingMaskIntoConstraints = false
        confetti.isUserInteractionEnabled = false
        confetti.backgroundColor = .clear

        view.addSubview(confetti)

        NSLayoutConstraint.activate([
            confetti.topAnchor.constraint(
                equalTo: view.topAnchor
            ),
            confetti.leadingAnchor.constraint(
                equalTo: view.leadingAnchor
            ),
            confetti.trailingAnchor.constraint(
                equalTo: view.trailingAnchor
            ),
            confetti.bottomAnchor.constraint(
                equalTo: view.bottomAnchor
            )
        ])

        confetti.start()

        let alert = UIAlertController(
            title: "🎉 Подарок отправлен!",
            message: message,
            preferredStyle: .alert
        )

        alert.addAction(
            UIAlertAction(title: "Отлично", style: .default)
        )

        present(alert, animated: true)
    }
}