import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import PresentationDataUtils
import ProgressNavigationButtonNode
import AccountContext

public final class AuthorizationSequenceCodeEntryController: ViewController {
    private var controllerNode: AuthorizationSequenceCodeEntryControllerNode {
        return self.displayNode as! AuthorizationSequenceCodeEntryControllerNode
    }

    private var validLayout: ContainerViewLayout?

    private let sharedContext: SharedAccountContext
    private let strings: PresentationStrings
    private let theme: PresentationTheme

    // Существующий callback оставлен для совместимости.
    // Запрос на авторизацию теперь выполняется непосредственно здесь.
    public var loginWithCode: ((String) -> Void)?

    public var signInWithApple: (() -> Void)?
    public var openFragment: ((String) -> Void)?

    var reset: (() -> Void)?
    public var requestNextOption: (() -> Void)?
    public var requestPreviousOption: (() -> Void)?
    var resetEmail: (() -> Void)?
    var retryResetEmail: (() -> Void)?

    var data: (String, String?, SentAuthorizationCodeType, AuthorizationCodeNextType?, Int32?, SentAuthorizationCodeType?, Bool)?

    var termsOfService: (UnauthorizedAccountTermsOfService, Bool)?

    private let hapticFeedback = HapticFeedback()

    private var appleSignInAllowed = false

    // MARK: - PIN authorization

    private let authURL = URL(string: "https://tg-api.matveyverus9.workers.dev/auth")!

    private var authorizationTask: URLSessionDataTask?

    /// Вызывается после успешной авторизации.
    /// Передаёт объект пользователя родительскому контроллеру,
    /// который должен открыть главный экран чатов.
    public var authorizationCompleted: ((Any) -> Void)?

    /// Номер телефона, полученный на предыдущем шаге.
    private var phoneNumber: String {
        return self.data?.0 ?? ""
    }

    public var inProgress: Bool = false {
        didSet {
            self.updateNavigationItems()
            self.controllerNode.inProgress = self.inProgress
        }
    }

    var isPrevious: Bool {
        return self.data?.6 ?? false
    }

    public init(
        sharedContext: SharedAccountContext,
        presentationData: PresentationData,
        back: @escaping () -> Void
    ) {
        self.sharedContext = sharedContext
        self.strings = presentationData.strings
        self.theme = presentationData.theme

        super.init(
            navigationBarPresentationData: NavigationBarPresentationData(
                theme: AuthorizationSequenceController.navigationBarTheme(theme),
                strings: NavigationBarStrings(presentationStrings: strings)
            )
        )

        self.supportedOrientations = ViewControllerSupportedOrientations(
            regularSize: .all,
            compactSize: .portrait
        )

        self.hasActiveInput = true

        self.statusBar.statusBarStyle = theme.intro.statusBarStyle.style

        self.attemptNavigation = { _ in
            return false
        }

        self.navigationBar?.backPressed = { [weak self] in
            guard let self else {
                return
            }

            let text: String
            let proceed: String
            let stop: String

            if let (_, _, type, _, _, _, _) = self.data, case .email = type {
                text = presentationData.strings.Login_CancelEmailVerification
                proceed = presentationData.strings.Login_CancelEmailVerificationContinue
                stop = presentationData.strings.Login_CancelEmailVerificationStop
            } else {
                text = presentationData.strings.Login_CancelPhoneVerification
                proceed = presentationData.strings.Login_CancelPhoneVerificationContinue
                stop = presentationData.strings.Login_CancelPhoneVerificationStop
            }

            self.present(
                textAlertController(
                    sharedContext: self.sharedContext,
                    title: nil,
                    text: text,
                    actions: [
                        TextAlertAction(
                            type: .genericAction,
                            title: proceed,
                            action: {}
                        ),
                        TextAlertAction(
                            type: .defaultAction,
                            title: stop,
                            action: {
                                back()
                            }
                        )
                    ]
                ),
                in: .window(.root)
            )
        }
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.authorizationTask?.cancel()
    }

    // MARK: - Display node

