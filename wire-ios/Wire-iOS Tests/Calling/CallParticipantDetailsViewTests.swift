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
import SnapshotTesting
@testable import Wire
import XCTest

class CallParticipantDetailsViewTests: XCTestCase {

    var sut: CallParticipantDetailsView!

    override func setUp() {
        super.setUp()

        sut = CallParticipantDetailsView()
        sut.name = "John Doe"
        sut.frame = CGRect(x: 0, y: 0, width: 95, height: 24)
        sut.backgroundColor = .black
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func testUnmutedState() {
        sut.microphoneIconStyle = MicrophoneIconStyle(state: .unmuted, shouldPulse: false)

        verify(matching: sut)
    }

    func testMutedState() {
        sut.microphoneIconStyle = MicrophoneIconStyle(state: .muted, shouldPulse: false)

        verify(matching: sut)
    }

    func testPulsingState() {
        sut.microphoneIconStyle = MicrophoneIconStyle(state: .unmuted, shouldPulse: true)

        verify(matching: sut)
    }

    func testConnectionIssue() {
        sut.callState = .unconnectedButMayConnect
        sut.name = "John Doe The Second"
        sut.frame = CGRect(x: 0, y: 0, width: 195, height: 24)
        verify(matching: sut)
    }
}
