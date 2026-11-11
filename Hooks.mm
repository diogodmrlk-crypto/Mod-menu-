#import "Hooks.h"
#import <objc/runtime.h>
#include <mach-o/dyld.h>
#include <string.h>
#include <mach/mach.h>
#include <mach/vm_map.h>

static uintptr_t getFrameworkBase(const char *name) {
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *n = _dyld_get_image_name(i);
        if (n && strstr(n, name)) return (uintptr_t)_dyld_get_image_header(i);
    }
    return 0;
}
static bool safeRead(void *addr, void *buf, size_t size) {
    if (!addr || !buf || size == 0) return false;
    uintptr_t a = (uintptr_t)addr;
    if (a < 0x100000000ULL) return false;
    vm_size_t out = 0;
    return vm_read_overwrite(mach_task_self(), (vm_address_t)a, size, (vm_address_t)buf, &out) == KERN_SUCCESS && out == size;
}

// ============================================================
// RVAs QUE VOCÊ ACHOU
// ============================================================
#define RVA_WORLDTOSCREEN   0x48FF730
#define RVA_GETBONETRANSFORM 0x1E1E500
#define RVA_CAMERA_MAIN     0x4900884

typedef void* (*Camera_Main_t)();
typedef void* (*Animator_GetBoneTransform_t)(void* animator, int humanBoneId);
typedef void* (*Camera_WorldToScreenPoint_t)(void* camera, void* position);

static uintptr_t gUnityBase = 0;
static BOOL gESPOn = NO;
static BOOL gAimbotOn = NO;
static UIView *gESPOverlay = nil;

static void drawESP() {
    if (!gESPOn || !gUnityBase || !gESPOverlay) return;
    
    Camera_Main_t Camera_main = (Camera_Main_t)(gUnityBase + RVA_CAMERA_MAIN);
    void* camera = Camera_main();
    if (!camera) return;
    
    Camera_WorldToScreenPoint_t WorldToScreen = (Camera_WorldToScreenPoint_t)(gUnityBase + RVA_WORLDTOSCREEN);
    
    [gESPOverlay.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    
    // Teste visual: desenha um quadrado no centro
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    CGRect boxRect = CGRectMake(screenSize.width/2 - 30, screenSize.height/2 - 50, 60, 100);
    
    UIView *box = [[UIView alloc] initWithFrame:boxRect];
    box.layer.borderColor = [UIColor redColor].CGColor;
    box.layer.borderWidth = 2.0;
    [gESPOverlay addSubview:box];
}

@implementation PurpouHooks
+ (instancetype)shared {
    static PurpouHooks *inst = nil; static dispatch_once_t once;
    dispatch_once(&once, ^{ inst = [PurpouHooks new]; });
    return inst;
}
- (void)setup {
    gUnityBase = getFrameworkBase("UnityFramework");
    if (!gUnityBase) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindowScene *scene = nil;
        for (UIScene *s in [UIApplication sharedApplication].connectedScenes)
            if ([s isKindOfClass:[UIWindowScene class]]) { scene = (UIWindowScene*)s; break; }
        UIWindow *win = scene ? [[UIWindow alloc] initWithWindowScene:scene] : [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        win.windowLevel = UIWindowLevelNormal - 1;
        win.backgroundColor = [UIColor clearColor];
        win.userInteractionEnabled = NO;
        win.rootViewController = [UIViewController new];
        win.hidden = NO;
        gESPOverlay = win.rootViewController.view;
    });
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 16 * NSEC_PER_MSEC, 0);
    dispatch_source_set_event_handler(timer, ^{ drawESP(); });
    dispatch_resume(timer);
}
- (void)setESPEnabled:(BOOL)on { gESPOn = on; }
- (void)setAimbotEnabled:(BOOL)on { gAimbotOn = on; }
- (void)toggleMoney:(BOOL)on {}
- (void)toggleAutoCNH:(BOOL)on {}
@end
