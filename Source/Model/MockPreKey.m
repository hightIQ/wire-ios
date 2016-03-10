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


#import "MockPreKey.h"

@import ZMUtilities;
@import ZMTransport;

@implementation MockPreKey

@dynamic value;
@dynamic identifier;
@dynamic client;
@dynamic lastPrekeyOfClient;

+ (instancetype)insertNewKeyWithPayload:(NSDictionary *)payload context:(NSManagedObjectContext *)context;
{
    if ([payload isKindOfClass:[NSDictionary class]]) {
        NSNumber *identifier = [payload numberForKey:@"id"];
        NSString *value = [payload stringForKey:@"key"];
        if (identifier == nil || value == nil) {
            return nil;
        }
        
        MockPreKey *preKey = [NSEntityDescription insertNewObjectForEntityForName:@"PreKey" inManagedObjectContext:context];
        preKey.identifier = [identifier integerValue];
        preKey.value = value;
        return preKey;
    }
    return nil;
}

+ (NSSet *)insertNewKeysWithPayload:(NSArray *)payload context:(NSManagedObjectContext *)context;
{
    return [[NSSet setWithArray:payload] mapWithBlock:^id(NSDictionary *keyPayload) {
        return [self insertNewKeyWithPayload:keyPayload context:context];
    }];
}

@end
