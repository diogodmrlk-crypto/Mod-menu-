#import "Hooks.h"
#import "Menu.h"

%ctor {
    [[PurpouHooks shared] setup];
    [[PurpouMenu shared] showMinimized];
    NSLog(@"[PURPOU] Carregado.");
}
