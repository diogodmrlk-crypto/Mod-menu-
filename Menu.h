#pragma once
#import <UIKit/UIKit.h>

@interface PurpouMenu : NSObject
+ (instancetype)shared;
- (void)show;
- (void)showMinimized;
- (void)hide;
@end
