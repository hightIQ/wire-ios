//
// Wire
// Copyright (C) 2023 Wire Swiss GmbH
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
import WireDataModel
import WireSyncEngine

final class DeviceDetailsViewActionsHandler: DeviceDetailsViewActions, ObservableObject {
    let logger = WireLogger.e2ei
    let e2eIdentityProvider: E2eIdentityProviding
    let userSession: UserSession
    let mlsProvider: MLSProviding

    var userClient: UserClient
    var clientRemovalObserver: ClientRemovalObserver?
    var credentials: ZMEmailCredentials?
    var isProcessing: ((Bool) -> Void)?

    var isMLSEnabled: Bool {
        mlsProvider.isMLSEnbaled
    }

    var isE2eIdentityEnabled: Bool {
        e2eIdentityProvider.isE2EIdentityEnabled
    }

    var isSelfClient: Bool {
        userClient.isSelfClient()
    }

    private var saveFileManager: SaveFileActions

    init(
        userClient: UserClient,
        userSession: UserSession,
        credentials: ZMEmailCredentials?,
        e2eIdentityProvider: E2eIdentityProviding,
        mlsProvider: MLSProviding,
        saveFileManager: SaveFileActions
    ) {
        self.userClient = userClient
        self.credentials = credentials
        self.userSession = userSession
        self.e2eIdentityProvider = e2eIdentityProvider
        self.mlsProvider = mlsProvider
        self.saveFileManager = saveFileManager
    }

    func fetchCertificate() async -> E2eIdentityCertificate? {
        do {
            return try await userClient.fetchE2eIdentityCertificate(e2eIdentityProvider: e2eIdentityProvider)
        } catch {
            logger.error(error.localizedDescription)
        }
        return nil
    }

    func fetchMLSThumbprint() async -> String? {
        do {
            return try await mlsProvider.fetchMLSThumbprint()
        } catch {
            logger.error(error.localizedDescription)
        }
        return nil
    }

    @MainActor
    func removeDevice() async -> Bool {
        return await withCheckedContinuation {[weak self] continuation in
            guard let self = self else {
                return
            }
            // (Continuation)[https://developer.apple.com/documentation/swift/checkedcontinuation]
            // Using the same continuation twice results in a crash.
            var optionalContinuation: CheckedContinuation<Bool, Never>? = continuation
            clientRemovalObserver = ClientRemovalObserver(
                userClientToDelete: userClient,
                delegate: self,
                credentials: credentials,
                completion: {
                    error in
                    defer {
                        optionalContinuation = nil
                    }
                    optionalContinuation?.resume(returning: error == nil)
                    if let error = error {
                        WireLogger.e2ei.error(error.localizedDescription)
                    }
                }
            )
            clientRemovalObserver?.startRemoval()
        }
    }

    func resetSession() {
        userClient.resetSession()
    }

    @MainActor
    func updateVerified(_ isVerified: Bool) async -> Bool {
        let selfUserClient = userSession.selfUserClient
        return await withCheckedContinuation { continuation in
            userSession.enqueue({
                if isVerified {
                    selfUserClient?.trustClient(self.userClient)
                } else {
                    selfUserClient?.ignoreClient(self.userClient)
                }
            }, completionHandler: {
                continuation.resume(returning: self.userClient.verified)
            }
            )
        }
    }

    func copyToClipboard(_ value: String) {
        UIPasteboard.general.string = value
    }

    func downloadE2EIdentityCertificate(certificate: E2eIdentityCertificate) {
        saveFileManager.save(
            value: certificate.certificateDetails,
            fileName: userClient.label ?? "e2ecertificate",
            type: "txt"
        )
    }
}

extension DeviceDetailsViewActionsHandler: ClientRemovalObserverDelegate {
    func present(
        _ clientRemovalObserver: ClientRemovalObserver,
        viewControllerToPresent: UIViewController
    ) {
        if !(UIApplication.shared.topmostViewController()?.presentedViewController is UIAlertController) {
                    UIViewController.presentTopmost(viewController: viewControllerToPresent)
        }
    }

    func setIsLoadingViewVisible(
        _ clientRemovalObserver: ClientRemovalObserver,
        isVisible: Bool
    ) {
        isProcessing?(isVisible)
    }
}
