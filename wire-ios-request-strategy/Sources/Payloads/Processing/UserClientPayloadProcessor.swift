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

import Foundation

final class UserClientPayloadProcessor {

    func createOrUpdateClients(
        from payloads: [Payload.UserClient],
        for user: ZMUser,
        selfClient: UserClient
    ) {
        let clients = payloads.map {
            createOrUpdateClient(
                from: $0,
                for: user
            )
        }

        // Remove clients that have not been included in the response
        let deletedClients = user.clients.subtracting(clients)
        deletedClients.forEach {
            $0.deleteClientAndEndSession()
        }

        // Mark new clients as missed and ignore them
        let newClients = Set(clients.filter({ $0.isInserted || !$0.hasSessionWithSelfClient }))
        selfClient.missesClients(newClients)
        selfClient.addNewClientsToIgnored(newClients)
        selfClient.updateSecurityLevelAfterDiscovering(newClients)
    }

    func createOrUpdateClient(
        from payload: Payload.UserClient,
        for user: ZMUser
    ) -> UserClient {
        let client = UserClient.fetchUserClient(
            withRemoteId: payload.id,
            forUser: user,
            createIfNeeded: true
        )!

        updateClient(
            client,
            from: payload
        )

        return client
    }

    func updateClient(
        _ client: UserClient,
        from payload: Payload.UserClient
    ) {
        client.needsToBeUpdatedFromBackend = false

        guard
            client.user?.isSelfUser == false,
            let deviceClass = payload.deviceClass
        else {
            return
        }

        client.deviceClass = DeviceClass(rawValue: deviceClass)
    }

}
