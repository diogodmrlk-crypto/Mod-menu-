#pragma once
#import <Foundation/Foundation.h>

@interface PurpouHooks : NSObject
+ (instancetype)shared;
- (void)setup;
- (void)setESPEnabled:(BOOL)on;
- (void)setAimbotEnabled:(BOOL)on;
- (void)toggleMoney:(BOOL)on;
- (void)toggleAutoCNH:(BOOL)on;
@end
