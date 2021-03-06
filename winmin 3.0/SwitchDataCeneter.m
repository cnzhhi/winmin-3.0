//
//  SwitchDataCeneter.m
//  SmartSwitch
//
//  Created by sdzg on 14-8-19.
//  Copyright (c) 2014年 itouchco.com. All rights reserved.
//

#import "SwitchDataCeneter.h"
#import "SwitchSyncService.h"

static NSTimeInterval localToRemoteFactor = 2.f;
static NSTimeInterval remoteToOfflineFactor = 3.f;

static dispatch_queue_t switch_datacenter_serial_queue() {
  static dispatch_queue_t sdzg_switch_datacenter_serial_queue;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
      sdzg_switch_datacenter_serial_queue = dispatch_queue_create(
          "switchdatacenter.com.itouchco.www", DISPATCH_QUEUE_SERIAL);
  });
  return sdzg_switch_datacenter_serial_queue;
}

@interface SwitchDataCeneter ()
@property (nonatomic, assign) UIBackgroundTaskIdentifier backgroundUpdateTask;
@end

@implementation SwitchDataCeneter
- (id)init {
  self = [super init];
  if (self) {
    self.switchs = [[DBUtil sharedInstance] getSwitchs];
    _switchsDict = [[NSMutableDictionary alloc] init];
    _switchTmpDict = [[NSMutableDictionary alloc] init];
    //这里一定不能使用self.switchs,因为覆写了switchs的get方法
    for (SDZGSwitch *aSwitch in _switchs) {
      if (aSwitch.mac) {
        [self.switchsDict setObject:aSwitch forKey:aSwitch.mac];
      }
    }
  }
  return self;
}

+ (instancetype)sharedInstance {
  static SwitchDataCeneter *instance;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
  return instance;
}

- (void)addSwitchFromServer:(NSArray *)switchs {
  for (SDZGSwitch *aSwitch in switchs) {
    [self.switchsDict setObject:aSwitch forKey:aSwitch.mac];
  }
}

- (void)updateAllSwitchStautsToOffLine {
  NSArray *switchs = [self.switchsDict allValues];
  dispatch_async(switch_datacenter_serial_queue(), ^{
      for (SDZGSwitch *aSwitch in switchs) {
        aSwitch.networkStatus = SWITCH_OFFLINE;
      }
  });
}

- (void)updateSocketStaus:(SocketStatus)socketStaus
            socketGroupId:(int)socketGroupId
                      mac:(NSString *)mac {
  dispatch_async(switch_datacenter_serial_queue(), ^{
      SDZGSwitch *aSwitch = [self.switchsDict objectForKey:mac];
      SDZGSocket *socket = [aSwitch.sockets objectAtIndex:socketGroupId - 1];
      socket.socketStatus = socketStaus;
  });
}

- (void)updateSwitchLockStaus:(LockStatus)lockStatus mac:(NSString *)mac {
  dispatch_async(switch_datacenter_serial_queue(), ^{
      //一定存在
      SDZGSwitch *aSwitch = [self.switchsDict objectForKey:mac];
      aSwitch.lockStatus = lockStatus;
  });
}

- (void)addSwitch:(SDZGSwitch *)aSwitch {
  if (aSwitch) {
    dispatch_async(switch_datacenter_serial_queue(), ^{
        [self.switchsDict setObject:aSwitch forKey:aSwitch.mac];
    });
  }
}

- (void)updateSwitch:(SDZGSwitch *)aSwitch {
  if (aSwitch) {
    dispatch_async(switch_datacenter_serial_queue(), ^{
        if ([[self.switchsDict allKeys] containsObject:aSwitch.mac]) {
          SDZGSwitch *oldSwitch = [self.switchsDict objectForKey:aSwitch.mac];
          oldSwitch.ip = aSwitch.ip;
          oldSwitch.port = aSwitch.port;
          oldSwitch.name = aSwitch.name;
          oldSwitch.lockStatus = aSwitch.lockStatus;
          oldSwitch.version = aSwitch.version;
          oldSwitch.networkStatus = aSwitch.networkStatus;

          NSArray *oldSockets = oldSwitch.sockets;
          NSArray *aSockets = aSwitch.sockets;
          for (int i = 0; i < oldSockets.count; i++) {
            SDZGSocket *oldSocket = oldSockets[i];
            SDZGSocket *aSocket = aSockets[i];
            oldSocket.socketStatus = aSocket.socketStatus;
          }
          [self.switchsDict setObject:oldSwitch forKey:aSwitch.mac];
        } else {
          [self.switchsDict setObject:aSwitch forKey:aSwitch.mac];
        }
    });
  }
}

