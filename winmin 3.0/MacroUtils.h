//
//  MacroUtils.h
//  SmartSwitch
//
//  Created by 文正光 on 14-8-21.
//  Copyright (c) 2014年 itouchco.com. All rights reserved.
//

#ifdef __OBJC__
#import <Reachability.h>
#import <GCDAsyncUdpSocket.h>
#import <MBProgressHUD.h>
#import <EGORefreshTableHeaderView.h>
#import <HexColor.h>
#import <UIView+Toast.h>
#import <AFNetworking.h>
#import <UIViewController+MJPopupViewController.h>
#import <ShareSDK/ShareSDK.h>

#import "CC3xMessage.h"
#import "SDZGSwitch.h"
#import "UdpRequest.h"
#import "PassValueDelegate.h"
#import "ViewUtil.h"
#import "FirstTimeConfig.h"
#import "SwitchDataCeneter.h"
#import "DB.h"
#import "DESUtil.h"
#import "UIImage+Color.h"
#import "UIView+NoDataView.h"
#import "AppDelegate.h"
#endif

#define SCREEN_WIDTH ([UIScreen mainScreen].bounds.size.width)
#define SCREEN_HEIGHT ([UIScreen mainScreen].bounds.size.height)
#define kSharedAppliction \
  ((AppDelegate *)[UIApplication sharedApplication].delegate)

#define kCheckNetworkWebsite @"www.baidu.com"

// UDP过期时间,单位秒
#define kUDPTimeOut -1
#define kCheckPrivateResponseInterval \
  0  //发送UDP内网请求后，检查是否有响应数据的间隔，单位为秒
#define kCheckPublicResponseInterval \
  0  //发送UDP外网请求后，检查是否有响应数据的间隔，单位为秒
#define kTryCount -1  //请求失败后自动尝试次数

//日志
#ifdef DEBUG
#define debugLog(...) NSLog(__VA_ARGS__)
#define debugMethod() NSLog(@"%s", __func__)
#else
#define debugLog(...)
#define debugMethod()
#endif

#define isEqualOrGreaterToiOS7 \
  ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0)
#define is4Inch ([[UIScreen mainScreen] bounds].size.height == 568)

#define PATH_OF_APP_HOME NSHomeDirectory()
#define PATH_OF_TEMP NSTemporaryDirectory()
#define PATH_OF_DOCUMENT                                                      \
  [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, \
                                       YES) objectAtIndex:0]
//延迟最大时间
#define kDelayMax 1440

#define DEFAULT_SWITCH_NAME NSLocalizedString(@"Smart Switch", nil)
#define DEFAULT_SOCKET1_NAME NSLocalizedString(@"Socket1", nil)
#define DEFAULT_SOCKET2_NAME NSLocalizedString(@"Socket2", nil)
#define socket_default_image @"099"
#define switch_default_image @"100"
#define switch_default_image_offline @"100_"
#define kSceneTemplateDict \
  @{                       \
    @"101" : @"客厅",    \
    @"102" : @"厨房",    \
    @"103" : @"卧室",    \
    @"104" : @"书房",    \
    @"105" : @"儿童房", \
    @"106" : @"玄关"     \
  }

//在家测试
#define isHome 0
#define kThemeColor [UIColor colorWithHexString:@"#28B92E"]

//是否当前版本第一次打开
#define kWelcomePageShowed @"WelcomePageShowed"
#define kCurrentVersion @"CurrentVersion"
#define kShake @"Shake"
#define kShowMac @"ShowMac"
//通知
#define kSceneDataChanged @"SceneDataChanged"
#define kLoginResponse @"LoginResponse"
#define kRegisterResponse @"RegisterResponse"
#define kLoginSuccess @"LoginSuccess"
#define kSwitchOnOffStateChange @"SwitchOnOffStateChange"
#define kSwitchNameChange @"SwitchNameChange"
#define kDelayQueryNotification @"DelayQueryNotification"
#define kDelaySettingNotification @"DelaySettingNotification"

#define kTimerListChanged @"TimerListChanged"
#define kTimerAddNotification @"TimerAddNotification"
#define kTimerUpdateNotification @"TimerUpdateNotification"
#define kTimerDeleteNotification @"TimerDeleteNotification"
#define kTimerEffectiveChangedNotifcation @"TimerEffectiveChangedNotifcation"

#define kSceneAddOrUpdateNotification @"SceneAddOrUpdateNotification"
#define kSceneExecuteResultNotification @"SceneExecuteResultNotification"
#define kSceneExecuteFinishedNotification @"SceneExecuteFinishedNotification"

//加密
#define __ENCRYPT(str) [DESUtil encryptString:str]
#define __DECRYPT(str) [DESUtil decryptString:str]

// json
#define __JSON(str)                                                   \
  [NSJSONSerialization                                                \
      JSONObjectWithData:[str dataUsingEncoding:NSUTF8StringEncoding] \
                 options:kNilOptions                                  \
                   error:nil]

#ifdef DEBUG
#define SERVER_IP @"192.168.0.89"
#else
#define SERVER_IP @"183.63.35.203"
#endif

#define SERVER_PORT 20002

#define APP_PORT 43690

#define DEVICE_PORT 56797

#define REFRESH_DEV_TIME 10

#define BROADCAST_ADDRESS @"255.255.255.255"

#define GLOBAL_QUEUE \
  dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
#define MAIN_QUEUE dispatch_get_main_queue()