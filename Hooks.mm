#import "Hooks.h"
#import <objc/runtime.h>
#include <mach-o/dyld.h>
#include <string.h>
#include <mach/mach.h>
#include <mach/vm_map.h>

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

static bool isHeapAddress(uintptr_t addr) {
    uintptr_t unityBase = getFrameworkBase("UnityFramework");
    if (!unityBase) return true;
    // Tamanho aprox do UnityFramework é ~92MB (do crash log)
    uintptr_t unityEnd = unityBase + 0x6000000;
    if (addr >= unityBase && addr < unityEnd) return false; // Não escreve em código
    return true;
}

static bool safeWrite(void *addr, const void *buf, size_t size) {
    if (!addr || !buf || size == 0) return false;
    uintptr_t a = (uintptr_t)addr;
    if (a < 0x100000000ULL) return false;
    if (!isHeapAddress(a)) return false; 
    
    vm_protect(mach_task_self(), (vm_address_t)(a & ~0xFFF), 0x1000, false, VM_PROT_READ|VM_PROT_WRITE|VM_PROT_COPY);
    return vm_write(mach_task_self(), (vm_address_t)a, (vm_address_t)buf, size) == KERN_SUCCESS;
}

#define OFF_ENGINE_MAX_SPEED    0x128
#define OFF_ENGINE_ACCEL        0x5C
#define OFF_DAMAGE_DATA         0xD0
#define OFF_CARTEIRA_CREDITAR   0x1E49A28
#define OFF_HABILITACAO_APROVAR 0x21435E8

static BOOL gSpeedOn = NO;
static BOOL gAccelOn = NO;
static BOOL gNoDamageOn = NO;
static dispatch_source_t gTimer = nil;
static uintptr_t gUnityBase = 0;

static void applyHacks() {
    if (!gUnityBase) return;
    // (A lógica de scan e aplicação dos offsets fica aqui, 
    // usando safeRead e safeWrite que já estão protegidos)
}

@implementation PurpouHooks

+ (instancetype)shared {
    static PurpouHooks *inst = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ inst = [PurpouHooks new]; });
    return inst;
}

- (void)setup {
    gUnityBase = getFrameworkBase("UnityFramework");
    if (!gUnityBase) {
        NSLog(@"[PURPOU] UnityFramework não encontrado.");
        return;
    }

    gTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(gTimer, DISPATCH_TIME_NOW, 500 * NSEC_PER_MSEC, 100 * NSEC_PER_MSEC);
    dispatch_source_set_event_handler(gTimer, ^{ applyHacks(); });
    dispatch_resume(gTimer);

    NSLog(@"[PURPOU] Modo sem hook ativo (protegido).");
}

- (void)toggleSpeed:(BOOL)on { gSpeedOn = on; }
- (void)toggleAcceleration:(BOOL)on { gAccelOn = on; }
- (void)toggleNoDamage:(BOOL)on { gNoDamageOn = on; }

- (void)toggleMoney:(BOOL)on {
    if (!on) return;
    typedef BOOL (*Creditar_t)(int, NSString*, int);
    Creditar_t creditar = (Creditar_t)(gUnityBase + OFF_CARTEIRA_CREDITAR);
    if (creditar) creditar(100000000, @"PURPOU", 0);
}

- (void)toggleAutoCNH:(BOOL)on {
    if (!on) return;
    typedef BOOL (*Aprovar_t)(int, float);
    Aprovar_t aprovar = (Aprovar_t)(gUnityBase + OFF_HABILITACAO_APROVAR);
    if (aprovar) {
        aprovar(0, 9999.0f);
        aprovar(1, 9999.0f);
    }
}

- (void)toggleUnlockVehicles:(BOOL)on {
    NSLog(@"[PURPOU] Desbloquear veículos: precisa do catálogo.");
}

@end
