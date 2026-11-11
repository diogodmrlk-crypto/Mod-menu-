#import "Hooks.h"
#import <objc/runtime.h>
#include <mach-o/dyld.h>
#include <string.h>
#include <mach/mach.h>
#include <mach/vm_map.h>

// Dobby (declaração manual)
extern "C" int DobbyHook(void* address, void* replace, void** origin);

// ============================================================
// Memory helpers
// ============================================================
static uintptr_t getFrameworkBase(const char *name) {
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *n = _dyld_get_image_name(i);
        if (n && strstr(n, name)) return (uintptr_t)_dyld_get_image_header(i);
    }
    return 0;
}

static bool safeWrite(void *addr, const void *buf, size_t size) {
    if (!addr || !buf || size == 0) return false;
    uintptr_t a = (uintptr_t)addr;
    if (a < 0x100000000ULL) return false;
    vm_protect(mach_task_self(), (vm_address_t)(a & ~0xFFF), 0x1000, false, VM_PROT_READ|VM_PROT_WRITE|VM_PROT_COPY);
    return vm_write(mach_task_self(), (vm_address_t)a, (vm_address_t)buf, size) == KERN_SUCCESS;
}

#define OFF_DAMAGE_DATA                 0xD0
#define OFF_CAIXA_RECOLHER              0x1AE16EC
#define OFF_CARTEIRA_CREDITAR           0x1E49A28
#define OFF_HABILITACAO_APROVAR         0x21435E8

static BOOL gSpeedOn = NO;
static BOOL gAccelOn = NO;
static BOOL gNoDamageOn = NO;
static BOOL gAutoDriveOn = NO;
static BOOL gAutoCollectOn = NO;
static BOOL gMoneyOn = NO;

typedef void (*OnCollision_t)(void *self, void *collision);
static OnCollision_t orig_OnCollision = NULL;

typedef void (*RecolherAoPassar_t)(void *self);
static RecolherAoPassar_t orig_RecolherAoPassar = NULL;

typedef BOOL (*Creditar_t)(int centavos, NSString *rotulo, int tipo);
static Creditar_t orig_Creditar = NULL;

static void hooked_OnCollision(void *self, void *collision) {
    if (gNoDamageOn) {
        uintptr_t damageDataAddr = (uintptr_t)self + OFF_DAMAGE_DATA;
        float zero = 0.0f;
        safeWrite((void*)damageDataAddr, &zero, sizeof(float));
        return;
    }
    if (orig_OnCollision) orig_OnCollision(self, collision);
}

static void hooked_RecolherAoPassar(void *self) {
    if (gAutoCollectOn && orig_RecolherAoPassar) {
        orig_RecolherAoPassar(self);
        orig_RecolherAoPassar(self);
        orig_RecolherAoPassar(self);
        return;
    }
    if (orig_RecolherAoPassar) orig_RecolherAoPassar(self);
}

static BOOL hooked_Creditar(int centavos, NSString *rotulo, int tipo) {
    if (gMoneyOn && orig_Creditar) {
        return orig_Creditar(centavos * 10, rotulo, tipo);
    }
    return orig_Creditar ? orig_Creditar(centavos, rotulo, tipo) : NO;
}

@implementation PurpouHooks

+ (instancetype)shared {
    static PurpouHooks *inst = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ inst = [PurpouHooks new]; });
    return inst;
}

- (void)setup {
    uintptr_t unity = getFrameworkBase("UnityFramework");
    if (!unity) return;

    DobbyHook((void*)(unity + 0x1947D90), (void*)hooked_OnCollision, (void**)&orig_OnCollision);
    DobbyHook((void*)(unity + OFF_CAIXA_RECOLHER), (void*)hooked_RecolherAoPassar, (void**)&orig_RecolherAoPassar);
    DobbyHook((void*)(unity + OFF_CARTEIRA_CREDITAR), (void*)hooked_Creditar, (void**)&orig_Creditar);

    NSLog(@"[PURPOU] Hooks com Dobby instalados.");
}

- (void)toggleSpeed:(BOOL)on { gSpeedOn = on; }
- (void)toggleAcceleration:(BOOL)on { gAccelOn = on; }
- (void)toggleUnlockVehicles:(BOOL)on { }
- (void)toggleMoney:(BOOL)on { gMoneyOn = on; }
- (void)toggleNoAds:(BOOL)on { }
- (void)toggleNoDamage:(BOOL)on { gNoDamageOn = on; }
- (void)toggleAutoDrive:(BOOL)on { gAutoDriveOn = on; }
- (void)toggleAutoCollect:(BOOL)on { gAutoCollectOn = on; }

- (void)toggleAutoCNH:(BOOL)on {
    if (!on) return;
    uintptr_t unity = getFrameworkBase("UnityFramework");
    if (!unity) return;
    typedef BOOL (*Aprovar_t)(int tipo, float segundos);
    Aprovar_t aprovar = (Aprovar_t)(unity + OFF_HABILITACAO_APROVAR);
    if (aprovar) {
        aprovar(0, 9999.0f);
        aprovar(1, 9999.0f);
    }
}

@end
