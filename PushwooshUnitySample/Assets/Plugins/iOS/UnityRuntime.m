//
//  PushRuntime.m
//  Pushwoosh SDK
//  (c) Pushwoosh 2012
//

#import "PushNotificationManager.h"
#import <objc/runtime.h>

char * g_tokenStr = 0;
char * g_registerErrStr = 0;
char * g_pushMessageStr = 0;
char * g_listenerName = 0;
bool g_launchNotificationCleared = false;

void registerForRemoteNotifications() {
	[[PushNotificationManager pushManager] registerForPushNotifications];
}

void initializePushManager(char *appId, char *appName) {
	NSString *appCodeStr = [[NSString alloc] initWithUTF8String:appId];
	NSString *appNameStr = [[NSString alloc] initWithUTF8String:appName];
	[PushNotificationManager initializeWithAppCode:appCodeStr appName:appNameStr];

	[[PushNotificationManager pushManager] sendAppOpen];
	[PushNotificationManager pushManager].delegate = (NSObject<PushNotificationDelegate> *)[UIApplication sharedApplication];
}

void unregisterForRemoteNotifications() {
	[[PushNotificationManager pushManager] unregisterForPushNotifications];
}

void * _getPushToken()
{
	return (void *)[[[PushNotificationManager pushManager] getPushToken] UTF8String];
}

void * _getPushwooshHWID()
{
	return (void *)[[[PushNotificationManager pushManager] getHWID] UTF8String];
}

void * _getLaunchNotification() {
	if (g_launchNotificationCleared) {
		return NULL;
	}

	NSDictionary *notificationDict = [PushNotificationManager pushManager].launchNotification;
	if (notificationDict) {
		NSData *jsonData = [NSJSONSerialization dataWithJSONObject:notificationDict options:0 error:nil];
		NSString *launchNotification = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
		return (void *)[launchNotification UTF8String];
	}
	return NULL;
}

void _clearLaunchNotification() {
	g_launchNotificationCleared = true;
}

void _setUserId(char *userId) {
	NSString *userIdStr = [[NSString alloc] initWithUTF8String:userId];
	[[PushNotificationManager pushManager] setUserId:userIdStr];
}

void _postEvent(char *event, char *attributes) {
	NSString *eventStr = [[NSString alloc] initWithUTF8String:event];
	NSString *attributesStr = [[NSString alloc] initWithUTF8String:attributes];

	NSDictionary *json = [NSJSONSerialization JSONObjectWithData:[attributesStr dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
	if ([json isKindOfClass:[NSDictionary class]]) {
		[[PushNotificationManager pushManager] postEvent:eventStr withAttributes:json];
	}
	else {
		NSLog(@"Invalid postEvent attribute argument: %@", json);
	}
}

void setListenerName(char * listenerName)
{
	free(g_listenerName); g_listenerName = 0;
	int len = strlen(listenerName);
	g_listenerName = malloc(len+1);
	strcpy(g_listenerName, listenerName);
	
	if(g_tokenStr) {
		UnitySendMessage(g_listenerName, "onRegisteredForPushNotifications", g_tokenStr);
		free(g_tokenStr); g_tokenStr = 0;
	}
	
	if(g_registerErrStr) {
		UnitySendMessage(g_listenerName, "onFailedToRegisteredForPushNotifications", g_registerErrStr);
		free(g_registerErrStr); g_registerErrStr = 0;
	}
	
	if(g_pushMessageStr) {
		UnitySendMessage(g_listenerName, "onPushNotificationsReceived", g_pushMessageStr);
		free(g_pushMessageStr); g_pushMessageStr = 0;
	}
}

void setIntTag(char * tagName, int tagValue)
{
	NSString *tagNameStr = [[NSString alloc] initWithUTF8String:tagName];
	NSDictionary * dict = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:tagValue], tagNameStr, nil];
	[[PushNotificationManager pushManager] setTags:dict];
	
#if !__has_feature(objc_arc)
	[tagNameStr release];
#endif
}