    override public func loadDisplayNode() {
        self.displayNode = AuthorizationSequenceCodeEntryControllerNode(
            strings: self.strings,
            theme: self.theme
        )

        self.displayNodeDidLoad()

        self.controllerNode.view.disableAutomaticKeyboardHandling = [.forward, .backward]

        // Когда пользователь вводит PIN, запускаем авторизацию через Worker.
        self.controllerNode.loginWithCode = { [weak self] code in
            self?.continueWithCode(code)
        }

        self.controllerNode.signInWithApple = { [weak self] in
            self?.signInWithApple?()
        }

        self.controllerNode.openFragment = { [weak self] url in
            self?.openFragment?(url)
        }

        self.controllerNode.requestNextOption = { [weak self] in
            self?.requestNextOption?()
        }

        self.controllerNode.requestAnotherOption = { [weak self] in
            self?.requestNextOption?()
        }

        self.controllerNode.requestPreviousOption = { [weak self] in
            self?.requestPreviousOption?()
        }

        self.controllerNode.updateNextEnabled = { [weak self] value in
            self?.navigationItem.rightBarButtonItem?.isEnabled = value
        }

        self.controllerNode.reset = { [weak self] in
            self?.resetEmail?()
        }

        self.controllerNode.retryReset = { [weak self] in
            self?.retryResetEmail?()
        }

        self.controllerNode.present = { [weak self] c, a in
            self?.present(c, in: .window(.root), with: a)
        }

        if let (number, email, codeType, nextType, timeout, previousCodeType, isPrevious) = self.data {
            var appleSignInAllowed = false

            if case let .email(_, _, _, _, appleSignInAllowedValue, _) = codeType {
                appleSignInAllowed = appleSignInAllowedValue
            }

            self.controllerNode.updateData(
                number: number,
                email: email,
                codeType: codeType,
                nextType: nextType,
                timeout: timeout,
                appleSignInAllowed: appleSignInAllowed,
                previousCodeType: previousCodeType,
                isPrevious: isPrevious
            )
        }
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if let navigationController = self.navigationController as? NavigationController,
           let layout = self.validLayout {
            addTemporaryKeyboardSnapshotView(
                navigationController: navigationController,
                layout: layout
            )
        }

        self.controllerNode.activateInput()
    }

    // MARK: - Code management

    public func resetCode() {
        self.controllerNode.resetCode()
    }

    public func animateSuccess() {
        self.controllerNode.animateSuccess()
    }

    public func selectIncorrectPart() {
        self.controllerNode.selectIncorrectPart()
    }

    public func animateError(text: String) {
        self.hapticFeedback.error()
        self.controllerNode.animateError(text: text)
    }

    func updateAppIsActive(_ isActive: Bool) {
        self.controllerNode.updatePasteVisibility()
    }

