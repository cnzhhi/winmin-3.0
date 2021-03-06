//
//  SwitchListModel.m
//  winmin 3.0
//
//  Created by sdzg on 14-9-17.
//  Copyright (c) 2014年 itouchco.com. All rights reserved.
//

#import "SwitchListModel.h"
#import "APServiceUtil.h"
@interface SwitchListModel () <UdpRequestDelegate>
@property (strong, nonatomic) NSTimer *timer;
@property (nonatomic, strong) NSString *mac; //扫描指定设备时使用

@property (strong, nonatomic) UdpRequest *request;
@property (strong, nonatomic) UdpRequest *request2; //用于闪烁和检查单个设备状态

//检查某个设备网络状态时使用
@property (strong, nonatomic) ScaneOneSwitchCompleteBlock completeBlock;
@property (strong, nonatomic) NSTimer *timerCheckOneSwitch;
@property (assign, nonatomic) BOOL isScanOneSwitch;
@property (assign, nonatomic) BOOL isRemote;
@property (strong, nonatomic) SDZGSwitch *currentSwitch;
//新添加设备的序列号，设备按序列号排序，扫描到一个设备，该值累加，零时的序列号，保存到数据库后序列号将更新，默认值100000
//配置时，默认值为200000
@property (assign, nonatomic) int switchId;
@end

@implementation SwitchListModel

- (id)init {
  self = [super init];
  if (self) {
    self.switchId = 100000;
    self.request = [UdpRequest manager];
    self.request.delegate = self;
    self.request2 = [UdpRequest manager];
    self.request2.delegate = self;
    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{ [self uploadDeviceAndAppInfo]; });
  }
  return self;
}

- (void)dealloc {
  self.request.delegate = nil;
  self.request2.delegate = nil;
}

- (void)startScanState {
  [self stopScanState];
  DDLogDebug(@"%s", __FUNCTION__);
  dispatch_async(MAIN_QUEUE, ^{
      _isScanningState = YES;
      self.timer = [NSTimer timerWithTimeInterval:REFRESH_DEV_TIME
                                           target:self
                                         selector:@selector(sendMsg0BOr0D)
                                         userInfo:nil
                                          repeats:YES];
      [self.timer fire];
      [[NSRunLoop mainRunLoop] addTimer:self.timer
                                forMode:NSRunLoopCommonModes];
  });
}

- (void)uploadDeviceAndAppInfo {
  [self.request2 sendMsg59WithSendMode:ActiveMode];
}

- (void)stopScanState {
  DDLogDebug(@"%s", __FUNCTION__);
  dispatch_async(MAIN_QUEUE, ^{
      _isScanningState = NO;
      if (self.timer) {
        [self.timer invalidate];
        self.timer = nil;
      }
  });
}

- (void)pauseScanState {
  if (![self.timer isValid]) {
    return;
  }
  _isScanningState = NO;
  [self.timer setFireDate:[NSDate distantFuture]];
}

- (void)resumeScanState {
  if (![self.timer isValid]) {
    return;
  }
  self.request.delegate = self;
  _isScanningState = YES;
  [self.timer setFireDate:[NSDate date]];
}

- (void)refreshSwitchList {
  [self pauseScanState];
  [self.request sendMsg09:ActiveMode];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)),
                 dispatch_get_main_queue(), ^{ [self resumeScanState]; });
}

- (void)addSwitchWithMac:(NSString *)mac password:(NSString *)password {
  SDZGSwitch *aSwitch = [SwitchDataCeneter sharedInstance].switchsDict[mac];
  if (aSwitch) {
    aSwitch._id = self.switchId++;
    aSwitch.networkStatus = SWITCH_NEW;
    aSwitch.password = password;
    aSwitch.name = NSLocalizedString(@"Smart Switch", nil);
    SDZGSocket *socket1 = aSwitch.sockets[0];
    socket1.imageNames =
        @[ socket_default_image, socket_default_image, socket_default_image ];
    SDZGSocket *socket2 = aSwitch.sockets[1];
    socket2.imageNames =
        @[ socket_default_image, socket_default_image, socket_default_image ];
    NSTimeInterval current = [[NSDate date] timeIntervalSince1970];
    NSArray *switchs = [[SwitchDataCeneter sharedInstance] switchs];
    for (SDZGSwitch *aSwitch in switchs) {
      aSwitch.lastUpdateInterval = current;
    }
  } else {
    self.mac = mac;
    [self refreshSwitchList];
  }
}

