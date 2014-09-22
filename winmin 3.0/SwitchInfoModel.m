//
//  SwitchInfoModel.m
//  winmin 3.0
//
//  Created by sdzg on 14-9-22.
//  Copyright (c) 2014年 itouchco.com. All rights reserved.
//

#import "SwitchInfoModel.h"

@interface SwitchInfoModel ()<UdpRequestDelegate>
@property(nonatomic, strong) SDZGSwitch *aSwitch;
@property(nonatomic, strong) UdpRequest *request;
@end

@implementation SwitchInfoModel
- (id)initWithSwitch:(SDZGSwitch *)aSwitch {
  self = [super init];
  if (self) {
    self.aSwitch = aSwitch;
    self.request = [UdpRequest manager];
    self.request.delegate = self;
  }
  return self;
}

- (void)setSwitch:(SDZGSwitch *)aSwitch lockStatus:(LockStatus)lockStatus {
  [self.request sendMsg47Or49:aSwitch sendMode:ActiveMode];
}

- (void)setSwitchName:(NSString *)name {
  dispatch_async(GLOBAL_QUEUE, ^{ [self sendMsg3FOr41WithName:name]; });
}

- (void)sendMsg3FOr41WithName:(NSString *)name {
  [self.request sendMsg3FOr41:self.aSwitch
                         type:0
                         name:name
                     sendMode:ActiveMode];
}

#pragma mark - UdpRequest代理
- (void)responseMsg:(CC3xMessage *)message address:(NSData *)address {
  switch (message.msgId) {
    case 0x40:
    case 0x42:
      [self responseMsg40Or42:message];
    default:
      break;
  }
}
- (void)responseMsg40Or42:(CC3xMessage *)message {
  //  [[SwitchDataCeneter sharedInstance] updateSwitchName:self.switchName
  //                                           socketNames:@[]
  //                                                   mac:self.aSwitch.mac];

  message.socketGroupId;  // 0代表插座名字，1-n表示插孔n的名字
  message.state;
  debugLog(@"socketId is %d", message.socketGroupId);
}
@end
