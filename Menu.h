#pragma once
#import <UIKit/UIKit.h>

@interface PurpouMenu : NSObject
+ (instancetype)shared;
- (void)show;
- (void)hide;
- (void)setupHooks;
- (void)checkAndSetupGesture;
@end