//扫描设备
- (void)sendMsg0BOr0D {
  //先局域网内扫描，0.5秒后请求外网，更新设备状态
  dispatch_async(GLOBAL_QUEUE, ^{
      [self.request sendMsg0B:ActiveMode];
      //设置0.5秒，保证内网的响应优先级
      [NSThread sleepForTimeInterval:0.5];
      NSArray *switchs = [[SwitchDataCeneter sharedInstance] switchs];
      for (SDZGSwitch *aSwitch in switchs) {
        if ((aSwitch.networkStatus == SWITCH_REMOTE ||
             aSwitch.networkStatus == SWITCH_OFFLINE) &&
            _isScanningState) {
          DDLogDebug(@"switch mac is %@", aSwitch.mac);
          [self.request sendMsg0D:aSwitch sendMode:ActiveMode tag:0];
        }
      }
  });
}

- (void)scanSwitchState:(SDZGSwitch *)aSwitch
               complete:(ScaneOneSwitchCompleteBlock)complete {
  if (!self.request2) {
    self.request2 = [UdpRequest manager];
    self.request2.delegate = self;
  }
  [self pauseScanState];
  self.request.delegate = nil;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)),
                 dispatch_get_main_queue(), ^{ self.request.delegate = self; });
  self.timerCheckOneSwitch =
      [NSTimer scheduledTimerWithTimeInterval:5.f
                                       target:self
                                     selector:@selector(checkSwitchStatus)
                                     userInfo:nil
                                      repeats:NO];
  self.currentSwitch = aSwitch;
  self.completeBlock = complete;
  self.isScanOneSwitch = YES;
  self.isRemote = NO;
  DDLogDebug(@"switch status is %d", aSwitch.networkStatus);
  if (aSwitch.networkStatus == SWITCH_REMOTE ||
      aSwitch.networkStatus == SWITCH_OFFLINE) {
    [self.request2 sendMsg0D:aSwitch sendMode:ActiveMode tag:0];
  } else {
    [self.request2 sendMsg0B:aSwitch sendMode:ActiveMode];
    [NSThread sleepForTimeInterval:0.1f];
    [self.request2 sendMsg0D:aSwitch sendMode:ActiveMode tag:0];
  }
}

- (void)stopScanOneSwitch {
  if (self.timerCheckOneSwitch) {
    [self.timerCheckOneSwitch invalidate];
    self.timerCheckOneSwitch = nil;
  }
}

- (void)blinkSwitch:(SDZGSwitch *)aSwitch {
  if (!self.request2) {
    self.request2 = [UdpRequest manager];
    self.request2.delegate = self;
  }
  [self.request sendMsg39Or3B:aSwitch on:YES sendMode:ActiveMode];
}

- (void)deleteSwitch:(SDZGSwitch *)aSwitch {
  [[SwitchDataCeneter sharedInstance] removeSwitch:aSwitch];
  [[DBUtil sharedInstance] removeSceneBySwitch:aSwitch];
  [[NSNotificationCenter defaultCenter] postNotificationName:kSwitchUpdate
                                                      object:self];
  [[NSNotificationCenter defaultCenter]
      postNotificationName:kSwitchDeleteSceneNotification
                    object:nil];
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  BOOL reciveRemoteNotification =
      [[defaults objectForKey:remoteNotification] boolValue];
  if (reciveRemoteNotification) {
    [APServiceUtil removeSwitchRemoteNotification:aSwitch
                                      finishBlock:^(BOOL result){}];
  }
}

#pragma mark -
- (void)checkSwitchStatus {
  if (self.isRemote) {
    self.completeBlock(SWITCH_REMOTE);
  } else {
    self.isScanOneSwitch = NO;
    self.completeBlock(-1);
    [self resumeScanState];
  }
}