- (void)updateTimerList:(NSArray *)timerList
                    mac:(NSString *)mac
          socketGroupId:(int)socketGroupId {
  dispatch_async(switch_datacenter_serial_queue(), ^{
      SDZGSwitch *aSwitch = [self.switchsDict objectForKey:mac];
      if (aSwitch && [aSwitch.sockets count] == 2) {
        SDZGSocket *socket = [aSwitch.sockets objectAtIndex:socketGroupId - 1];
        socket.timerList = [timerList mutableCopy];
        [self.switchsDict setObject:aSwitch forKey:mac];
      }
  });
}

- (void)updateSwitchImageName:(NSString *)imgName mac:(NSString *)mac {
  dispatch_async(switch_datacenter_serial_queue(), ^{
      SDZGSwitch *aSwitch = [self.switchsDict objectForKey:mac];
      if (aSwitch) {
        aSwitch.imageName = imgName;
        [self.switchsDict setObject:aSwitch forKey:mac];
      }
  });
}

- (void)updateDelayTime:(int)delayTime
            delayAction:(DelayAction)delayAction
                    mac:(NSString *)mac
          socketGroupId:(int)socketGroupId {
  dispatch_async(switch_datacenter_serial_queue(), ^{
      SDZGSwitch *aSwitch = [self.switchsDict objectForKey:mac];
      if (aSwitch && [aSwitch.sockets count] == 2) {
        SDZGSocket *socket = [aSwitch.sockets objectAtIndex:socketGroupId - 1];
        socket.delayTime = delayTime;
        socket.delayAction = delayAction;
        [self.switchsDict setObject:aSwitch forKey:mac];
      }
  });
}

- (void)updateSwitchName:(NSString *)switchName
             socketNames:(NSArray *)socketNames
                     mac:(NSString *)mac {
  dispatch_async(switch_datacenter_serial_queue(), ^{
      SDZGSwitch *aSwitch = [self.switchsDict objectForKey:mac];
      if (aSwitch) {
        aSwitch.name = switchName;
        NSArray *sockets = aSwitch.sockets;
        for (int i = 0; i < socketNames.count; i++) {
          SDZGSocket *socket = sockets[i];
          socket.name = socketNames[i];
        }
        [self.switchsDict setObject:aSwitch forKey:mac];
      }
  });
}

- (void)updateSocketImage:imgName
                  groupId:(int)groupId
                 socketId:(int)socketId
              whichSwitch:(SDZGSwitch *)whichSwitch {
  dispatch_async(switch_datacenter_serial_queue(), ^{
      SDZGSwitch *aSwitch = [self.switchsDict objectForKey:whichSwitch.mac];
      if (aSwitch && [aSwitch.sockets count] == 2) {
        SDZGSocket *socket = [aSwitch.sockets objectAtIndex:groupId - 1];
        NSMutableArray *imageNames =
            [NSMutableArray arrayWithArray:socket.imageNames];
        [imageNames replaceObjectAtIndex:socketId - 1 withObject:imgName];
        socket.imageNames = imageNames;
      }
  });
}

- (void)checkSwitchOnlineState:(SDZGSwitch *)aSwitch {
  NSTimeInterval current = [[NSDate date] timeIntervalSince1970];
  NSTimeInterval diff = current - aSwitch.lastUpdateInterval;
  if (diff > localToRemoteFactor * REFRESH_DEV_TIME &&
      aSwitch.networkStatus == SWITCH_LOCAL) {
    aSwitch.networkStatus = SWITCH_OFFLINE;
  } else if (diff > remoteToOfflineFactor * REFRESH_DEV_TIME &&
             aSwitch.networkStatus == SWITCH_REMOTE) {
    aSwitch.networkStatus = SWITCH_OFFLINE;
  }
}

