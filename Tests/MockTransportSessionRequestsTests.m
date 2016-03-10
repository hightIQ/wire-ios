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


#import "MockTransportSessionTests.h"

@interface MockTransportSessionRequestsTests : MockTransportSessionTests

@end

@implementation MockTransportSessionRequestsTests


- (void)testThatItReturnsResponseFromResponseGenerator
{
    // given
    NSDictionary *expectedPayload = @{@"foo": @"baar"};
    NSError *expectedError = [NSError errorWithDomain:ZMTransportSessionErrorDomain code:ZMTransportSessionErrorCodeTryAgainLater userInfo:nil];
    NSInteger expectedStatus = 451;
    
    NSString *requestPath =@"/connections";
    ZMTransportRequestMethod requestMethod = ZMMethodPUT;
    NSArray *requestPayload = @[@3,@4,@5];
    
    __block ZMTransportRequest *receivedRequest;
    self.sut.responseGeneratorBlock = ^ZMTransportResponse *(ZMTransportRequest *request) {
        NOT_USED(request);
        receivedRequest = request;
        return [ZMTransportResponse responseWithPayload:expectedPayload HTTPstatus:expectedStatus transportSessionError:expectedError];
    };
    
    // when
    ZMTransportResponse *response = [self responseForPayload:requestPayload path:requestPath method:requestMethod];
    
    // then
    XCTAssertNotNil(response);
    if(!response) {
        return;
    }
    
    XCTAssertNotNil(receivedRequest);
    XCTAssertEqualObjects(receivedRequest.path, requestPath);
    XCTAssertEqualObjects(receivedRequest.payload, requestPayload);
    XCTAssertEqual(receivedRequest.method, requestMethod);
    
    
    XCTAssertEqual(response.HTTPStatus, expectedStatus);
    XCTAssertEqualObjects(response.transportSessionError, expectedError);
    XCTAssertEqualObjects(response.payload, expectedPayload);
}

- (void)testThatItReturnsTheOriginalResponseIfTheResponseGeneratorReturnsNil
{
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        MockUser *selfUser = [session insertSelfUserWithName:@"Me Myself"];
        selfUser.email = @"me@example.com";
        selfUser.phone = @"456456456";
    }];
    NSString *requestPath = [NSString stringWithFormat:@"/users?ids=%@", self.sut.selfUser.identifier];
    ZMTransportRequestMethod requestMethod = ZMMethodGET;
    NSArray *requestPayload = nil;
    
    // given
    self.sut.responseGeneratorBlock = ^ZMTransportResponse *(ZMTransportRequest *request) {
        NOT_USED(request);
        return nil;
    };
    
    // when
    ZMTransportResponse *response = [self responseForPayload:requestPayload path:requestPath method:requestMethod];
    
    // then
    XCTAssertNotNil(response);
    if(!response) {
        return;
    }
    
    XCTAssertEqual(response.HTTPStatus, 200);
    XCTAssertEqualObjects(response.transportSessionError, nil);
    XCTAssertEqualObjects(response.payload, @[self.sut.selfUser.transportData]);
}


- (void)testThatItNeverCompletesIfTheResponseGeneratorReturns_ZMCustomResponseGeneratorReturnResponseNotCompleted
{
    // given
    self.sut.responseGeneratorBlock = ^ZMTransportResponse *(ZMTransportRequest *request) {
        NOT_USED(request);
        return ZMCustomResponseGeneratorReturnResponseNotCompleted;
    };
    
    __block BOOL completed = NO;
    ZMCompletionHandler *handler = [ZMCompletionHandler handlerOnGroupQueue:self.fakeSyncContext block:^(ZMTransportResponse *backgroundResponse) {
        (void)backgroundResponse;
        completed = YES;
    }];
    
    ZMTransportRequestGenerator generator = [self createGeneratorForPayload:nil path:@"/foo" method:ZMMethodGET handler:handler];
    
    ZMTransportEnqueueResult* result = [self.sut.mockedTransportSession attemptToEnqueueSyncRequestWithGenerator:generator];
    [self spinMainQueueWithTimeout:0.1];
    
    // then
    XCTAssertTrue(result.didHaveLessRequestThanMax);
    XCTAssertTrue(result.didGenerateNonNullRequest);
    XCTAssertFalse(completed);
    
    [self.sut expireAllBlockedRequests];
    [self spinMainQueueWithTimeout:0.1];
    
    XCTAssertTrue(completed);
}