#pragma mark - UdpRequestDelegate
- (void)udpRequest:(UdpRequest *)request
     didReceiveMsg:(CC3xMessage *)message
           address:(NSData *)address {
  switch (message.msgId) {
    //添加设备
    case 0xa:
      [self responseMsgA:message];
      break;
    //开关状态查询
    case 0xc:
    case 0xe:
      [self responseMsgCOrE:message request:request];
      break;
    //闪烁
    case 0x3a:
    case 0x3c:
      [self responseMsg3AOr3C:message];
      break;
    case 0x5a:
      DDLogDebug(@"设备信息已上传");
      break;
    default:
      break;
  }
}

- (void)responseMsgA:(CC3xMessage *)message {
  //添加指定mac地址的设备，配置时使用
  if (self.mac) {
    if (![self.mac isEqualToString:message.mac]) {
      return;
    }
    self.switchId = 200000;
  }
  if (message.version == kHardwareVersion) {
    SDZGSwitch *aSwitch = [[[SwitchDataCeneter sharedInstance] switchsDict]
        objectForKey:message.mac];
    if (!aSwitch && message.lockStatus == LockStatusOff) {
      //设备未加锁，并且不在本地列表中，发送请求，查询设备状态
      aSwitch = [[SDZGSwitch alloc] init];
      aSwitch._id = self.switchId++;
      aSwitch.mac = message.mac;
      aSwitch.ip = message.ip;
      aSwitch.port = message.port;
      aSwitch.networkStatus = SWITCH_NEW;
      [[SwitchDataCeneter sharedInstance]
          addSwitchToTmp:aSwitch
              completion:^{
                  [self.request sendMsg0B:aSwitch sendMode:ActiveMode];
              }];
    }
  }
  //删除指定mac，避免下拉刷新时使用该mac
  if (self.mac) {
    self.mac = nil;
  }
}

- (void)responseMsgCOrE:(CC3xMessage *)message request:(UdpRequest *)request {
  //  DDLogDebug(@"%s", __func__);
  if (self.isScanOneSwitch && request == self.request2) {
    if (message.state == kUdpResponseSuccessCode) {
      if (message.msgId == 0xc) {
        DDLogDebug(@"%@ msgId=0xc", [NSThread currentThread]);
        //设备内网
        //解决多个设备使用同一ip导致各种奇怪问题
        if ([message.mac isEqualToString:self.currentSwitch.mac]) {
          self.completeBlock(SWITCH_LOCAL);
        } else {
          self.completeBlock(-1);
        }
        [self stopScanOneSwitch];
      } else if (message.msgId == 0xe) {
        DDLogDebug(@"%@ msgId=0xe", [NSThread currentThread]);
        self.isRemote = YES;
        if (self.currentSwitch.networkStatus == SWITCH_REMOTE ||
            self.currentSwitch.networkStatus == SWITCH_OFFLINE) {
          self.completeBlock(SWITCH_REMOTE);
          [self stopScanOneSwitch];
        }
      }
    } else {
      //设备不在线
      if (message.state == kUdpResponsePasswordErrorCode) {
        //密码错误，设备被重新配置
        self.completeBlock(kUdpResponsePasswordErrorCode);
      } else {
        //设备离线
        self.completeBlock(-1);
      }
      [self stopScanOneSwitch];
      [self resumeScanState];
    }
    self.isScanOneSwitch = NO;
  } else if (request == self.request) {
    SDZGSwitch *aSwitchInTmp =
        [[SwitchDataCeneter sharedInstance] getSwitchFromTmpByMac:message.mac];
    SDZGSwitch *aSwitch = [[[SwitchDataCeneter sharedInstance] switchsDict]
        objectForKey:message.mac];
    if ((aSwitchInTmp || aSwitch) && message.version == kHardwareVersion &&
        message.state == kUdpResponseSuccessCode) {
      [SDZGSwitch parseMessageCOrE:message
                          toSwitch:^(SDZGSwitch *aSwitch) {
                              if (aSwitchInTmp) {
                                [[SwitchDataCeneter sharedInstance]
                                    removeSwitchFromTmp:aSwitchInTmp];
                                [[NSNotificationCenter defaultCenter]
                                    postNotificationName:kSwitchUpdate
                                                  object:self
                                                userInfo:nil];
                              }
                          }];
    }
  }
}

- (void)responseMsg3AOr3C:(CC3xMessage *)message {
  if (message.state == kUdpResponseSuccessCode) {
    //成功
  }
}

@end
