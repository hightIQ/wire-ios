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

@testable import Wire
import XCTest

final class FullscreenImageViewControllerSnapshotTests: BaseSnapshotTestCase {

    var sut: FullscreenImageViewController!
    var userSession: UserSessionMock!

    override func setUp() {
        super.setUp()
        userSession = UserSessionMock()
    }

    override func tearDown() {
        sut = nil
        userSession = nil
        super.tearDown()
    }

    func testThatVeryLargeImageIsLoadedToImageView() {
        sut = createFullscreenImageViewControllerForTest(imageFileName: "20000x20000.gif", userSession: userSession)

        verify(matching: sut.view)
    }

    func testThatSmallImageIsCenteredInTheScreen() {
        sut = createFullscreenImageViewControllerForTest(imageFileName: "unsplash_matterhorn_small_size.jpg", userSession: userSession)

        verify(matching: sut.view)
    }

    func testThatSmallImageIsScaledToFitTheScreenAfterDoubleTapped() {
        // GIVEN
        sut = createFullscreenImageViewControllerForTest(imageFileName: "unsplash_matterhorn_small_size.jpg", userSession: userSession)

        // WHEN
        doubleTap(fullscreenImageViewController: sut)

        // THEN
        verify(matching: sut.view)
    }

    func testThatImageIsDarkenWhenSelectedByMenu() {
        sut = createFullscreenImageViewControllerForTest(imageFileName: "unsplash_matterhorn_small_size.jpg", userSession: userSession)

        sut.setSelectedByMenu(true, animated: false)
        // test for tap again does not add one more layer
        sut.setSelectedByMenu(false, animated: false)
        sut.setSelectedByMenu(true, animated: false)

        verify(matching: sut.view)
    }
}
