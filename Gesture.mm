#import "Gesture.h"
#import "Menu.h"

@implementation PurpouGesture {
    NSInteger _tapCount;
    NSTimer *_resetTimer;
    UIView *_detectorView;
    UIWindow *_detectorWindow;
}

+ (instancetype)shared {
    static PurpouGesture *inst = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ inst = [PurpouGesture new]; });
    return inst;
}

- (void)start {
    dispatch_async(dispatch_get_main_queue(), ^{
        // Cria uma janela invisível só pra capturar o toque em qualquer lugar
        UIWindowScene *scene = nil;
        for (UIScene *s in [UIApplication sharedApplication].connectedScenes)
            if ([s isKindOfClass:[UIWindowScene class]]) { scene = (UIWindowScene*)s; break; }

        _detectorWindow = scene ? [[UIWindow alloc] initWithWindowScene:scene] : [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        _detectorWindow.frame = [UIScreen mainScreen].bounds;
        _detectorWindow.windowLevel = UIWindowLevelAlert + 2000; // Acima de tudo
        _detectorWindow.backgroundColor = [UIColor clearColor];
        _detectorWindow.hidden = NO;

        _detectorView = [[UIView alloc] initWithFrame:_detectorWindow.bounds];
        _detectorView.backgroundColor = [UIColor clearColor];
        _detectorView.userInteractionEnabled = YES;
        _detectorView.multipleTouchEnabled = YES;
        _detectorWindow.rootViewController = [UIViewController new];
        [_detectorWindow.rootViewController.view addSubview:_detectorView];

        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
        tap.numberOfTouchesRequired = 3;
        tap.numberOfTapsRequired = 5;
        [_detectorView addGestureRecognizer:tap];
    });
}

- (void)handleTap:(UITapGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateEnded) {
        NSLog(@"[PURPOU] Gesto detectado! Abrindo menu...");
        [[PurpouMenu shared] show];
    }
}

@end
