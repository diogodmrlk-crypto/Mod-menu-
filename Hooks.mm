#import "Hooks.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#include <mach-o/dyld.h>
#include <string.h>
#include <mach/mach.h>
#include <mach/vm_map.h>
#include <math.h>

// Dobby
extern "C" int DobbyHook(void* address, void* replace, void** origin);

// Helpers
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

// RVAs
#define RVA_WORLDTOSCREEN   0x48FF730
#define RVA_GETBONETRANSFORM 0x1E1E500
#define RVA_CAMERA_MAIN     0x4900884
#define RVA_PLAYER_STORAGE  0x331890C
#define RVA_GET_COUNT       0x2C56134
#define RVA_SET_ROTATION    0x2E0143C
#define RVA_UPDATE_PLAYER   0x2C56100 // Exemplo (se não funcionar, mudar)

typedef void* (*Camera_Main_t)();
typedef void* (*Animator_GetBoneTransform_t)(void* animator, int humanBoneId);
typedef void* (*Camera_WorldToScreenPoint_t)(void* camera, void* position);
typedef void* (*PlayerStorage_Get_t)();
typedef int   (*PlayerStorage_GetCount_t)(void* storage);
typedef void  (*Transform_SetRotation_t)(void* transform, void* quaternion);

static uintptr_t gUnityBase = 0;
static BOOL gESPOn = NO;
static BOOL gAimbotOn = NO;
static UIView *gESPOverlay = nil;
static float gFOV = 150.0f;

static Camera_Main_t func_Camera_main;
static Animator_GetBoneTransform_t func_GetBoneTransform;
static Camera_WorldToScreenPoint_t func_WorldToScreen;
static PlayerStorage_Get_t func_GetPlayerStorage;
static PlayerStorage_GetCount_t func_GetCount;
static Transform_SetRotation_t func_SetRotation;

// Função de Desenho
static void drawESP() {
    if (!gESPOn || !gUnityBase || !gESPOverlay) return;
    
    [gESPOverlay.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    
    void* camera = func_Camera_main();
    if (!camera) return;
    
    void* storage = func_GetPlayerStorage();
    if (!storage) return;
    
    int count = func_GetCount(storage);
    if (count <= 0) return;
    
    // Desenha uma caixa de teste pra provar que o loop tá rodando
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    CGRect boxRect = CGRectMake(screenSize.width/2 - 30, screenSize.height/2 - 50, 60, 100);
    
    UIView *box = [[UIView alloc] initWithFrame:boxRect];
    box.layer.borderColor = [UIColor redColor].CGColor;
    box.layer.borderWidth = 2.0;
    [gESPOverlay addSubview:box];
}

// Hook do Update
static void (*orig_Update)(void* self);
static void hooked_Update(void* self) {
    // Roda o ESP a cada frame
    drawESP();
    
    // Chama a função original
    if (orig_Update) orig_Update(self);
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

    func_Camera_main = (Camera_Main_t)(gUnityBase + RVA_CAMERA_MAIN);
    func_GetBoneTransform = (Animator_GetBoneTransform_t)(gUnityBase + RVA_GETBONETRANSFORM);
    func_WorldToScreen = (Camera_WorldToScreenPoint_t)(gUnityBase + RVA_WORLDTOSCREEN);
    func_GetPlayerStorage = (PlayerStorage_Get_t)(gUnityBase + RVA_PLAYER_STORAGE);
    func_GetCount = (PlayerStorage_GetCount_t)(gUnityBase + RVA_GET_COUNT);
    func_SetRotation = (Transform_SetRotation_t)(gUnityBase + RVA_SET_ROTATION);

    // Cria a janela do ESP
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

    // HOOK DO UPDATE (Pra rodar o ESP no loop do jogo)
    uintptr_t updateAddr = gUnityBase + RVA_UPDATE_PLAYER;
    DobbyHook((void*)updateAddr, (void*)hooked_Update, (void**)&orig_Update);

    NSLog(@"[PURPOU] Hooks (ESP e Aimbot) instalados!");
}

- (void)setESPEnabled:(BOOL)on { gESPOn = on; }
- (void)setAimbotEnabled:(BOOL)on { gAimbotOn = on; }
- (void)toggleMoney:(BOOL)on {}
- (void)toggleAutoCNH:(BOOL)on {}
@end
