// 
// Wire
// Copyright (C) 2016 Wire Swiss GmbH
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
// along with this program. If not, see <http://www.gnu.org/licenses/>.
// 


@import ZMTransport;
#import "MockTransportSessionTests.h"
#import "MockPushEvent.h"

@interface MockTransportSessionPushChannelTests : MockTransportSessionTests
@end

@implementation MockTransportSessionPushChannelTests

- (void)testThatAfterSimulatePushChannelClosedTheDelegateIsInvoked
{
    // given
    [self.sut.mockedTransportSession openPushChannelWithConsumer:self groupQueue:self.fakeSyncContext];
    
    // when
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        [session simulatePushChannelClosed];
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    
    // then
    XCTAssertEqual(self.pushChannelDidCloseCount, 1u);
}

- (void)testThatAfterSimulatePushChannelOpenedTheDelegateIsInvoked
{
    // given
    [self.sut.mockedTransportSession openPushChannelWithConsumer:self groupQueue:self.fakeSyncContext];
    __block NSDictionary *payload;
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        MockUser *selfUser = [session insertSelfUserWithName:@"Me Myself"];
        selfUser.email = @"me@example.com";
        selfUser.password = @"123456";
        
        payload = @{@"email" : selfUser.email, @"password" : selfUser.password};
    }];
    
    // when
    [self responseForPayload:payload path:@"/login" method:ZMMethodPOST]; // this will simulate the user logging in
    
    // then
    XCTAssertEqual(self.pushChannelDidOpenCount, 1u);
}

- (void)testThatNoPushChannelEventIsSentBeforeThePushChannelIsOpened
{
    __block MockUser *selfUser;
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        selfUser = [session insertSelfUserWithName:@"Old self username"];
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    XCTAssertEqual(self.pushChannelReceivedEvents.count, 0u);
    
    // when
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> * ZM_UNUSED session) {
        selfUser.name = @"New";
        
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    
    // then
    XCTAssertEqual(self.pushChannelReceivedEvents.count, 0u);
}

- (void)testThatPushChannelEventsAreSentWhenThePushChannelIsOpened
{
    __block MockUser *selfUser;
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        selfUser = [session insertSelfUserWithName:@"Old self username"];
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    XCTAssertEqual(self.pushChannelReceivedEvents.count, 0u);
    
    // when
    [self createAndOpenPushChannelAndCreateSelfUser:NO];
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> * ZM_UNUSED session) {
        selfUser.name = @"New";
        
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    
    // then
    XCTAssertEqual(self.pushChannelReceivedEvents.count, 1u);
}

- (void)testThatNoPushChannelEventAreSentAfterThePushChannelIsClosed
{
    __block MockUser *selfUser;
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        selfUser = [session insertSelfUserWithName:@"Old self username"];
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    XCTAssertEqual(self.pushChannelReceivedEvents.count, 0u);
    
    // when
    [self createAndOpenPushChannelAndCreateSelfUser:NO];
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        [session simulatePushChannelClosed];
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> * ZM_UNUSED session) {
        selfUser.name = @"New";
        
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    
    // then
    XCTAssertEqual(self.pushChannelReceivedEvents.count, 0u);
}

- (void)testThatWeReceiveAPushEventWhenChangingSelfUserName
{
    // given
    NSString *newName = @"NEWNEWNEW";
    [self createAndOpenPushChannel];
    
    __block MockUser *selfUser;
    __block NSDictionary *expectedUserPayload;
    __block NSString *selfUserID;
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        selfUser = session.selfUser;
        selfUserID = selfUser.identifier;
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    XCTAssertEqual(self.pushChannelReceivedEvents.count, 0u);
    
    
    // when
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> * ZM_UNUSED session) {
        selfUser.name = newName;
        expectedUserPayload = @{
                                @"id" : selfUserID,
                                @"name" : newName
                                };
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    
    XCTAssertEqual(self.pushChannelReceivedEvents.count, 1u);
    TestPushChannelEvent *nameEvent = self.pushChannelReceivedEvents.firstObject;
    XCTAssertEqual(nameEvent.type, ZMTUpdateEventUserUpdate);
    XCTAssertEqualObjects(nameEvent.payload[@"user"], expectedUserPayload);
}

