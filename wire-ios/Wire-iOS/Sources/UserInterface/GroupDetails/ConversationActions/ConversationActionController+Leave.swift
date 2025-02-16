//
// Wire
// Copyright (C) 2024 Wire Swiss GmbH
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

import Foundation
import WireDataModel

enum LeaveResult: AlertResultConfiguration {
    case leave(delete: Bool), cancel

    var title: String {
        switch self {
        case .cancel: return L10n.Localizable.General.cancel
        case .leave(delete: true): return L10n.Localizable.Meta.leaveConversationButtonLeaveAndDelete
        case .leave(delete: false): return L10n.Localizable.Meta.leaveConversationButtonLeave
        }
    }

    private var style: UIAlertAction.Style {
        guard case .cancel = self else { return .destructive }
        return .cancel
    }

    func action(_ handler: @escaping (LeaveResult) -> Void) -> UIAlertAction {
        return .init(title: title, style: style) { _ in handler(self) }
    }

    static var title: String {
        return L10n.Localizable.Meta.leaveConversationDialogMessage
    }

    static var all: [LeaveResult] {
        return [.leave(delete: true), .leave(delete: false), .cancel]
    }
}

extension ConversationActionController {

    func handleLeaveResult(_ result: LeaveResult, for conversation: ZMConversation) {
        guard  case .leave(delete: let delete) = result else { return }
        guard let user = SelfUser.provider?.providedSelfUser else {
            assertionFailure("expected available 'user'!")
            return
        }

        transitionToListAndEnqueue {
            if delete {
                conversation.clearMessageHistory()
            }

            conversation.removeOrShowError(participant: user)
        }
    }

}
