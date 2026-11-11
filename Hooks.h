#pragma once
#import <Foundation/Foundation.h>

@interface PurpouHooks : NSObject
+ (instancetype)shared;
- (void)setup;
- (void)toggleSpeed:(BOOL)on;
- (void)toggleAcceleration:(BOOL)on;
- (void)toggleNoDamage:(BOOL)on;
- (void)toggleMoney:(BOOL)on;
- (void)toggleAutoCNH:(BOOL)on;
- (void)toggleUnlockVehicles:(BOOL)on;
@end