void setStringTag(char * tagName, char * tagValue)
{
	NSString *tagNameStr = [[NSString alloc] initWithUTF8String:tagName];
	NSString *tagValueStr = [[NSString alloc] initWithUTF8String:tagValue];
	
	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:tagValueStr, tagNameStr, nil];
	[[PushNotificationManager pushManager] setTags:dict];
    
#if !__has_feature(objc_arc)
	[tagNameStr release];
	[tagValueStr release];
#endif
}

void internalSendStringTags (char * tagName, char** tags) {
    size_t length = 0;
    while (tags[length] != NULL) length++;
    
    NSMutableArray *tagsArray = [NSMutableArray array];
    NSString *tagNameStr = [[NSString alloc] initWithUTF8String:tagName];
    
    for (int i = 0; i < length; i++) {
        char *tagValue = tags[i];
        NSString *tagValueStr = [[NSString alloc] initWithUTF8String:tagValue];
        
        if (tagValueStr) {
            [tagsArray addObject:tagValueStr];
        }
#if !__has_feature(objc_arc)
        [tagValueStr release];
#endif
    }
    
    if (tagsArray.count) {
        [[PushNotificationManager pushManager] setTags:@{tagNameStr : tagsArray}];
    }
#if !__has_feature(objc_arc)
    [tagNameStr release];
#endif
}

void startLocationTracking()
{
	[[PushNotificationManager pushManager] startLocationTracking];
}

void clearNotificationCenter()
{
	[PushNotificationManager clearNotificationCenter];
}

void stopLocationTracking()
{
	[[PushNotificationManager pushManager] stopLocationTracking];
}

void setBadgeNumber(int badge)
{
	[[UIApplication sharedApplication] setApplicationIconBadgeNumber:badge];
}

void addBadgeNumber(int deltaBadge)
{
	int badge = [UIApplication sharedApplication].applicationIconBadgeNumber + deltaBadge;
	setBadgeNumber(badge);
}

@implementation UIApplication(InternalPushRuntime)

- (NSObject<PushNotificationDelegate> *)getPushwooshDelegate {
	return (NSObject<PushNotificationDelegate> *)[UIApplication sharedApplication];
}

- (BOOL) pushwooshUseRuntimeMagic {
	return YES;
}

//succesfully registered for push notifications
- (void) onDidRegisterForRemoteNotificationsWithDeviceToken:(NSString *)token
{
	const char * str = [token UTF8String];
	if(!g_listenerName) {
		g_tokenStr = malloc(strlen(str)+1);
		strcpy(g_tokenStr, str);
		return;
	}
	
	UnitySendMessage(g_listenerName, "onRegisteredForPushNotifications", str);
}

//failed to register for push notifications
- (void) onDidFailToRegisterForRemoteNotificationsWithError:(NSError *)error
{
	const char * str = [[error description] UTF8String];
	if(!g_listenerName) {
		if (str) {
			g_registerErrStr = malloc(strlen(str)+1);
			strcpy(g_registerErrStr, str);
		}
		return;
	}
	
	UnitySendMessage(g_listenerName, "onFailedToRegisteredForPushNotifications", str);
}

//handle push notification, display alert, if this method is implemented onPushAccepted will not be called, internal message boxes will not be displayed
- (void) onPushAccepted:(PushNotificationManager *)pushManager withNotification:(NSDictionary *)pushNotification onStart:(BOOL)onStart
{
	NSData *jsonData = [NSJSONSerialization dataWithJSONObject:pushNotification options:0 error:nil];
	NSString *jsonRequestData = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

	const char * str = [jsonRequestData UTF8String];
	
	if(!g_listenerName) {
		g_pushMessageStr = malloc(strlen(str)+1);
		strcpy(g_pushMessageStr, str);
		return;
	}
	
	UnitySendMessage(g_listenerName, "onPushNotificationsReceived", str);
}

@end
