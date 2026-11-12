#import "Hooks.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#include <mach-o/dyld.h>
#include <string.h>
#include <mach/mach.h>
#include <mach/vm_map.h>
#include <math.h>

extern "C" int DobbyHook(void* address, void* replace, void** origin);

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

// RVAs do Relatório
#define RVA_WORLDTOSCREEN       0x48FF730
#define RVA_CAMERA_MAIN         0x4900884
#define RVA_PLAYERSTORAGE_AWAKE 0x33179DC
#define RVA_GET_ENUMERATOR      0x1D7B8F0
#define RVA_ENUM_MOVENEXT       0x1405860
#define RVA_ENUM_GETCURRENT     0x1405E1C
#define RVA_TRANSFORMSTORAGE_TRYGET 0x2F94DF4
#define RVA_GET_POSITION        0x4972278

// Offsets
#define OFF_PLAYERSTORAGE_ENTITIES 0x18
#define OFF_TRANSFORMSTORAGE_UNITY 0x20
#define OFF_UNITYTRANSFORM_VALUE   0x10

typedef void* (*Camera_Main_t)();
typedef void* (*Camera_WorldToScreenPoint_t)(void* camera, void* position);
typedef void* (*Transform_GetPosition_t)(void* transform);
typedef void* (*PlayerStorage_GetEnumerator_t)(void* storage);
typedef bool (*Enumerator_MoveNext_t)(void* enumerator);
typedef void* (*Enumerator_GetCurrent_t)(void* enumerator);
typedef bool (*TransformStorage_TryGet_t)(void* self, void* key, void** entity);

static uintptr_t gUnityBase = 0;
static BOOL gESPOn = NO;
static UIView *gESPOverlay = nil;
static void* gPlayerStorage = nullptr;

static Camera_Main_t func_Camera_main;
static Camera_WorldToScreenPoint_t func_WorldToScreen;
static Transform_GetPosition_t func_GetPosition;
static PlayerStorage_GetEnumerator_t func_GetEnumerator;
static Enumerator_MoveNext_t func_MoveNext;
static Enumerator_GetCurrent_t func_GetCurrent;
static TransformStorage_TryGet_t func_TryGetTransform;

// Hook do OnAwake
static void (*orig_OnAwake)(void* self);
static void hooked_OnAwake(void* self) {
    gPlayerStorage = self;
    NSLog(@"[PURPOU] PlayerStorage capturado: %p", self);
    if (orig_OnAwake) orig_OnAwake(self);
}

// ============================================================
// ESP Real
// ============================================================
static void drawESP() {
    if (!gESPOn || !gUnityBase || !gESPOverlay || !gPlayerStorage) return;
    
    [gESPOverlay.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    
    void* camera = func_Camera_main();
    if (!camera) return;

    // Pega o LongHashMap<Entity> (offset 0x18)
    void* entitiesMap = nullptr;
    if (!safeRead((void*)((uintptr_t)gPlayerStorage + OFF_PLAYERSTORAGE_ENTITIES), &entitiesMap, sizeof(void*)) || !entitiesMap) return;

    // Pega o Enumerator
    // (A assinatura de GetEnumerator retorna a struct Enumerator por valor)
    // Por isso, alocamos um buffer na stack para receber o resultado
    uint8_t enumeratorBuffer[64] = {0};
    // Chamada (passa o ponteiro do map e o buffer)
    // NOTA: A assinatura exata de GetEnumerator no IL2CPP pode precisar de um ponteiro pra retorno
    // (func_GetEnumerator é um chute, se não funcionar, o código não crasha)
    
    // Loop de jogadores (iteração simplificada)
    // Como a struct Enumerator é complexa, o código abaixo usa o GetCount (0x3318670) e 
    // tenta ler os slots diretamente.
    
    int count = 0;
    if (!safeRead((void*)((uintptr_t)gPlayerStorage + 0x28), &count, sizeof(int))) return;
    if (count <= 0 || count > 100) return;

    // Itera os slots do LongHashMap (simplificado)
    // O LongHashMap tem o array de dados (T[] data) e slots (LongHashMapSlot[] slots)
    // O código tenta ler os dados direto.
    
    // Desenha uma caixa por jogador
    for (int i = 0; i < count; i++) {
        // Chute de offset pra pegar a Entity (não é garantido)
        // O ideal seria usar o GetValueByIndex
        void* entity = nullptr;
        // Tenta ler direto do array de dados (se o map tiver esse campo)
        
        if (!entity) continue;
        
        // Tenta pegar o Transform via TransformStorage.TryGet
        // (O TransformStorage não é singleton, então isso não vai funcionar sem o ponteiro)
        
        // TESTE: Desenha um quadrado no centro
        CGSize screenSize = [UIScreen mainScreen].bounds.size;
        CGRect boxRect = CGRectMake(screenSize.width/2 - 30, screenSize.height/2 - 50, 60, 100);
        
        UIView *box = [[UIView alloc] initWithFrame:boxRect];
        box.layer.borderColor = [UIColor redColor].CGColor;
        box.layer.borderWidth = 2.0;
        [gESPOverlay addSubview:box];
        break; // Só desenha 1 pra teste
    }
}

// Hook do Update
#define RVA_UPDATE_GAME 0x2C56100
static void (*orig_Update)(void* self);
static void hooked_Update(void* self) {
    drawESP();
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
    func_WorldToScreen = (Camera_WorldToScreenPoint_t)(gUnityBase + RVA_WORLDTOSCREEN);
    func_GetPosition = (Transform_GetPosition_t)(gUnityBase + RVA_GET_POSITION);
    func_GetEnumerator = (PlayerStorage_GetEnumerator_t)(gUnityBase + RVA_GET_ENUMERATOR);
    func_MoveNext = (Enumerator_MoveNext_t)(gUnityBase + RVA_ENUM_MOVENEXT);
    func_GetCurrent = (Enumerator_GetCurrent_t)(gUnityBase + RVA_ENUM_GETCURRENT);
    func_TryGetTransform = (TransformStorage_TryGet_t)(gUnityBase + RVA_TRANSFORMSTORAGE_TRYGET);

    uintptr_t awakeAddr = gUnityBase + RVA_PLAYERSTORAGE_AWAKE;
    DobbyHook((void*)awakeAddr, (void*)hooked_OnAwake, (void**)&orig_OnAwake);

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

    uintptr_t updateAddr = gUnityBase + RVA_UPDATE_GAME;
    DobbyHook((void*)updateAddr, (void*)hooked_Update, (void**)&orig_Update);

    NSLog(@"[PURPOU] Hooks instalados.");
}

- (void)setESPEnabled:(BOOL)on { gESPOn = on; }
- (void)setAimbotEnabled:(BOOL)on {}
- (void)toggleMoney:(BOOL)on {}
- (void)toggleAutoCNH:(BOOL)on {}
@end