- (void)testThatWeReceiveAPushEventWhenChangingSelfProfile
{
    // given
    NSString *newValue = @"NEWNEWNEW";
    [self createAndOpenPushChannel];
    
    __block MockUser *selfUser;
    __block NSDictionary *expectedUserPayload;
    
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        selfUser = session.selfUser;
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    XCTAssertEqual(self.pushChannelReceivedEvents.count, 0u);
    
    
    
    // when
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> * ZM_UNUSED session) {
        selfUser.email = [newValue stringByAppendingString:@"-email"];
        selfUser.phone = [newValue stringByAppendingString:@"-phone"];
        selfUser.accentID = 5567;
        expectedUserPayload = @{
                                @"id" : selfUser.identifier,
                                @"email" : selfUser.email,
                                @"phone" : selfUser.phone,
                                @"accent_id" : @(selfUser.accentID)
                                };
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    
    XCTAssertEqual(self.pushChannelReceivedEvents.count, 1u);
    TestPushChannelEvent *nameEvent = self.pushChannelReceivedEvents.firstObject;
    XCTAssertEqual(nameEvent.type, ZMTUpdateEventUserUpdate);
    XCTAssertEqualObjects(nameEvent.payload[@"user"], expectedUserPayload);
}

- (void)testThatWeReceiveAPushEventWhenCreatingAConnection
{
    // given
    NSString *message = @"How're you doin'?";
    [self createAndOpenPushChannel];
    
    __block MockUser *selfUser;
    __block MockUser *otherUser;
    __block id<ZMTransportData> expectedConnectionPayload;
    
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        selfUser = session.selfUser;
        otherUser = [session insertUserWithName:@"Mr. Other User"];
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    XCTAssertEqual(self.pushChannelReceivedEvents.count, 0u);
    
    
    // when
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        MockConnection *connection = [session insertConnectionWithSelfUser:selfUser toUser:otherUser];
        connection.message = message;
        expectedConnectionPayload = connection.transportData;
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    
    XCTAssertEqual(self.pushChannelReceivedEvents.count, 1u);
    TestPushChannelEvent *connectEvent = self.pushChannelReceivedEvents.firstObject;
    XCTAssertEqual(connectEvent.type, ZMTUpdateEventUserConnection);
    XCTAssertEqualObjects(connectEvent.payload[@"connection"], expectedConnectionPayload);
}

- (void)testThatWeReceiveAPushEventWhenChangingAConnection
{
    // given
    NSString *message = @"How're you doin'?";
    [self createAndOpenPushChannel];
    
    __block MockConnection *connection;
    __block id<ZMTransportData> expectedConnectionPayload;
    
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        MockUser *selfUser = session.selfUser;
        MockUser *otherUser = [session insertUserWithName:@"Mr. Other User"];
        connection = [session insertConnectionWithSelfUser:selfUser toUser:otherUser];
        connection.message = message;
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    [self.pushChannelReceivedEvents removeAllObjects];
    
    // when
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> * ZM_UNUSED session) {
        connection.status = @"blocked";
        expectedConnectionPayload = connection.transportData;
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    
    XCTAssertEqual(self.pushChannelReceivedEvents.count, 1u);
    TestPushChannelEvent *connectEvent = self.pushChannelReceivedEvents.firstObject;
    XCTAssertEqual(connectEvent.type, ZMTUpdateEventUserConnection);
    XCTAssertEqualObjects(connectEvent.payload[@"connection"], expectedConnectionPayload);
}