- (NSArray *)switchsWithChangeStatus {
  NSTimeInterval current = [[NSDate date] timeIntervalSince1970];
  NSArray *switchs = [self.switchsDict allValues];
  for (SDZGSwitch *aSwitch in switchs) {
    NSTimeInterval diff = current - aSwitch.lastUpdateInterval;
    if ((aSwitch.networkStatus == SWITCH_NEW ||
         aSwitch.networkStatus == SWITCH_LOCAL) &&
        diff > localToRemoteFactor * REFRESH_DEV_TIME) {
      aSwitch.networkStatus = SWITCH_REMOTE;
    }
    if (aSwitch.networkStatus == SWITCH_REMOTE &&
        diff > remoteToOfflineFactor * REFRESH_DEV_TIME) {
      aSwitch.networkStatus = SWITCH_OFFLINE;
    }
  }
  //  NSSortDescriptor *netDescriptor =
  //      [[NSSortDescriptor alloc] initWithKey:@"networkStatus" ascending:YES];
  //  NSSortDescriptor *macDescriptor =
  //      [[NSSortDescriptor alloc] initWithKey:@"mac" ascending:YES];
  //  return [[self.switchsDict allValues]
  //      sortedArrayUsingDescriptors:@[ netDescriptor, macDescriptor ]];
  NSSortDescriptor *_idDescriptor =
      [[NSSortDescriptor alloc] initWithKey:@"_id" ascending:NO];
  return [[self.switchsDict allValues]
      sortedArrayUsingDescriptors:@[ _idDescriptor ]];
}

- (NSArray *)switchs {
  // TODO: 修复新扫描到的设备场景添加中找不到
  //  return [self.switchsDict allValues];
  //  return _switchs;
  //  NSSortDescriptor *netDescriptor =
  //      [[NSSortDescriptor alloc] initWithKey:@"networkStatus" ascending:YES];
  //  NSSortDescriptor *macDescriptor =
  //      [[NSSortDescriptor alloc] initWithKey:@"mac" ascending:YES];
  //  return [[self.switchsDict allValues]
  //      sortedArrayUsingDescriptors:@[ netDescriptor, macDescriptor ]];

  NSSortDescriptor *_idDescriptor =
      [[NSSortDescriptor alloc] initWithKey:@"_id" ascending:NO];
  return [[self.switchsDict allValues]
      sortedArrayUsingDescriptors:@[ _idDescriptor ]];
}

- (BOOL)isAllSwitchOffLine {
  BOOL result = YES;
  NSArray *switchs = [self.switchsDict allValues];
  for (SDZGSwitch *aSwitch in switchs) {
    if (aSwitch.networkStatus != SWITCH_OFFLINE) {
      result = NO;
      break;
    }
  }
  return result;
}

- (void)syncSwitchs {
  dispatch_async(GLOBAL_QUEUE, ^{
      [self beginBackgroundUpdateTask];
      [[DBUtil sharedInstance] saveSwitchs:[self switchs]];
      SwitchSyncService *service = [[SwitchSyncService alloc] init];
      //      for (int i = 0; i < 10; i++) {
      //        [NSThread sleepForTimeInterval:1];
      //      }
      [service
          uploadSwitchs:^(BOOL isSuccess) { [self endBackgroundUpdateTask]; }];
  });
}

- (void)beginBackgroundUpdateTask {
  self.backgroundUpdateTask = [[UIApplication sharedApplication]
      beginBackgroundTaskWithExpirationHandler:^{
          [self endBackgroundUpdateTask];
      }];
}

- (void)endBackgroundUpdateTask {
  [[UIApplication sharedApplication]
      endBackgroundTask:self.backgroundUpdateTask];
  self.backgroundUpdateTask = UIBackgroundTaskInvalid;
}

- (BOOL)removeSwitch:(SDZGSwitch *)aSwtich {
  dispatch_async(switch_datacenter_serial_queue(),
                 ^{ [self.switchsDict removeObjectForKey:aSwtich.mac]; });
  [[DBUtil sharedInstance] deleteSwitch:aSwtich.mac];
  return YES;
}

#pragma mark - 临时空间
- (void)addSwitchToTmp:(SDZGSwitch *)aSwitch
            completion:(void (^)(void))completion {
  dispatch_async(switch_datacenter_serial_queue(), ^{
      [self.switchTmpDict setObject:aSwitch forKey:aSwitch.mac];
      completion();
  });
}

- (void)removeSwitchFromTmp:(SDZGSwitch *)aSwitch {
  dispatch_async(switch_datacenter_serial_queue(),
                 ^{ [self.switchTmpDict removeObjectForKey:aSwitch.mac]; });
}

- (SDZGSwitch *)getSwitchFromTmpByMac:(NSString *)mac {
  __block SDZGSwitch *aSwitch;
  dispatch_sync(switch_datacenter_serial_queue(),
                ^{ aSwitch = [self.switchTmpDict objectForKey:mac]; });
  return aSwitch;
}
@end
