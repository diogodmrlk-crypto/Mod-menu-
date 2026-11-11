#import "Hooks.h"
#import "Gesture.h"

%ctor {
    // Inicia o detector de gestos e os hooks assim que a dylib carregar
    [[PurpouHooks shared] setup];
    [[PurpouGesture shared] start];
    NSLog(@"[PURPOU] Hooks e Gesture iniciados imediatamente.");
}
