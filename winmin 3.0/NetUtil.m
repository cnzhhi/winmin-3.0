//
//  NetUtil.m
//  winmin
//
//  Created by 文正光 on 14-7-25.
//  Copyright (c) 2014年 itouchco.com. All rights reserved.
//

#import "NetUtil.h"
#import "Reachability.h"

@interface NetUtil ()
@property (nonatomic, strong) Reachability *hostReach;
@end

@implementation NetUtil
+ (instancetype)sharedInstance {
  static NetUtil *instance;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{ instance = [[NetUtil alloc] init]; });
  return instance;
}

- (void)addNetWorkChangeNotification {
  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(reachabilityChanged:)
             name:kReachabilityChangedNotification
           object:nil];
  self.hostReach = [Reachability reachabilityWithHostname:kCheckNetworkWebsite];
  [self.hostReach startNotifier];
}

- (void)reachabilityChanged:(NSNotification *)note {
  Reachability *curReach = [note object];
  NSParameterAssert([curReach isKindOfClass:[Reachability class]]);
  NetworkStatus status = [curReach currentReachabilityStatus];
  switch (status) {
    case NotReachable:
      kSharedAppliction.networkStatus = NotReachable;
      debugLog(@"网络不可用");
      break;
    case ReachableViaWiFi:
      kSharedAppliction.networkStatus = ReachableViaWiFi;
      debugLog(@"网络改变为WIFI");
      break;
    case ReachableViaWWAN:
      kSharedAppliction.networkStatus = ReachableViaWWAN;
      debugLog(@"网络为蜂窝网络");
      break;
    default:
      kSharedAppliction.networkStatus = NotReachable;
      break;
  }
  [[NSNotificationCenter defaultCenter]
      postNotificationName:kNetChangedNotification
                    object:self];
}

- (NSString *)getIPWithHostName:(const NSString *)hostName {
  const char *hostN = [hostName UTF8String];
  struct hostent *phot;
  @try {
    phot = gethostbyname(hostN);
  }
  @catch (NSException *exception) {
    return nil;
  }
  if (phot != NULL) {
    struct in_addr ip_addr;
    memcpy(&ip_addr, phot->h_addr_list[0], 4);
    char ip[20] = { 0 };
    inet_ntop(AF_INET, &ip_addr, ip, sizeof(ip));

    NSString *strIPAddress = [NSString stringWithUTF8String:ip];
    return strIPAddress;
  } else {
    return nil;
  }
}

@end