- (void)testThatWeReceivePushEventsWhenCreatingAConversationAndInsertingMessages
{
    
    // given
    [self createAndOpenPushChannel];
    __block id<ZMTransportData> conversationPayload;
    __block id<ZMTransportData> event1Payload;
    __block id<ZMTransportData> event2Payload;
    
    // when
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        MockUser *selfUser = session.selfUser;
        MockUser *user1 = [session insertUserWithName:@"Name1 213"];
        MockUser *user2 = [session insertUserWithName:@"Name2 866"];
        MockConversation *conversation = [session insertGroupConversationWithSelfUser:selfUser otherUsers:@[user1,user2]];
        MockEvent *event1 = [conversation insertTextMessageFromUser:selfUser text:@"Text1" nonce:[NSUUID createUUID]];
        MockEvent *event2 = [conversation insertTextMessageFromUser:selfUser text:@"Text2" nonce:[NSUUID createUUID]];
        
        event1Payload = event1.data;
        event2Payload = event2.data;
        conversationPayload = conversation.transportData;
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    
    // then
    XCTAssertEqual(self.pushChannelReceivedEvents.count, 4u);
    TestPushChannelEvent *createConversationEvent = [self popEventMatchingWithBlock:^BOOL(TestPushChannelEvent *event) {
        return event.type == ZMTUpdateEventConversationCreate;
    }];
    TestPushChannelEvent *memberJoinEvent = [self popEventMatchingWithBlock:^BOOL(TestPushChannelEvent *event) {
        return event.type == ZMTUpdateEventConversationMemberJoin;
    }];
    TestPushChannelEvent *textEvent1 = [self popEventMatchingWithBlock:^BOOL(TestPushChannelEvent *event) {
        return ((event.type == ZMTUpdateEventConversationMessageAdd) &&
                [event.payload[@"data"] isEqual:event1Payload]);
    }];
    TestPushChannelEvent *textEvent2 = [self popEventMatchingWithBlock:^BOOL(TestPushChannelEvent *event) {
        return ((event.type == ZMTUpdateEventConversationMessageAdd) &&
                [event.payload[@"data"] isEqual:event2Payload]);
    }];
    XCTAssertNotNil(createConversationEvent);
    XCTAssertEqualObjects(createConversationEvent.payload[@"data"], conversationPayload);
    XCTAssertNotNil(memberJoinEvent);
    XCTAssertNotNil(textEvent1);
    XCTAssertNotNil(textEvent2);
    XCTAssertEqual(self.pushChannelReceivedEvents.count, 0u);
}

- (void)testThatWeReceiveAPushEventWhenChangingAConversationName
{
    // given
    NSString *name = @"So much name";
    [self createAndOpenPushChannel];
    __block MockConversation *conversation;
    
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        MockUser *selfUser = session.selfUser;
        MockUser *user1 = [session insertUserWithName:@"Name1 213"];
        MockUser *user2 = [session insertUserWithName:@"Name2 866"];
        conversation = [session insertGroupConversationWithSelfUser:selfUser otherUsers:@[user1,user2]];
        [conversation changeNameByUser:session.selfUser name:@"Something boring"];
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    [self.pushChannelReceivedEvents removeAllObjects];
    
    // when
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        [conversation changeNameByUser:session.selfUser name:name];
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    
    // then
    XCTAssertEqual(self.pushChannelReceivedEvents.count, 1u);
    TestPushChannelEvent *nameChangeName = self.pushChannelReceivedEvents.firstObject;
    
    XCTAssertEqual(nameChangeName.type, ZMTUpdateEventConversationRename);
}

- (void)testThatWeReceiveAPushEventWhenCreatingAConversation
{
    // given
    [self createAndOpenPushChannel];
    __block MockConversation *conversation;
    __block id<ZMTransportData> expectedData;
    
    // when
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        MockUser *selfUser = session.selfUser;
        MockUser *user1 = [session insertUserWithName:@"Name1 213"];
        MockUser *user2 = [session insertUserWithName:@"Name2 866"];
        conversation = [session insertGroupConversationWithSelfUser:selfUser otherUsers:@[user1,user2]];
        [conversation changeNameByUser:session.selfUser name:@"Trolls"];
        
        expectedData = conversation.transportData;
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    
    
    // then
    XCTAssertGreaterThanOrEqual(self.pushChannelReceivedEvents.count, 1u);
    NSUInteger index = [self.pushChannelReceivedEvents indexOfObjectPassingTest:^BOOL(TestPushChannelEvent *event, NSUInteger idx ZM_UNUSED, BOOL *stop ZM_UNUSED) {
        return event.type == ZMTUpdateEventConversationCreate;
    }];
    XCTAssertTrue(index != NSNotFound);
    if(index != NSNotFound) {
        TestPushChannelEvent *event = self.pushChannelReceivedEvents[index];
        XCTAssertEqualObjects(expectedData, event.payload[@"data"]);
    }
}