- (void)testThatItReturnsAnImage
{
    // given
    NSString *convID = [NSUUID createUUID].transportString;
    NSString *assetID = [NSUUID createUUID].transportString;
    NSData *expectedImageData =  [ZMTBaseTest dataForResource:@"verySmallJPEGs/tiny" extension:@"jpg"];
    
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        
        NOT_USED(session);
        MockAsset *asset = [MockAsset insertIntoManagedObjectContext:self.sut.managedObjectContext];
        asset.data = expectedImageData;
        asset.identifier = assetID;
        asset.conversation = convID;
        XCTAssertNotNil(expectedImageData);
    }];
    
    NSString *path = [NSString pathWithComponents:@[@"/", @"assets", [NSString stringWithFormat:@"%@?conv_id=%@", assetID, convID]]];
    
    // when
    ZMTransportResponse *response = [self responseForPayload:nil path:path method:ZMMethodGET];
    
    // then
    XCTAssertEqual(response.HTTPStatus, 200);
    XCTAssertNil(response.transportSessionError);
    AssertEqualData(response.imageData, expectedImageData);
}


- (void)testThatItDoesNotRespondToRequests
{
    // given
    self.sut.doNotRespondToRequests = YES;
    
    __block MockUser *selfUser;
    __block MockUser *user1;
    
    __block MockConversation *oneOnOneConversation;
    __block NSString *selfUserID;
    __block NSString *oneOnOneConversationID;
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        selfUser = [session insertSelfUserWithName:@"Me Myself"];
        selfUser.identifier = [[NSUUID createUUID] transportString];
        selfUserID = selfUser.identifier;
        user1 = [session insertUserWithName:@"Foo"];
        
        oneOnOneConversation = [session insertOneOnOneConversationWithSelfUser:selfUser otherUser:user1];
        oneOnOneConversationID = oneOnOneConversation.identifier;
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    
    NSString *messageText = @"Fofooof";
    NSUUID *nonce = [NSUUID createUUID];
    
    // (1)
    {
        // when
        NSDictionary *payload = @{
                                  @"content" : messageText,
                                  @"nonce" : nonce.transportString
                                  };
        
        NSString *path = [NSString pathWithComponents:@[@"/", @"conversations", oneOnOneConversationID, @"messages"]];
        
        
        ZMCompletionHandler *handler = [ZMCompletionHandler handlerOnGroupQueue:self.fakeSyncContext block:^(ZMTransportResponse *backgroundResponse) {
            NOT_USED(backgroundResponse);
            XCTFail(@"Shouldn't respond");
        }];
        
        ZMTransportRequestGenerator generator = [self createGeneratorForPayload:payload path:path method:ZMMethodPOST handler:handler];
        
        ZMTransportEnqueueResult *result = [self.sut.mockedTransportSession attemptToEnqueueSyncRequestWithGenerator:generator];
        
        XCTAssertTrue(result.didHaveLessRequestThanMax);
        XCTAssertTrue(result.didGenerateNonNullRequest);
    }
    
    
    
    // (2)
    {
        // when
        self.sut.doNotRespondToRequests = NO;
        
        NSString *path = [NSString pathWithComponents:@[@"/", @"conversations", oneOnOneConversationID, @"events?start=1.0&size=300"]];
        ZMTransportResponse *response = [self responseForPayload:nil path:path method:ZMMethodGET];
        
        // then
        XCTAssertNotNil(response);
        if (!response) {
            return;
        }
        XCTAssertEqual(response.HTTPStatus, 200);
        XCTAssertNil(response.transportSessionError);
        NSArray *events = [[response.payload asDictionary] arrayForKey:@"events"];
        XCTAssertNotNil(events);
        XCTAssertLessThanOrEqual(events.count, 1u);
    }
    
}


- (void)testThatOfflineWeNeverGetAResponseToOurRequest {
    
    // given
    self.sut.doNotRespondToRequests = YES;
    WaitForAllGroupsToBeEmpty(0.5);
    
    // when
    NSString *path = [NSString stringWithFormat:@"/conversations/ids"];
    
    ZMTransportSession *mockedTransportSession = self.sut.mockedTransportSession;
    
    __block ZMTransportResponse *response;
    
    ZMCompletionHandler *handler = [ZMCompletionHandler handlerOnGroupQueue:self.fakeSyncContext block:^(ZMTransportResponse *backgroundResponse) {
        NOT_USED(backgroundResponse);
        XCTFail();
    }];
    
    ZMTransportRequestGenerator generator = ^ZMTransportRequest*(void) {
        ZMTransportRequest *request = [ZMTransportRequest requestWithPath:path method:ZMMethodGET payload:nil];
        [request addCompletionHandler:handler];
        return request;
    };
    
    
    ZMTransportEnqueueResult* result = [mockedTransportSession attemptToEnqueueSyncRequestWithGenerator:generator];
    
    XCTAssertTrue(result.didHaveLessRequestThanMax);
    XCTAssertTrue(result.didGenerateNonNullRequest);
    
    [self spinMainQueueWithTimeout:0.3];
    
    // then
    XCTAssertNil(response);
    
    WaitForAllGroupsToBeEmpty(0.5);
}



