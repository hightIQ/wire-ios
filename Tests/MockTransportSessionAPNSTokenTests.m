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

@interface MockTransportAPNSTokenTests : MockTransportSessionTests

@end

@implementation MockTransportAPNSTokenTests

- (void)testThatWeCanRegisterAPushToken;
{
    // given
    NSString *token = @"c5e31e41e4d4599037928449349487547ef14f162c77aee3a08e12a39c8db1d5";
    NSDictionary *payload = @{@"token" : token,
                              @"app" : @"com.wire.zclient.mac",
                              @"transport" : @"APNS"};
    
    // when
    ZMTransportResponse *response = [self responseForPayload:payload path:@"/push/tokens" method:ZMMethodPOST];
    
    // then
    XCTAssertEqual(response.HTTPStatus, (NSInteger) 201);
    XCTAssertEqualObjects(response.payload, payload);
}

- (void)testThatItFailsWhenAnyFieldIsMissing;
{
    // given
    NSString *token = @"c5e31e41e4d4599037928449349487547ef14f162c77aee3a08e12a39c8db1d5";
    NSDictionary *payload = @{@"token" : token,
                              @"app" : @"com.wire.zclient.mac",
                              @"transport" : @"APNS"};
    
    for (NSString *key in payload.allKeys) {
        NSMutableDictionary *p2 = [payload mutableCopy];
        [p2 removeObjectForKey:key];
        
        // when
        __block ZMTransportResponse *response;
        [self performIgnoringZMLogError:^{
            response = [self responseForPayload:p2 path:@"/push/tokens" method:ZMMethodPOST];
        }];
        
        // then
        XCTAssertEqual(response.HTTPStatus, (NSInteger) 400);
    }
    //{
    //    "code": 400,
    //    "message": "Failed reading: satisfyElem",
    //    "label": "bad-request"
    //}
}

- (void)testThatItFailsWhenTheTransportIsNotAPNS;
{
    // given
    NSString *token = @"c5e31e41e4d4599037928449349487547ef14f162c77aee3a08e12a39c8db1d5";
    NSDictionary *payload = @{@"token" : token,
                              @"app" : @"com.wire.zclient.mac",
                              @"transport" : @"sfkhhksdf"};
    
    // when
    ZMTransportResponse *response = [self responseForPayload:payload path:@"/push/tokens" method:ZMMethodPOST];
    
    // then
    XCTAssertEqual(response.HTTPStatus, (NSInteger) 400);
    
    //{
    //    "code": 400,
    //    "message": "mzero",
    //    "label": "bad-request"
    //}
}

@end
