//
//  SwitchDetailModel.m
//  winmin 3.0
//
//  Created by sdzg on 14-9-19.
//  Copyright (c) 2014年 itouchco.com. All rights reserved.
//

#import "SwitchDetailModel.h"
#import "HistoryElec.h"
#define kElecRefreshInterval 2

@interface SwitchDetailModel ()<UdpRequestDelegate>
@property (strong, nonatomic) NSTimer *timer;
@property (strong, nonatomic) NSTimer *timerElec;
@property (nonatomic, strong) UdpRequest *request11Or13;
@property (nonatomic, strong) UdpRequest *request0BOr0D;
@property (nonatomic, strong) UdpRequest *request33Or35;
@property (nonatomic, strong) UdpRequest *request63;

@property (nonatomic, strong) SDZGSwitch *aSwitch;
@property (nonatomic, strong) HistoryElec *historyElec;
@property (nonatomic, strong) HistoryElecParam *param;
@property (nonatomic, assign) HistoryElecDateType dateType;
@end

@implementation SwitchDetailModel

- (id)initWithSwitch:(SDZGSwitch *)aSwitch {
  if (self = [super init]) {
    self.aSwitch = aSwitch;
  }
  return self;
}

- (void)openOrCloseWithGroupId:(int)groupId {
  dispatch_async(GLOBAL_QUEUE,
                 ^{ [self sendMsg11Or13:self.aSwitch groupId:groupId]; });
}

- (void)startScanSwitchState {
  _isScanning = YES;
  //加上0.1是避免和实时电量查询请求同时发出，降低同时发出的几率
  self.timer = [NSTimer timerWithTimeInterval:REFRESH_DEV_TIME + 0.1
                                       target:self
                                     selector:@selector(sendMsg0BOr0D)
                                     userInfo:nil
                                      repeats:YES];
  [self.timer fire];
  [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
}

- (void)stopScanSwitchState {
  _isScanning = NO;
  if (self.timer) {
    [self.timer invalidate];
    self.timer = nil;
  }
}

- (void)startRealTimeElec {
  self.timerElec = [NSTimer timerWithTimeInterval:kElecRefreshInterval
                                           target:self
                                         selector:@selector(sendMsg33Or35)
                                         userInfo:nil
                                          repeats:YES];
  [[NSRunLoop currentRunLoop] addTimer:self.timerElec
                               forMode:NSDefaultRunLoopMode];
  [self.timerElec fire];
}

- (void)stopRealTimeElec {
  [self.timerElec invalidate];
  self.timerElec = nil;
}

- (void)historyElec:(HistoryElecDateType)dateType {
  dispatch_async(GLOBAL_QUEUE, ^{
      if (!self.historyElec) {
        self.historyElec = [[HistoryElec alloc] init];
      }
      self.dateType = dateType;
      self.param =
          [self.historyElec getParam:[[NSDate date] timeIntervalSince1970]
                            dateType:dateType];
      [self senMsg63:self.param];
  });
}

//状态
- (void)sendMsg0BOr0D {
  if (!self.request0BOr0D) {
    self.request0BOr0D = [UdpRequest manager];
    self.request0BOr0D.delegate = self;
  }
  [self.request0BOr0D sendMsg0BOr0D:self.aSwitch sendMode:ActiveMode];
}

//控制开关
- (void)sendMsg11Or13:(SDZGSwitch *)aSwitch groupId:(int)groupId {
  if (!self.request11Or13) {
    self.request11Or13 = [UdpRequest manager];
    self.request11Or13.delegate = self;
  }
  [self.request11Or13 sendMsg11Or13:aSwitch
                      socketGroupId:groupId
                           sendMode:ActiveMode];
}

//实时电量
- (void)sendMsg33Or35 {
  if (!self.request33Or35) {
    self.request33Or35 = [UdpRequest manager];
    self.request33Or35.delegate = self;
  }
  [self.request33Or35 sendMsg33Or35:self.aSwitch sendMode:ActiveMode];
}

//历史电量
- (void)senMsg63:(HistoryElecParam *)param {
  if (!self.request63) {
    self.request63 = [UdpRequest manager];
    self.request63.delegate = self;
  }
  [self.request63 sendMsg63:self.aSwitch
                  beginTime:param.beginTime
                    endTime:param.endTime
                   interval:param.interval
                   sendMode:ActiveMode];
}

#pragma mark - UdpRequestDelegate
- (void)responseMsg:(CC3xMessage *)message address:(NSData *)address {
  switch (message.msgId) {
    //开关状态查询
    case 0xc:
    case 0xe:
      [self responseMsgCOrE:message];
      break;
    //开关控制
    case 0x12:
    case 0x14:
      [self responseMsg12Or14:message];
      break;
    //实时电量
    case 0x34:
    case 0x36:
      [self responseMsg34Or36:message];
      break;
    //历史电量
    case 0x64:
      [self responseMsg64:message];
      break;
  }
}

- (void)responseMsgCOrE:(CC3xMessage *)message {
  if (message.state == 0) {
    SDZGSwitch *aSwitch = [SDZGSwitch parseMessageCOrEToSwitch:message];
    if (aSwitch) {
      debugLog(@"############## recivied msg info");
      self.aSwitch = aSwitch;
      [[SwitchDataCeneter sharedInstance] updateSwitch:aSwitch];
      [[NSNotificationCenter defaultCenter]
          postNotificationName:kOneSwitchUpdate
                        object:self
                      userInfo:@{
                        @"switch" : aSwitch
                      }];
    }
  }
}

- (void)responseMsg12Or14:(CC3xMessage *)message {
  if (message.state == 0) {
    SDZGSocket *socket =
        [self.aSwitch.sockets objectAtIndex:message.socketGroupId - 1];
    socket.socketStatus = !socket.socketStatus;
    [self.aSwitch.sockets replaceObjectAtIndex:message.socketGroupId - 1
                                    withObject:socket];
    NSDictionary *userInfo = @{
      @"switch" : self.aSwitch,
      @"socketGroupId" : @(message.socketGroupId)
    };
    [[NSNotificationCenter defaultCenter]
        postNotificationName:kSwitchOnOffStateChange
                      object:self
                    userInfo:userInfo];
  }
}

- (void)responseMsg34Or36:(CC3xMessage *)message {
  debugLog(@"power is %f", message.power);
  NSDictionary *userInfo = @{ @"power" : @(message.power) };
  [[NSNotificationCenter defaultCenter]
      postNotificationName:kRealTimeElecNotification
                    object:self
                  userInfo:userInfo];
}

- (void)responseMsg64:(CC3xMessage *)message {
  if (message.state == 0) {
    HistoryElecData *data =
        [self.historyElec parseResponse:message.historyElecs param:self.param];
    //    debugLog(@"times is %@", data.times);
    //    debugLog(@"values is %@", data.values);
    NSDictionary *userInfo = @{
      @"data" : data,
      @"dateType" : @(self.dateType)
    };
    [[NSNotificationCenter defaultCenter]
        postNotificationName:kHistoryElecNotification
                      object:self
                    userInfo:userInfo];
  }
}
@end