- (void)testThatWhenOfflineAndMessageHasAnExpirationDateWeExpireTheRequest
{
    // given
    self.sut.doNotRespondToRequests = YES;
    WaitForAllGroupsToBeEmpty(0.5);
    
    // when
    NSString *path = [NSString stringWithFormat:@"/conversations/ids"];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Got a response"];
    
    ZMTransportSession *mockedTransportSession = self.sut.mockedTransportSession;
    
    __block ZMTransportResponse *response;
    
    ZMCompletionHandler *handler = [ZMCompletionHandler handlerOnGroupQueue:self.fakeSyncContext block:^(ZMTransportResponse *backgroundResponse) {
        response = backgroundResponse;
        [expectation fulfill];
    }];
    
    ZMTransportRequestGenerator generator = ^ZMTransportRequest*(void) {
        ZMTransportRequest *request = [ZMTransportRequest requestWithPath:path method:ZMMethodGET payload:nil];
        [request expireAfterInterval:0.2]; //This is the important bit
        [request addCompletionHandler:handler];
        return request;
    };
    
    ZMTransportEnqueueResult* result = [mockedTransportSession attemptToEnqueueSyncRequestWithGenerator:generator];
    
    XCTAssertTrue(result.didHaveLessRequestThanMax);
    XCTAssertTrue(result.didGenerateNonNullRequest);
    XCTAssertTrue([self waitForCustomExpectationsWithTimeout:0.5]);
    
    // then
    XCTAssertNotNil(response);
    if (!response) {
        return;
    }
    XCTAssertEqual(response.HTTPStatus, 0);
    XCTAssertNotNil(response.transportSessionError);
    XCTAssertEqual(response.transportSessionError.code, ZMTransportSessionErrorCodeRequestExpired);
    
}



@end



@implementation MockTransportSessionTests (ListOfRequests)

- (void)sendRequestToMockTransportSession:(ZMTransportRequest *)request
{
    ZMTransportRequestGenerator generator = ^ZMTransportRequest *(void) {
        return request;
    };
    [self.sut.mockedTransportSession attemptToEnqueueSyncRequestWithGenerator:generator];
}

- (void)testThatTheListOfRequestsContainsTheRequestsSent
{
    // given
    ZMTransportRequest *req1 = [ZMTransportRequest requestGetFromPath:@"/this/path"];
    ZMTransportRequest *req2 = [ZMTransportRequest requestWithPath:@"/foo/bar" method:ZMMethodDELETE payload:nil];
    ZMTransportRequest *req3 = [ZMTransportRequest requestWithPath:@"/arrrr" method:ZMMethodPUT payload:@{@"name":@"Johnny"}];
    
    NSArray *requests = @[req1, req2, req3];
    
    // when
    for(ZMTransportRequest *request in requests) {
        [self sendRequestToMockTransportSession:request];
    }
    WaitForAllGroupsToBeEmpty(0.5);
    
    // then
    XCTAssertEqualObjects(requests, self.sut.receivedRequests);
}

- (void)testThatResetRequestDiscardsPreviousRequests
{
    // given
    ZMTransportRequest *req1 = [ZMTransportRequest requestGetFromPath:@"/this/path"];
    ZMTransportRequest *req2 = [ZMTransportRequest requestWithPath:@"/foo/bar" method:ZMMethodDELETE payload:nil];
    ZMTransportRequest *req3 = [ZMTransportRequest requestWithPath:@"/arrrr" method:ZMMethodPUT payload:@{@"name":@"Johnny"}];
    for(ZMTransportRequest *request in @[req1, req2]) {
        [self sendRequestToMockTransportSession:request];
    }
    WaitForAllGroupsToBeEmpty(0.5);
    
    // when
    [self.sut resetReceivedRequests];
    [self sendRequestToMockTransportSession:req3];
    
    // then
    XCTAssertEqualObjects(self.sut.receivedRequests, @[req3]);
}


@end