- (void)testThatWeReceiveAPushEventWhenAddingAParticipantToAConversation
{
    // given
    [self createAndOpenPushChannel];
    __block MockConversation *conversation;
    __block MockUser *user3;
    
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        MockUser *selfUser = session.selfUser;
        selfUser.name = @"Some self user name";
        MockUser *user1 = [session insertUserWithName:@"Name1 213"];
        MockUser *user2 = [session insertUserWithName:@"Name2 866"];
        user3 = [session insertUserWithName:@"Name3 555"];
        conversation = [session insertGroupConversationWithSelfUser:selfUser otherUsers:@[user1,user2]];
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    [self.pushChannelReceivedEvents removeAllObjects];
    
    // when
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        [conversation addUsersByUser:session.selfUser addedUsers:@[user3]];
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    
    // then
    XCTAssertEqual(self.pushChannelReceivedEvents.count, 1u);
    TestPushChannelEvent *memberAddEvent = self.pushChannelReceivedEvents.firstObject;
    
    XCTAssertEqual(memberAddEvent.type, ZMTUpdateEventConversationMemberJoin);
}

- (void)testThatWeReceiveAPushEventWhenRemovingAParticipantFromAConversation
{
    // given
    [self createAndOpenPushChannel];
    __block MockConversation *conversation;
    __block MockUser *user2;
    
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        MockUser *selfUser = session.selfUser;
        MockUser *user1 = [session insertUserWithName:@"Name1 213"];
        user2 = [session insertUserWithName:@"Name2 866"];
        conversation = [session insertGroupConversationWithSelfUser:selfUser otherUsers:@[user1,user2]];
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    [self.pushChannelReceivedEvents removeAllObjects];
    
    // when
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        [conversation removeUsersByUser:session.selfUser removedUser:user2];
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    
    // then
    XCTAssertEqual(self.pushChannelReceivedEvents.count, 1u);
    TestPushChannelEvent *memberRemoveEvent = self.pushChannelReceivedEvents.firstObject;
    XCTAssertEqual(memberRemoveEvent.type, ZMTUpdateEventConversationMemberLeave);
}

- (void)testThatWeReceiveIsTypingPushEvents;
{
    [self createAndOpenPushChannel];
    __block MockConversation *conversation;
    __block MockUser *user2;
    __block NSString *conversationIdentifier;
    __block NSString *userIdentifier;
    
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        MockUser *selfUser = session.selfUser;
        MockUser *user1 = [session insertUserWithName:@"Name1 213"];
        user2 = [session insertUserWithName:@"Name2 866"];
        conversation = [session insertGroupConversationWithSelfUser:selfUser otherUsers:@[user1,user2]];
        conversationIdentifier = conversation.identifier;
        userIdentifier = user2.identifier;
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    [self.pushChannelReceivedEvents removeAllObjects];
    
    // when
    [self.sut sendIsTypingEventForConversation:conversation user:user2 started:YES];
    WaitForAllGroupsToBeEmpty(0.5);
    
    // then
    XCTAssertEqual(self.pushChannelReceivedEvents.count, 1u);
    TestPushChannelEvent *isTypingEvent = self.pushChannelReceivedEvents.firstObject;
    
    XCTAssertEqual(isTypingEvent.type, ZMTUpdateEventConversationTyping);
    NSDictionary *expected = @{@"conversation": conversationIdentifier,
                               @"from": userIdentifier,
                               @"data": @{@"status": @"started"},
                               @"type": @"conversation.typing"};
    XCTAssertEqualObjects(isTypingEvent.payload, expected);
}

