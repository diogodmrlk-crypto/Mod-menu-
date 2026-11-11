#pragma once
#import <Foundation/Foundation.h>

@interface PurpouHooks : NSObject
+ (instancetype)shared;
- (void)setup;
- (void)toggleSpeed:(BOOL)on;
- (void)toggleAcceleration:(BOOL)on;
- (void)toggleUnlockVehicles:(BOOL)on;
- (void)toggleMoney:(BOOL)on;
- (void)toggleNoAds:(BOOL)on;
- (void)toggleNoDamage:(BOOL)on;
- (void)toggleAutoDrive:(BOOL)on;
- (void)toggleAutoCollect:(BOOL)on;
- (void)toggleAutoCNH:(BOOL)on;
@end
