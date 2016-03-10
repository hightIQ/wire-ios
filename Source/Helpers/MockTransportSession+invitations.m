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


#import "MockTransportSession+invitations.h"
#import "MockPersonalInvitation.h"

@implementation MockTransportSession (invitations)

- (ZMTransportResponse *)processInvitationsRequest:(TestTransportSessionRequest *)request;
{
    if ((request.method == ZMMethodGET) && (request.pathComponents.count == 0)) {
        return [self processGetInvitationRequest:request];
    }
    if ((request.method == ZMMethodGET) && (request.pathComponents.count == 1)) {
        return [self processGetSpecificInivitationRequest:request];
    }
    if ((request.method == ZMMethodPOST) && (request.pathComponents.count == 0)) {
        return [self processPostInivitationRequest:request];
    }
    if (request.method == ZMMethodDELETE && (request.pathComponents.count == 1)) {
        return [self processDeleteInivitationRequest:request];
    }
    
    return [ZMTransportResponse responseWithPayload:nil HTTPstatus:404 transportSessionError:nil];
}

- (ZMTransportResponse *)processPostInivitationRequest:(TestTransportSessionRequest *)request;
{
    NSDictionary *payload = [request.payload asDictionary];
    NSString *inviterName = [payload stringForKey:@"inviter_name"];
    if (inviterName == nil) {
        return [self errorResponseWithCode:400 reason:@"Missing \"inviter_name\" field"];
    }
    NSString *inviteeName = [payload stringForKey:@"invitee_name"];
    if (inviteeName == nil) {
        return [self errorResponseWithCode:400 reason:@"Missing \"invitee_name\" field"];
    }
    NSString *message = [payload stringForKey:@"message"];
    if (message == nil) {
        return [self errorResponseWithCode:400 reason:@"Missing \"invitee_name\" field"];
    }
    
    NSString *inviteeEmail = [payload optionalStringForKey:@"email"];
    NSString *inviteePhone = [payload optionalStringForKey:@"phone"];
    if (inviteeEmail == nil && inviteePhone == nil ) {
        return [self errorResponseWithCode:400 reason:@"Missing \"invitee_name\" or \"invitee_phone\" field"];
    }
    
    // check if invitee existing already in DB, invitee is a Wire user
    NSPredicate *identificationPredicate = [self predicateForUserWithEmail:inviteeEmail ORPhone:inviteePhone];
    NSFetchRequest *usersRequest = [MockUser sortedFetchRequestWithPredicate:identificationPredicate];
    NSArray *users = [self.managedObjectContext executeFetchRequest:usersRequest error:nil];
    if ([users count] > 0) { // User exist
        
        MockUser *toUser = [users firstObject];
        NSFetchRequest *connectionRequest = [MockConnection sortedFetchRequest];
        connectionRequest.predicate = [NSPredicate predicateWithFormat:@"to.identifier == %@", toUser.identifier];
        
        //check if a connection already exist
        NSArray *connections = [self.managedObjectContext executeFetchRequest:connectionRequest error:nil];
        if ([connections count] > 0) { //yes, return existing connection
            MockConnection *connection = connections[0];
            return [ZMTransportResponse responseWithPayload:nil HTTPstatus:303 transportSessionError:nil headers:@{@"Location" : connection.to.identifier}];
        }
        
        //create connection
        MockConnection *connection = [self createConnectionFrom:self.selfUser to:toUser message:message];
        return [ZMTransportResponse responseWithPayload:nil HTTPstatus:201 transportSessionError:nil headers:@{@"Location" : connection.to.identifier}];
    }
    
    // user does not exist, create an invitation 
    MockPersonalInvitation *personalInvitation = [MockPersonalInvitation invitationInMOC:self.managedObjectContext fromUser:self.selfUser toInviteeWithName:inviteeName email:inviteeEmail phoneNumber:inviteePhone];
    return [ZMTransportResponse responseWithPayload:personalInvitation.transportData HTTPstatus:201 transportSessionError:nil];
}