- (void)testThatThePushChannelIsOpenAfterALogin
{
    // given
    [self.sut.mockedTransportSession openPushChannelWithConsumer:self groupQueue:self.fakeSyncContext];
    
    __block MockUser *selfUser;
    NSString *email = @"doo@example.com";
    NSString *password = @"Bar481516";
    
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        selfUser = [session insertSelfUserWithName:@"Food"];
        selfUser.email = email;
        selfUser.password = password;
    }];
    [[(id) self.cookieStorage stub] setAuthenticationCookieData:OCMOCK_ANY];
    WaitForAllGroupsToBeEmpty(0.5);
    
    // when
    NSString *path = @"/login";
    ZMTransportResponse *response = [self responseForPayload:@{
                                                               @"email": email,
                                                               @"password": password
                                                               } path:path method:ZMMethodPOST];
    WaitForAllGroupsToBeEmpty(0.5);
    
    // then
    XCTAssertNotNil(response);
    XCTAssertEqual(response.HTTPStatus, 200);
    XCTAssertTrue(self.sut.isPushChannelActive);
    XCTAssertEqual(self.pushChannelDidOpenCount, 1u);
}

- (void)testThatThePushChannelIsOpenAfterSimulateOpenPushChannel
{
    // when
    [self createAndOpenPushChannel];
    WaitForAllGroupsToBeEmpty(0.5);
    
    // then
    XCTAssertEqual(self.pushChannelDidOpenCount, 1u);
    XCTAssertTrue(self.sut.isPushChannelActive);
}

- (void)testThatThePushChannelIsClosedAfterSimulateClosePushChannel
{
    // given
    [self createAndOpenPushChannel];
    
    // when
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        [session simulatePushChannelClosed];
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    
    // then
    XCTAssertEqual(self.pushChannelDidOpenCount, 1u);
    XCTAssertEqual(self.pushChannelDidCloseCount, 1u);
    XCTAssertFalse(self.sut.isPushChannelActive);
}

- (NSArray *)createConversationAndReturnExpectedNotificationTypes
{
    // given
    const NSInteger NUM_MESSAGES = 10;
    __block MockUser *selfUser;
    __block MockUser *user1;
    __block MockUser *user2;
    __block MockConversation *conversation;
    
    NSMutableArray *expectedTypes = [NSMutableArray array];
    
    // do in separate blocks so I'm sure of the order of events - if done together there is a single
    // save and I don't know the order
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        selfUser = [session insertSelfUserWithName:@"SelfUser Name"];
        user1 = [session insertUserWithName:@"Name of User 1"];
        user2 = [session insertUserWithName:@"Name of user 2"];
        
        // two connection events
        [expectedTypes addObject:@"user.connection"];
        [expectedTypes addObject:@"user.connection"];
        
        
        MockConnection *connection1 = [session insertConnectionWithSelfUser:selfUser toUser:user1];
        connection1.status = @"accepted";
        MockConnection *connection2 = [session insertConnectionWithSelfUser:selfUser toUser:user2];
        connection2.status = @"accepted";
    }];
    
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        // conversation creation event + member join event
        [expectedTypes addObject:@"conversation.create"];
        [expectedTypes addObject:@"conversation.member-join"];
        
        conversation = [session insertGroupConversationWithSelfUser:selfUser otherUsers:@[user1, user2]];
    }];
    
    for(int i = 0; i < NUM_MESSAGES; ++i) {
        // NUM_MESSAGES message events
        [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
            [expectedTypes addObject:@"conversation.message-add"];
            
            [conversation insertTextMessageFromUser:user1 text:[NSString stringWithFormat:@"Message %d",i] nonce:[NSUUID createUUID]];
            NOT_USED(session);
        }];
    }
    WaitForAllGroupsToBeEmpty(0.5);
    
    return expectedTypes;
}

- (void)testThatItReturnsTheLastPushChannelEventsWhenRequestingNotifications
{
    // given
    NSArray *expectedTypes = [self createConversationAndReturnExpectedNotificationTypes];
    
    // when
    ZMTransportResponse *response = [self responseForPayload:nil path:@"/notifications" method:ZMMethodGET];
    
    // then
    XCTAssertEqual(response.result, ZMTransportResponseStatusSuccess);
    NSArray* events = [[[response.payload asDictionary] arrayForKey:@"notifications" ] asDictionaries];
    XCTAssertEqual(events.count, expectedTypes.count);
    
    NSUInteger counter = 0;
    for(NSDictionary *eventData in events) {
        
        NSUUID *eventID = [eventData uuidForKey:@"id"];
        XCTAssertNotNil(eventID);
        
        NSString *type = [[[eventData arrayForKey:@"payload"] asDictionaries][0] stringForKey:@"type"];
        XCTAssertEqualObjects(type, expectedTypes[counter]);
        ++counter;
    }
}