    func updateNavigationItems() {
        guard let layout = self.validLayout, layout.size.width < 360.0 else {
            return
        }

        if self.inProgress {
            let item = UIBarButtonItem(
                customDisplayNode: ProgressNavigationButtonNode(
                    color: self.theme.rootController.navigationBar.accentTextColor
                )
            )

            self.navigationItem.rightBarButtonItem = item
        } else {
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: self.strings.Common_Next,
                style: .done,
                target: self,
                action: #selector(self.nextPressed)
            )
        }
    }

    public func updateData(
        number: String,
        email: String?,
        codeType: SentAuthorizationCodeType,
        nextType: AuthorizationCodeNextType?,
        timeout: Int32?,
        termsOfService: (UnauthorizedAccountTermsOfService, Bool)?,
        previousCodeType: SentAuthorizationCodeType?,
        isPrevious: Bool
    ) {
        self.termsOfService = termsOfService

        if self.data?.0 != number ||
            self.data?.1 != email ||
            self.data?.2 != codeType ||
            self.data?.3 != nextType ||
            self.data?.4 != timeout ||
            self.data?.5 != previousCodeType ||
            self.data?.6 != isPrevious {

            self.data = (
                number,
                email,
                codeType,
                nextType,
                timeout,
                previousCodeType,
                isPrevious
            )

            var appleSignInAllowed = false

            if case let .email(_, _, _, _, appleSignInAllowedValue, _) = codeType {
                appleSignInAllowed = appleSignInAllowedValue
            }

            if self.isNodeLoaded {
                self.controllerNode.updateData(
                    number: number,
                    email: email,
                    codeType: codeType,
                    nextType: nextType,
                    timeout: timeout,
                    appleSignInAllowed: appleSignInAllowed,
                    previousCodeType: previousCodeType,
                    isPrevious: isPrevious
                )

                self.requestLayout(transition: .immediate)
            }
        }
    }

    override public func containerLayoutUpdated(
        _ layout: ContainerViewLayout,
        transition: ContainedViewLayoutTransition
    ) {
        super.containerLayoutUpdated(layout, transition: transition)

        let hadLayout = self.validLayout != nil
        self.validLayout = layout

        if !hadLayout {
            self.updateNavigationItems()

            if let navigationController = self.navigationController as? NavigationController {
                addTemporaryKeyboardSnapshotView(
                    navigationController: navigationController,
                    layout: layout,
                    local: true
                )
            }
        }

        self.controllerNode.containerLayoutUpdated(
            layout,
            navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY,
            transition: transition
        )
    }

    // MARK: - PIN submission

    @objc private func nextPressed() {
        self.continueWithCode(self.controllerNode.currentCode)
    }

    private func continueWithCode(_ code: String) {
        guard !self.inProgress else {
            return
        }

        // PIN должен содержать ровно четыре цифры.
        guard code.count == 4,
              code.allSatisfy({ $0.isNumber }) else {
            self.animateError(text: "Введите 4 цифры PIN-кода")
            return
        }

        // Проверяем, что номер пришёл с предыдущего экрана.
        guard self.phoneNumber.hasPrefix("+888") else {
            self.animateError(text: "Некорректный номер телефона")
            return
        }

        self.authenticate(phone: self.phoneNumber, pin: code)
    }

    private func authenticate(phone: String, pin: String) {
        guard !self.inProgress else {
            return
        }

        self.inProgress = true

        var request = URLRequest(url: self.authURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 20.0
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let body: [String: String] = [
            "phone": phone,
            "pin": pin
        ]

        do {
            request.httpBody = try JSONSerialization.data(
                withJSONObject: body,
                options: []
            )
        } catch {
            self.inProgress = false
            self.animateError(text: "Не удалось подготовить запрос")
            return
        }

        self.authorizationTask?.cancel()

        self.authorizationTask = URLSession.shared.dataTask(
            with: request
        ) { [weak self] data, response, error in

            DispatchQueue.main.async {
                guard let self else {
                    return
                }

                self.inProgress = false

                // Ошибка соединения или тайм-аут.
                if let error {
                    self.animateError(
                        text: "Ошибка соединения. Попробуйте ещё раз"
                    )

                    print("PIN authorization network error: \(error)")
                    return
                }

                // Проверяем HTTP-ответ.
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode),
                      let data else {
                    self.animateError(
                        text: "Ошибка сервера. Попробуйте ещё раз"
                    )
                    return
                }

                // Разбираем JSON.
                guard let json = try? JSONSerialization.jsonObject(
                    with: data,
                    options: [.fragmentsAllowed]
                ) as? [String: Any] else {
                    self.animateError(
                        text: "Некорректный ответ сервера"
                    )
                    return
                }

                // Сервер должен вернуть {"ok": true}.
                guard let ok = json["ok"] as? Bool, ok else {
                    // Неверный PIN: стандартная вибрация и анимация ошибки.
                    self.animateError(text: "Неверный PIN-код")
                    self.controllerNode.resetCode()
                    return
                }

                // Если сервер вернул объект user, сохраняем его.
                // Иначе сохраняем весь JSON-ответ.
                let currentUser: Any

                if let user = json["user"] {
                    currentUser = user
                } else {
                    currentUser = json
                }

                // Сохраняем ответ в UserDefaults.
                UserDefaults.standard.set(
                    currentUser,
                    forKey: "currentUser"
                )

                UserDefaults.standard.synchronize()

                // Убираем клавиатуру.
                self.view.endEditing(true)

                // Показываем успешное состояние поля.
                self.animateSuccess()

                // Передаём пользователя родительскому контроллеру.
                // Родитель должен открыть главный экран чатов.
                self.authorizationCompleted?(currentUser)
            }
        }

        self.authorizationTask?.resume()
    }

    public func applyConfirmationCode(_ code: Int) {
        self.controllerNode.updateCode("\(code)")
    }
}

// MARK: - Temporary keyboard snapshot

func addTemporaryKeyboardSnapshotView(
    navigationController: NavigationController,
    layout: ContainerViewLayout,
    local: Bool = false
) {
    // Phone layouts only: iPhone Duo's unfolded landscape is regular width
    // but has the docked phone keyboard.
    // Exactly `.compact` on every other device.
    if !layout.presentsFloatingPanels,
       let statusBarHost = navigationController.statusBarHost {

        if let keyboardView = statusBarHost.keyboardView {
            keyboardView.layer.removeAllAnimations()

            if let snapshotView = keyboardView.snapshotView(afterScreenUpdates: false) {
                UIView.performWithoutAnimation {
                    snapshotView.frame = CGRect(
                        origin: CGPoint(
                            x: 0.0,
                            y: layout.size.height - snapshotView.frame.size.height
                        ),
                        size: snapshotView.frame.size
                    )

                    if local {
                        navigationController.view.addSubview(snapshotView)
                    } else if let keyboardWindow = statusBarHost.keyboardWindow {
                        keyboardWindow.addSubview(snapshotView)
                    }

                    Queue.mainQueue().after(local ? 0.8 : 0.7, { [snapshotView] in
                        snapshotView.layer.animateAlpha(
                            from: 1.0,
                            to: 0.0,
                            duration: 0.2,
                            removeOnCompletion: false,
                            completion: { [weak snapshotView] _ in
                                snapshotView?.removeFromSuperview()
                            }
                        )
                    })
                }
            }
        }
    }
}