//
// Wire
// Copyright (C) 2020 Wire Swiss GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
//

import UIKit
import WireSyncEngine

public enum NavigationDestination {
    case conversation(ZMConversation, ZMConversationMessage?)
    case userProfile(UserType)
    case connectionRequest(UUID)
    case conversationList
}

protocol AuthenticatedRouterProtocol: AnyObject {
    func updateActiveCallPresentationState()
    func minimizeCallOverlay(animated: Bool, withCompletion completion: Completion?)
    func navigate(to destination: NavigationDestination)
}

final class AuthenticatedRouter: NSObject {

    // MARK: - Private Property

    private let builder: AuthenticatedWireFrame
    private let rootViewController: RootViewController
    private let activeCallRouter: ActiveCallRouter
    private weak var _viewController: ZClientViewController?
    private let featureRepositoryProvider: FeatureRepositoryProvider
    private let featureChangeActionsHandler: E2eINotificationActions
    private let gracePeriodRepository: GracePeriodRepository

    // MARK: - Public Property

    var viewController: UIViewController {
        let viewController = _viewController ?? builder.build(router: self)
        _viewController = viewController
        return viewController
    }

    // MARK: - Init

    init(
        rootViewController: RootViewController,
        account: Account,
        userSession: UserSession,
        isComingFromRegistration: Bool,
        needToShowDataUsagePermissionDialog: Bool,
        featureRepositoryProvider: FeatureRepositoryProvider,
        featureChangeActionsHandler: E2eINotificationActionsHandler,
        gracePeriodRepository: GracePeriodRepository
    ) {
        self.rootViewController = rootViewController
        activeCallRouter = ActiveCallRouter(rootviewController: rootViewController, userSession: userSession)

        builder = AuthenticatedWireFrame(
            account: account,
            userSession: userSession,
            isComingFromRegistration: needToShowDataUsagePermissionDialog,
            needToShowDataUsagePermissionDialog: needToShowDataUsagePermissionDialog
        )

        self.featureRepositoryProvider = featureRepositoryProvider
        self.featureChangeActionsHandler = featureChangeActionsHandler
        self.gracePeriodRepository = gracePeriodRepository

        super.init()

        NotificationCenter.default.addObserver(
            forName: .featureDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.notifyFeatureChange(notification)
        }
    }

    private func notifyFeatureChange(_ note: Notification) {
        guard
            let change = note.object as? FeatureRepository.FeatureChange,
            let alert = change.hasFurtherActions
                ? UIAlertController.fromFeatureChangeWithActions(change,
                                                                 acknowledger: featureRepositoryProvider.featureRepository,
                                                                 actionsHandler: featureChangeActionsHandler)
                : UIAlertController.fromFeatureChange(change,
                                                      acknowledger: featureRepositoryProvider.featureRepository)
        else {
            return
        }

        if case .e2eIEnabled(gracePeriod: let gracePeriod) = change, let gracePeriod {
            let endOfGracePeriod = Date.now.addingTimeInterval(gracePeriod)
            gracePeriodRepository.storeEndGracePeriodDate(endOfGracePeriod)
        }

        _viewController?.presentAlert(alert)
    }
}

// MARK: - AuthenticatedRouterProtocol
extension AuthenticatedRouter: AuthenticatedRouterProtocol {
    func updateActiveCallPresentationState() {
        activeCallRouter.updateActiveCallPresentationState()
    }

    func minimizeCallOverlay(animated: Bool,
                             withCompletion completion: Completion?) {
        activeCallRouter.minimizeCall(animated: animated, completion: completion)
    }

    func navigate(to destination: NavigationDestination) {
        switch destination {
        case .conversation(let converation, let message):
            _viewController?.showConversation(converation, at: message)
        case .connectionRequest(let userId):
            _viewController?.showConnectionRequest(userId: userId)
        case .conversationList:
            _viewController?.showConversationList()
        case .userProfile(let user):
            _viewController?.showUserProfile(user: user)
        }
    }
}

// MARK: - AuthenticatedWireFrame
struct AuthenticatedWireFrame {
    private var account: Account
    private var userSession: UserSession
    private var isComingFromRegistration: Bool
    private var needToShowDataUsagePermissionDialog: Bool

    init(
        account: Account,
        userSession: UserSession,
        isComingFromRegistration: Bool,
        needToShowDataUsagePermissionDialog: Bool
    ) {
        self.account = account
        self.userSession = userSession
        self.isComingFromRegistration = isComingFromRegistration
        self.needToShowDataUsagePermissionDialog = needToShowDataUsagePermissionDialog
    }

    func build(router: AuthenticatedRouterProtocol) -> ZClientViewController {
        let viewController = ZClientViewController(
            account: account,
            userSession: userSession
        )
        viewController.isComingFromRegistration = isComingFromRegistration
        viewController.needToShowDataUsagePermissionDialog = needToShowDataUsagePermissionDialog
        viewController.router = router
        return viewController
    }
}

private extension UIViewController {

    func presentAlert(_ alert: UIAlertController) {
        present(alert, animated: true, completion: nil)
    }

}

protocol FeatureRepositoryProvider {

    var featureRepository: FeatureRepository { get }

}

extension ZMUserSession: FeatureRepositoryProvider {}
