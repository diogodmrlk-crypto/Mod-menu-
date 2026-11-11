#pragma once
#import <UIKit/UIKit.h>

@interface PurpouMenu : NSObject
+ (instancetype)shared;
- (void)show;              // Abre o menu grande
- (void)showMinimized;     // Abre só a barrinha
- (void)hide;
@end