- (ZMTransportResponse *)processGetInvitationRequest:(__unused TestTransportSessionRequest *)request;
{
    NSFetchRequest *fetchRequest = [MockPersonalInvitation sortedFetchRequest];
    [fetchRequest setFetchLimit:10];
    NSArray *invitations = [self.managedObjectContext executeFetchRequest:fetchRequest error:nil];
    return [ZMTransportResponse responseWithPayload:[self invitationsTransportDataFromInvitations:invitations] HTTPstatus:200 transportSessionError:nil];
}

- (ZMTransportResponse *)processGetSpecificInivitationRequest:(TestTransportSessionRequest *)request;
{
    NSString *invitationID = request.pathComponents[0];
    if ([invitationID length] == 0lu) {
        return [self errorResponseWithCode:404 reason:@"ID to delete does not exist"];
    }
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"identifier == %@", invitationID];
    NSFetchRequest *fetchRequest = [MockPersonalInvitation sortedFetchRequestWithPredicate:predicate];
    NSArray *invitations = [self.managedObjectContext executeFetchRequest:fetchRequest error:nil];
    if (invitations.count == 0) {
        return [self errorResponseWithCode:404 reason:@"ID to delete does not exist"];
    }
    return [ZMTransportResponse responseWithPayload:[[invitations firstObject] transportData] HTTPstatus:200 transportSessionError:nil];
}

- (ZMTransportResponse *)processDeleteInivitationRequest:(TestTransportSessionRequest *)request;
{
    NSString *invitationID = request.pathComponents[0];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"identifier == %@", invitationID];
    NSFetchRequest *fetchRequest = [MockPersonalInvitation sortedFetchRequestWithPredicate:predicate];
    NSArray *invitations = [self.managedObjectContext executeFetchRequest:fetchRequest error:nil];
    if (invitations.count == 0) {
        return [self errorResponseWithCode:404 reason:@"ID to delete does not exist"];
    }
    [self.managedObjectContext deleteObject:[invitations firstObject]];
    return [ZMTransportResponse responseWithPayload:nil HTTPstatus:200 transportSessionError:nil];
}

#pragma mark Helpers

- (NSString *)invitationsTransportDataFromInvitations:(NSArray *)invitations;
{
    NSMutableArray *transportDataArray = [NSMutableArray array];
    for (MockPersonalInvitation *invitation in invitations) {
        [transportDataArray addObject:invitation.transportData];
    }
    return [transportDataArray copy];
}

- (NSPredicate *)predicateForUserWithEmail:(nullable NSString *)email ORPhone:(nullable NSString *)phone;
{
    NSPredicate *emailPredicate = email ? [NSPredicate predicateWithFormat:@"email == %@", email] : nil;
    NSPredicate *phonePredicate = phone ? [NSPredicate predicateWithFormat:@"phone == %@", phone] : nil;
    
    if (emailPredicate && phonePredicate) {
        return [NSCompoundPredicate orPredicateWithSubpredicates:@[emailPredicate, phonePredicate]];
    } else if (emailPredicate) {
        return emailPredicate;
    } else {
        return phonePredicate;
    }
}

- (MockConnection *)createConnectionFrom:(MockUser *)fromUser to:(MockUser *)toUser message:(NSString *)message;
{
    MockConversation *existingConversation;
    for (MockConnection *connection in fromUser.connectionsFrom) {
        if (connection.to == toUser) {
            existingConversation = connection.conversation;
            break;
        }
    }
    MockConnection *connection = [MockConnection connectionInMOC:self.managedObjectContext from:fromUser to:toUser message:message];
    connection.status = @"sent";
    MockConversation *conversation = existingConversation ?: [MockConversation conversationInMoc:self.managedObjectContext withCreator:fromUser otherUsers:@[] type:ZMTConversationTypeConnection];
    [conversation connectRequestByUser:fromUser toUser:toUser message:message];
    connection.conversation = conversation;
    return connection;
    
}

@end
