#import "Menu.h"
#import "Hooks.h"
#import <objc/runtime.h>

// Declaração do Dobby
extern "C" int DobbyHook(void* address, void* replace, void** origin);

@class PurpouWindow;
static PurpouWindow *gOverlayWindow = nil;
static UIView *gMenuContainer = nil;
static UIView *gMiniBar = nil;
static BOOL gIsMinimized = NO;

// Variáveis do Hook de Toque
static NSInteger gTapCount = 0;
static NSTimer *gTapTimer = nil;
static void (*orig_sendEvent)(id, SEL, UIEvent *);

// A função que vai substituir a sendEvent: do UIWindow
static void hooked_sendEvent(id self, SEL _cmd, UIEvent *event) {
    if (event.type == UIEventTypeTouches) {
        NSSet *touches = [event allTouches];
        if (touches.count >= 3) {
            gTapCount++;
            [gTapTimer invalidate];
            gTapTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:NO block:^(NSTimer * _Nonnull timer) { gTapCount = 0; }];
            if (gTapCount >= 5) {
                gTapCount = 0;
                dispatch_async(dispatch_get_main_queue(), ^{ [[PurpouMenu shared] show]; });
            }
        }
    }
    // Chama a função original pra o jogo continuar funcionando
    if (orig_sendEvent) orig_sendEvent(self, _cmd, event);
}

// Cores do Menu
#define C_BG        [UIColor colorWithRed:0.08 green:0.08 blue:0.10 alpha:0.95]
#define C_SIDEBAR   [UIColor colorWithRed:0.05 green:0.05 blue:0.05 alpha:0.95]
#define C_ACCENT    [UIColor colorWithRed:0.8 green:0.3 blue:0.4 alpha:1.0]
#define C_TEXT      [UIColor whiteColor]
#define C_SUBTEXT   [UIColor lightGrayColor]

// (A UI do Menu é a mesma que você já tem, então vou omitir os detalhes pra focar no hook)
// ... [Aqui entra o código do PurpouToggle, PurpouMenuVC, etc, IGUAL ao que você já tem] ...

// ============================================================
// PurpouWindow: A janela que permite interagir com o menu
// ============================================================
@interface PurpouWindow : UIWindow
@property (nonatomic, weak) UIView *interactive1;
@end
@implementation PurpouWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *v = [super hitTest:point withEvent:event];
    if (!v) return nil;
    if (self.interactive1 && !self.interactive1.hidden) {
        CGPoint p = [self.interactive1 convertPoint:point fromView:self];
        if ([self.interactive1 pointInside:p withEvent:event]) return v;
    }
    return nil;
}
@end

@implementation PurpouMenu

+ (instancetype)shared {
    static PurpouMenu *inst = nil; static dispatch_once_t once;
    dispatch_once(&once, ^{ inst = [PurpouMenu new]; });
    return inst;
}

- (void)setupHooks {
    // Pega o endereço da função sendEvent: na classe UIWindow
    Method sendEventMethod = class_getInstanceMethod([UIWindow class], @selector(sendEvent:));
    void *sendEventAddr = method_getImplementation(sendEventMethod);

    // Usa o Dobby pra hookar
    DobbyHook(sendEventAddr, (void *)hooked_sendEvent, (void **)&orig_sendEvent);
    NSLog(@"[PURPOU] DobbyHook aplicado na sendEvent:.");
}

- (void)show {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (gOverlayWindow) return;
        UIWindowScene *scene = nil;
        for (UIScene *s in [UIApplication sharedApplication].connectedScenes)
            if ([s isKindOfClass:[UIWindowScene class]]) { scene = (UIWindowScene*)s; break; }
        
        PurpouWindow *win = scene ? [[PurpouWindow alloc] initWithWindowScene:scene] : [[PurpouWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        win.frame = [UIScreen mainScreen].bounds;
        win.windowLevel = UIWindowLevelAlert + 1000;
        win.backgroundColor = [UIColor clearColor];
        gOverlayWindow = win;
        
        // (Aqui você instancia o PurpouMenuVC e a UI)
    });
}

- (void)hide {
    dispatch_async(dispatch_get_main_queue(), ^{
        gOverlayWindow.hidden = YES;
        gOverlayWindow = nil;
        gMenuContainer = nil;
    });
}

- (void)checkAndSetupGesture {}
@end