- (void)testThatItReturnsTheLastPushChannelEventsEvenIfRequestingSinceANonExistingOne
{
    // given
    NSArray *expectedTypes = [self createConversationAndReturnExpectedNotificationTypes];
    
    // when
    NSString *path = [NSString stringWithFormat:@"/notifications?since=%@", [NSUUID createUUID].transportString];
    ZMTransportResponse *response = [self responseForPayload:nil path:path method:ZMMethodGET];
    
    // then
    XCTAssertEqual(response.HTTPStatus, 404);
    NSArray* events = [[[response.payload asDictionary] arrayForKey:@"notifications" ] asDictionaries];
    XCTAssertEqual(events.count, expectedTypes.count);
    
    NSUInteger counter = 0;
    for(NSDictionary *eventData in events) {
        
        NSUUID *eventID = [eventData uuidForKey:@"id"];
        XCTAssertNotNil(eventID);
        
        NSString *type = [[[eventData arrayForKey:@"payload"] asDictionaries][0] stringForKey:@"type"];
        XCTAssertEqualObjects(type, expectedTypes[counter]);
        ++counter;
    }
}

- (void)testThatItReturnsOnlyTheNotificationsFollowingTheOneRequested
{
    // given
    const NSUInteger eventsOffset = 4;
    NSArray *expectedTypes = [self createConversationAndReturnExpectedNotificationTypes];
    XCTAssertTrue(eventsOffset < expectedTypes.count);
    
    ZMTransportResponse *response = [self responseForPayload:nil path:@"/notifications" method:ZMMethodGET];
    
    NSArray *allEvents = [[[response.payload asDictionary] arrayForKey:@"notifications" ] asDictionaries];
    NSUUID *startingEventID = [allEvents[eventsOffset-1] uuidForKey:@"id"];
    
    // when
    NSString *path = [NSString stringWithFormat:@"/notifications?since=%@", startingEventID.transportString];
    response = [self responseForPayload:nil path:path method:ZMMethodGET];
    
    // then
    NSArray *expectedEvents = [allEvents subarrayWithRange:NSMakeRange(eventsOffset, allEvents.count - eventsOffset)];
    XCTAssertEqual(response.result, ZMTransportResponseStatusSuccess);
    NSArray *events = [[[response.payload asDictionary] arrayForKey:@"notifications" ] asDictionaries];
    
    XCTAssertEqualObjects(expectedEvents, events);
}

- (void)testThatItReturnsTheLastUpdateEventWhenRequested
{
    // given
    __block MockUser *selfUser;
    __block MockUser *user1;
    __block MockUser *user2;
    
    NSMutableArray *expectedTypes = [NSMutableArray array];
    
    // do in separate blocks so I'm sure of the order of events - if done together there is a single
    // save and I don't know the order
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        selfUser = [session insertSelfUserWithName:@"SelfUser Name"];
        user1 = [session insertUserWithName:@"Name of User 1"];
        user2 = [session insertUserWithName:@"Name of user 2"];
        
        // two connection events
        [expectedTypes addObject:@"user.connection"];
        [expectedTypes addObject:@"user.connection"];
        
        
        MockConnection *connection1 = [session insertConnectionWithSelfUser:selfUser toUser:user1];
        connection1.status = @"accepted";
        MockConnection *connection2 = [session insertConnectionWithSelfUser:selfUser toUser:user2];
        connection2.status = @"accepted";
    }];
    
    // when
    ZMTransportResponse *response = [self responseForPayload:nil path:@"/notifications/last" method:ZMMethodGET];
    
    // then
    XCTAssertEqual(response.result, ZMTransportResponseStatusSuccess);
    XCTAssertEqualObjects(response.payload, [self.sut.generatedPushEvents.lastObject transportData]);
}

@end
