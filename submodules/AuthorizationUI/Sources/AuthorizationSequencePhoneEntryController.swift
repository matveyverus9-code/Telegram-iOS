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
import CountrySelectionUI
import PhoneNumberFormat
import DebugSettingsUI
import MessageUI
import AuthenticationServices

public final class AuthorizationSequencePhoneEntryController: ViewController, MFMailComposeViewControllerDelegate, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var controllerNode: AuthorizationSequencePhoneEntryControllerNode {
        return self.displayNode as! AuthorizationSequencePhoneEntryControllerNode
    }

    private var validLayout: ContainerViewLayout?

    private let sharedContext: SharedAccountContext
    private var account: UnauthorizedAccount?
    private let apiId: Int32
    private let apiHash: String
    private let isTestingEnvironment: Bool
    private let otherAccountPhoneNumbers: ((String, AccountRecordId, Bool)?, [(String, AccountRecordId, Bool)])
    private let network: Network
    private let presentationData: PresentationData
    private let openUrl: (String) -> Void

    private let back: () -> Void

    private var currentData: (Int32, String?, String)?

    var codeNode: ASDisplayNode {
        return self.controllerNode.codeNode
    }

    var numberNode: ASDisplayNode {
        return self.controllerNode.numberNode
    }

    var buttonNode: ASDisplayNode {
        return self.controllerNode.buttonNode
    }

    public var inProgress: Bool = false {
        didSet {
            self.updateNavigationItems()
            self.controllerNode.inProgress = self.inProgress
            self.confirmationController?.inProgress = self.inProgress
        }
    }

    public var loginWithNumber: ((String, Bool) -> Void)?

    /// Receives the collection phone number and the locally entered 4-digit PIN.
    public var loginWithPin: ((String, String) -> Void)?

    public var loginWithPasskey: ((AuthorizationPasskeyData, Bool) -> Void)?
    var accountUpdated: ((UnauthorizedAccount) -> Void)?

    weak var confirmationController: PhoneConfirmationController?

    private let termsDisposable = MetaDisposable()

    private let hapticFeedback = HapticFeedback()

    public init(
        sharedContext: SharedAccountContext,
        account: UnauthorizedAccount?,
        countriesConfiguration: CountriesConfiguration? = nil,
        apiId: Int32,
        apiHash: String,
        isTestingEnvironment: Bool,
        otherAccountPhoneNumbers: ((String, AccountRecordId, Bool)?, [(String, AccountRecordId, Bool)]),
        network: Network,
        presentationData: PresentationData,
        openUrl: @escaping (String) -> Void,
        back: @escaping () -> Void
    ) {
        self.sharedContext = sharedContext
        self.account = account
        self.apiId = apiId
        self.apiHash = apiHash
        self.isTestingEnvironment = isTestingEnvironment
        self.otherAccountPhoneNumbers = otherAccountPhoneNumbers
        self.network = network
        self.presentationData = presentationData
        self.openUrl = openUrl
        self.back = back

        super.init(
            navigationBarPresentationData: NavigationBarPresentationData(
                theme: AuthorizationSequenceController.navigationBarTheme(presentationData.theme),
                strings: NavigationBarStrings(presentationStrings: presentationData.strings)
            )
        )

        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)

        self.hasActiveInput = true

        self.statusBar.statusBarStyle = presentationData.theme.intro.statusBarStyle.style

        self.attemptNavigation = { _ in
            return false
        }

        self.navigationBar?.backPressed = {
            back()
        }

        if !otherAccountPhoneNumbers.1.isEmpty {
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(
                title: "___close",
                style: .plain,
                target: self,
                action: #selector(self.cancelPressed)
            )
        }

        if let countriesConfiguration {
            AuthorizationSequenceCountrySelectionController.setupCountryCodes(
                countries: countriesConfiguration.countries,
                codesByPrefix: countriesConfiguration.countriesByPrefix
            )
        }
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.termsDisposable.dispose()
    }

    @objc private func cancelPressed() {
        self.back()
    }

    func updateNavigationItems() {
        guard let layout = self.validLayout, layout.size.width < 360.0 else {
            return
        }

        if self.inProgress {
            let item = UIBarButtonItem(
                customDisplayNode: ProgressNavigationButtonNode(
                    color: self.presentationData.theme.rootController.navigationBar.accentTextColor
                )
            )
            self.navigationItem.rightBarButtonItem = item
        } else {
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: self.presentationData.strings.Common_Next,
                style: .done,
                target: self,
                action: #selector(self.nextPressed)
            )
        }
    }

    public func updateData(countryCode: Int32, countryName: String?, number: String) {
        self.currentData = (countryCode, countryName, number)

        if self.isNodeLoaded {
            self.controllerNode.codeAndNumber = (countryCode, countryName, number)
        }
    }

    private var shouldAnimateIn = false

    private var transitionInArguments: (
        buttonFrame: CGRect,
        buttonTitle: String,
        animationSnapshot: UIView,
        textSnapshot: UIView
    )?

    func animateWithSplashController(_ controller: AuthorizationSequenceSplashController) {
        self.shouldAnimateIn = true

        if let animationSnapshot = controller.animationSnapshot,
           let textSnapshot = controller.textSnaphot {
            self.transitionInArguments = (
                controller.buttonFrame,
                controller.buttonTitle,
                animationSnapshot,
                textSnapshot
            )
        }
    }

    override public func loadDisplayNode() {
        self.displayNode = AuthorizationSequencePhoneEntryControllerNode(
            sharedContext: self.sharedContext,
            account: self.account,
            strings: self.presentationData.strings,
            theme: self.presentationData.theme,
            debugAction: { [weak self] in
                guard let strongSelf = self else {
                    return
                }

                strongSelf.view.endEditing(true)

                self?.present(
                    debugController(
                        sharedContext: strongSelf.sharedContext,
                        context: nil,
                        modal: true
                    ),
                    in: .window(.root),
                    with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet)
                )
            },
            hasOtherAccounts: self.otherAccountPhoneNumbers.0 != nil
        )

        self.controllerNode.accountUpdated = { [weak self] account in
            guard let strongSelf = self else {
                return
            }

            strongSelf.account = account
            strongSelf.accountUpdated?(account)
        }

        self.controllerNode.retryPasskey = { [weak self] in
            guard let self else {
                return
            }

            self.loadAndPresentPasskey(force: true)
        }

        if let (code, name, number) = self.currentData {
            self.controllerNode.codeAndNumber = (code, name, number)
        }

        self.displayNodeDidLoad()

        self.controllerNode.view.disableAutomaticKeyboardHandling = [.forward, .backward]

        self.controllerNode.selectCountryCode = { [weak self] in
            guard let strongSelf = self else {
                return
            }

            let controller = AuthorizationSequenceCountrySelectionController(
                strings: strongSelf.presentationData.strings,
                theme: strongSelf.presentationData.theme,
                glass: true
            )

            controller.completeWithCountryCode = { code, name in
                guard let strongSelf = self,
                      let currentData = strongSelf.currentData else {
                    return
                }

                strongSelf.updateData(
                    countryCode: Int32(code),
                    countryName: name,
                    number: currentData.2
                )

                strongSelf.controllerNode.activateInput()
            }

            controller.dismissed = {
                self?.controllerNode.activateInput()
            }

            strongSelf.push(controller)
        }

        // Подключаем callback из обновлённого PhoneEntryNode.
        // При нажатии Next открываем экран локального PIN-кода.
        self.controllerNode.continueWithPhone = { [weak self] phoneNumber in
            self?.presentPinEntry(phoneNumber: phoneNumber)
        }

        // Резервный путь для действий, которые вызывают checkPhone.
        self.controllerNode.checkPhone = { [weak self] in
            guard let self else {
                return
            }

            self.presentPinEntry(phoneNumber: self.controllerNode.currentNumber)
        }

        if let account = self.account {
            loadServerCountryCodes(
                accountManager: sharedContext.accountManager,
                engine: TelegramEngineUnauthorized(account: account),
                completion: { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }

                    strongSelf.controllerNode.updateCountryCode()
                }
            )
        } else {
            self.controllerNode.updateCountryCode()
        }

        self.loadAndPresentPasskey(force: false)
    }

    private func loadAndPresentPasskey(force: Bool) {
        if #available(iOS 16.0, *) {
            Task { @MainActor [weak self] in
                guard let self, let account = self.account else {
                    return
                }

                let decodeBase64: (String) -> Data? = { string in
                    var string = string
                        .replacingOccurrences(of: "-", with: "+")
                        .replacingOccurrences(of: "_", with: "/")

                    while string.count % 4 != 0 {
                        string.append("=")
                    }

                    return Data(base64Encoded: string)
                }

                let engine = TelegramEngineUnauthorized(account: account)

                let passkeyDataString = await engine.auth.requestPasskeyLoginData(
                    apiId: self.apiId,
                    apiHash: self.apiHash
                ).get()

                guard let passkeyDataString,
                      let passkeyData = passkeyDataString.data(using: .utf8) else {
                    return
                }

                guard let params = try? JSONSerialization.jsonObject(with: passkeyData) as? [String: Any] else {
                    return
                }

                guard let pkDict = params["publicKey"] as? [String: Any] else {
                    return
                }

                guard let relyingPartyIdentifier = pkDict["rpId"] as? String else {
                    return
                }

                guard let challengeBase64 = pkDict["challenge"] as? String else {
                    return
                }

                guard let challengeData = decodeBase64(challengeBase64) else {
                    return
                }

                let platformProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(
                    relyingPartyIdentifier: relyingPartyIdentifier
                )

                let platformKeyRequest = platformProvider.createCredentialAssertionRequest(
                    challenge: challengeData
                )

                let authController = ASAuthorizationController(
                    authorizationRequests: [platformKeyRequest]
                )

                authController.delegate = self
                authController.presentationContextProvider = self

                if force {
                    authController.performRequests()
                } else {
                    authController.performRequests(options: [.preferImmediatelyAvailableCredentials])
                }
            }
        }
    }

    public func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor [weak self] in
            guard let self, let account = self.account else {
                return
            }

            let encodeBase64URL: (Data) -> String = { data in
                var string = data.base64EncodedString()

                string = string
                    .replacingOccurrences(of: "+", with: "-")
                    .replacingOccurrences(of: "/", with: "_")

                string = string.replacingOccurrences(of: "=", with: "")
                return string
            }

            if #available(iOS 17.0, *) {
                if let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion {
                    guard let clientData = String(
                        data: credential.rawClientDataJSON,
                        encoding: .utf8
                    ) else {
                        return
                    }

                    guard let userHandle = String(
                        data: credential.userID,
                        encoding: .utf8
                    ) else {
                        return
                    }

                    let passkey = AuthorizationPasskeyData(
                        id: encodeBase64URL(credential.credentialID),
                        clientData: clientData,
                        authenticatorData: credential.rawAuthenticatorData,
                        signature: credential.signature,
                        userHandle: userHandle
                    )

                    self.loginWithPasskey?(passkey, self.controllerNode.syncContacts)

                    let _ = account
                    let _ = credential
                }
            }
        }
    }

    public func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: any Error
    ) {
        if (error as NSError).domain == "com.apple.AuthenticationServices.AuthorizationError"
            && (error as NSError).code == 1001 {
            self.controllerNode.updateDisplayPasskeyLoginOption()

            if let validLayout = self.validLayout {
                self.containerLayoutUpdated(validLayout, transition: .immediate)
            }
        }
    }

    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = self.view.window?.windowScene else {
            preconditionFailure()
        }

        return ASPresentationAnchor(windowScene: windowScene)
    }

    public func updateCountryCode() {
        self.controllerNode.updateCountryCode()
    }

    private var animatingIn = false

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if self.shouldAnimateIn {
            self.animatingIn = true

            if let (buttonFrame, buttonTitle, animationSnapshot, textSnapshot) = self.transitionInArguments {
                self.controllerNode.willAnimateIn(
                    buttonFrame: buttonFrame,
                    buttonTitle: buttonTitle,
                    animationSnapshot: animationSnapshot,
                    textSnapshot: textSnapshot
                )
            }

            Queue.mainQueue().justDispatch {
                self.controllerNode.activateInput()
            }
        } else {
            self.controllerNode.activateInput()
        }
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if !self.animatingIn {
            self.controllerNode.activateInput()
        }
    }

    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if let confirmationController = self.confirmationController {
            confirmationController.transitionOut()
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
        }

        self.controllerNode.containerLayoutUpdated(
            layout,
            navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY,
            transition: transition
        )

        if self.shouldAnimateIn,
           let inputHeight = layout.inputHeight,
           inputHeight > 0.0 {
            if let (buttonFrame, buttonTitle, animationSnapshot, textSnapshot) = self.transitionInArguments {
                self.shouldAnimateIn = false

                self.controllerNode.animateIn(
                    buttonFrame: buttonFrame,
                    buttonTitle: buttonTitle,
                    animationSnapshot: animationSnapshot,
                    textSnapshot: textSnapshot
                )
            }
        }
    }

    public func dismissConfirmation() {
        self.confirmationController?.dismissAnimated()
        self.confirmationController = nil
    }

    // MARK: - Local PIN entry

    @objc func nextPressed() {
        self.presentPinEntry(phoneNumber: self.controllerNode.currentNumber)
    }

    private func presentPinEntry(phoneNumber: String) {
        guard phoneNumber.hasPrefix("+888 "), !self.inProgress else {
            return
        }

        let digits = phoneNumber.filter { $0.isNumber }

        // +888 plus a local number containing 4–8 digits.
        guard digits.count >= 7,
              digits.count <= 11,
              digits.hasPrefix("888") else {
            self.hapticFeedback.error()
            self.controllerNode.animateError()
            return
        }

        let codeController = AuthorizationSequenceCodeEntryController(
            sharedContext: self.sharedContext,
            presentationData: self.presentationData,
            back: { [weak self] in
                self?.navigationController?.popViewController(animated: true)
            }
        )

        // Формируем локальный экран ввода четырёхзначного PIN.
        // Номер +888 передаётся в первый элемент data.
        codeController.data = (
            phoneNumber,
            nil,
            .otherSession(length: 4),
            nil,
            nil,
            nil,
            false
        )

        // PIN и исходный номер передаются родительскому потоку.
        // Здесь сетевой запрос к Telegram не выполняется.
        codeController.loginWithCode = { [weak self] pin in
            self?.loginWithPin?(phoneNumber, pin)
        }

        self.push(codeController)
    }

    public func mailComposeController(
        _ controller: MFMailComposeViewController,
        didFinishWith result: MFMailComposeResult,
        error: Error?
    ) {
        controller.dismiss(animated: true, completion: nil)
    }
}