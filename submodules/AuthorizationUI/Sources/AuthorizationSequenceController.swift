import Foundation
import UIKit
import Display

public final class AuthorizationSequenceController: NSObject {

    // MARK: - Callbacks

    /// Вызывается после успешной авторизации.
    public var authorizationCompleted: ((Any) -> Void)?

    /// Создаёт экран ввода номера.
    /// Переданный callback должен получить номер в формате "+888 XXXXX".
    private let makePhoneEntryController: (
        @escaping (String) -> Void
    ) -> AuthorizationSequencePhoneEntryController

    /// Создаёт экран PIN и настраивает его для указанного номера.
    /// Переданный callback вызывается после успешной авторизации.
    private let makePinEntryController: (
        String,
        @escaping (Any) -> Void
    ) -> AuthorizationSequenceCodeEntryController

    private weak var navigationController: UINavigationController?

    private var isAuthorizationCompleted = false

    // MARK: - Init

    public init(
        navigationController: UINavigationController,
        makePhoneEntryController: @escaping (
            @escaping (String) -> Void
        ) -> AuthorizationSequencePhoneEntryController,
        makePinEntryController: @escaping (
            String,
            @escaping (Any) -> Void
        ) -> AuthorizationSequenceCodeEntryController
    ) {
        self.navigationController = navigationController
        self.makePhoneEntryController = makePhoneEntryController
        self.makePinEntryController = makePinEntryController

        super.init()
    }

    // MARK: - Start

    public func start() {
        isAuthorizationCompleted = false

        let phoneController = makePhoneEntryController { [weak self] phoneNumber in
            self?.openPinEntry(phoneNumber: phoneNumber)
        }

        navigationController?.setViewControllers(
            [phoneController],
            animated: false
        )
    }

    // MARK: - PIN screen

    private func openPinEntry(phoneNumber: String) {
        guard isValidPhoneNumber(phoneNumber) else {
            return
        }

        guard let navigationController else {
            return
        }

        let pinController = makePinEntryController(
            phoneNumber
        ) { [weak self] user in
            self?.completeAuthorization(user: user)
        }

        navigationController.pushViewController(
            pinController,
            animated: true
        )
    }

    // MARK: - Authorization completed

    private func completeAuthorization(user: Any) {
        guard !isAuthorizationCompleted else {
            return
        }

        isAuthorizationCompleted = true

        authorizationCompleted?(user)
    }

    // MARK: - Validation

    private func isValidPhoneNumber(_ phoneNumber: String) -> Bool {
        guard phoneNumber.hasPrefix("+888 ") else {
            return false
        }

        let localNumber = phoneNumber
            .replacingOccurrences(of: "+888", with: "")
            .filter { $0.isNumber }

        guard let number = Int(localNumber) else {
            return false
        }

        return (1...88_888_888).contains(number)
            && localNumber.count <= 8
    }
}