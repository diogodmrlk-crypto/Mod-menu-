#import "Hooks.h"
#import <objc/runtime.h>
#import <substrate.h>
#include <mach-o/dyld.h>
#include <string.h>

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

static bool safeRead(void *addr, void *buf, size_t size) {
    if (!addr || !buf || size == 0) return false;
    uintptr_t a = (uintptr_t)addr;
    if (a < 0x100000000ULL) return false;
    vm_size_t out = 0;
    return vm_read_overwrite(mach_task_self(), (vm_address_t)a, size, (vm_address_t)buf, &out) == KERN_SUCCESS && out == size;
}

static bool safeWrite(void *addr, const void *buf, size_t size) {
    if (!addr || !buf || size == 0) return false;
    uintptr_t a = (uintptr_t)addr;
    if (a < 0x100000000ULL) return false;
    vm_protect(mach_task_self(), (vm_address_t)(a & ~0xFFF), 0x1000, false, VM_PROT_READ|VM_PROT_WRITE|VM_PROT_COPY);
    return vm_write(mach_task_self(), (vm_address_t)a, (vm_address_t)buf, size) == KERN_SUCCESS;
}

// ============================================================
// Offsets (do dump.cs)
// ============================================================
#define OFF_RCCP_ENGINE_MAX_SPEED       0x128
#define OFF_BIKE_SETTINGS_MAX_SPEED     0x14
#define OFF_ENGINE_ACCEL_RATE           0x5C
#define OFF_BIKE_SETTINGS_ACCEL         0x1C
#define OFF_DAMAGE_MAXIMUM              0x90
#define OFF_CARTEIRA_CREDITAR           0x1E49A28
#define OFF_HABILITACAO_APROVAR         0x21435E8
#define OFF_CAIXA_RECOLHER              0x1AE16EC

// ============================================================
// Estado global
// ============================================================
static BOOL gSpeedOn = NO;
static BOOL gAccelOn = NO;
static BOOL gNoDamageOn = NO;
static BOOL gAutoDriveOn = NO;
static BOOL gAutoCollectOn = NO;
static BOOL gMoneyOn = NO;
static BOOL gNoAdsOn = NO;
static BOOL gUnlockVehiclesOn = NO;

static dispatch_source_t gTickTimer = nil;

// ============================================================
// Funções originais (hooks)
// ============================================================
typedef void (*OverrideInputs_t)(void *self, void *overridedInputs);
static OverrideInputs_t orig_OverrideInputs = NULL;

typedef void (*OnCollision_t)(void *self, void *collision);
static OnCollision_t orig_OnCollision = NULL;

typedef void (*RecolherAoPassar_t)(void *self);
static RecolherAoPassar_t orig_RecolherAoPassar = NULL;

typedef BOOL (*Creditar_t)(int centavos, NSString *rotulo, int tipo);
static Creditar_t orig_Creditar = NULL;

// ============================================================
// Hooks
// ============================================================
static void hooked_OnCollision(void *self, void *collision) {
    if (gNoDamageOn) {
        // Força o campo "damageData" a ficar em zero após a colisão
        // O damageData fica no offset 0xD0 do RCCP_Damage
        uintptr_t selfAddr = (uintptr_t)self;
        uintptr_t damageDataAddr = selfAddr + 0xD0;
        float zero = 0.0f;
        safeWrite((void*)damageDataAddr, &zero, sizeof(float));
        return; // não processa colisão
    }
    if (orig_OnCollision) orig_OnCollision(self, collision);
}

static void hooked_RecolherAoPassar(void *self) {
    if (gAutoCollectOn) {
        // Chama a função várias vezes por frame pra forçar a coleta
        if (orig_RecolherAoPassar) {
            orig_RecolherAoPassar(self);
            orig_RecolherAoPassar(self);
            orig_RecolherAoPassar(self);
        }
        return;
    }
    if (orig_RecolherAoPassar) orig_RecolherAoPassar(self);
}

static BOOL hooked_Creditar(int centavos, NSString *rotulo, int tipo) {
    if (gMoneyOn) {
        // Quando o jogo for creditar algo, credita 10x
        return orig_Creditar ? orig_Creditar(centavos * 10, rotulo, tipo) : NO;
    }
    return orig_Creditar ? orig_Creditar(centavos, rotulo, tipo) : NO;
}

// ============================================================
// Tick loop (aplica velocidade, aceleração, auto-drive)
// ============================================================
static void applySpeedToVehicles(uintptr_t base) {
    // O RCCP_Engine é filho do CarController. Sem o offset do ponteiro,
    // varremos a memória próxima ao CarController.
    // Como fallback, hookamos os campos quando o jogo os lê.
}

static void tickLoop() {
    uintptr_t unityBase = getFrameworkBase("UnityFramework");
    if (!unityBase) return;

    // Auto Drive: força input de acelerar
    if (gAutoDriveOn) {
        // O campo throttleInput_V fica no offset 0x180 do RCCP_CarController.
        // Precisamos achar uma instância ativa. Sem o ponteiro do CarController,
        // o Auto Drive não consegue ser aplicado em tempo real.
        // Por enquanto, o toggle fica visual.
    }

    // Velocidade: precisamos do ponteiro do Engine ativo.
    // Sem o ponteiro, aplicamos via scan periódico (pesado).
    // Deixamos o toggle visual por enquanto.
}

// ============================================================
// Setup
// ============================================================
@implementation PurpouHooks

+ (instancetype)shared {
    static PurpouHooks *inst = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ inst = [PurpouHooks new]; });
    return inst;
}

- (void)setup {
    // Hook OnCollision do RCCP_Damage (Sem Dano)
    uintptr_t unity = getFrameworkBase("UnityFramework");
    if (unity) {
        uintptr_t onCollisionAddr = unity + 0x1947D90;
        MSHookFunction((void*)onCollisionAddr, (void*)hooked_OnCollision, (void**)&orig_OnCollision);

        uintptr_t recolherAddr = unity + 0x1AE16EC;
        MSHookFunction((void*)recolherAddr, (void*)hooked_RecolherAoPassar, (void**)&orig_RecolherAoPassar);

        uintptr_t creditarAddr = unity + 0x1E49A28;
        MSHookFunction((void*)creditarAddr, (void*)hooked_Creditar, (void**)&orig_Creditar);

        NSLog(@"[PURPOU] Hooks instalados na base 0x%lx", unity);
    } else {
        NSLog(@"[PURPOU] UnityFramework não encontrado.");
    }

    // Tick loop (1 Hz por segurança)
    gTickTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(gTickTimer, DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC, 0);
    dispatch_source_set_event_handler(gTickTimer, ^{ tickLoop(); });
    dispatch_resume(gTickTimer);
}

- (void)toggleSpeed:(BOOL)on {
    gSpeedOn = on;
    NSLog(@"[PURPOU] Velocidade: %d", on);
}

- (void)toggleAcceleration:(BOOL)on {
    gAccelOn = on;
    NSLog(@"[PURPOU] Aceleração: %d", on);
}

- (void)toggleUnlockVehicles:(BOOL)on {
    gUnlockVehiclesOn = on;
    NSLog(@"[PURPOU] Desbloquear veículos: %d (chama Desbloquear em cada veículo do catálogo)", on);
    // A implementação real precisa iterar CatalogoDeVeiculos.m_Veiculos (0x18)
    // e chamar PosseDeVeiculos.Desbloquear (0x1B3D54C).
    // Fica como TODO até termos o ponteiro do catálogo.
}

- (void)toggleMoney:(BOOL)on {
    gMoneyOn = on;
    NSLog(@"[PURPOU] Dinheiro x10: %d", on);
}

- (void)toggleNoAds:(BOOL)on {
    gNoAdsOn = on;
    NSLog(@"[PURPOU] Sem anúncios: %d", on);
    // Hook em Anuncios.IniciarSdkSeAutorizado (0x2155F48) pra não carregar
}

- (void)toggleNoDamage:(BOOL)on {
    gNoDamageOn = on;
    NSLog(@"[PURPOU] Sem dano: %d", on);
}

- (void)toggleAutoDrive:(BOOL)on {
    gAutoDriveOn = on;
    NSLog(@"[PURPOU] Piloto automático: %d", on);
}

- (void)toggleAutoCollect:(BOOL)on {
    gAutoCollectOn = on;
    NSLog(@"[PURPOU] Auto coleta: %d", on);
}

- (void)toggleAutoCNH:(BOOL)on {
    NSLog(@"[PURPOU] Auto CNH: %d", on);
    if (!on) return;
    uintptr_t unity = getFrameworkBase("UnityFramework");
    if (!unity) return;
    typedef BOOL (*Aprovar_t)(int tipo, float segundos);
    Aprovar_t aprovar = (Aprovar_t)(unity + 0x21435E8);
    if (aprovar) {
        aprovar(0, 9999.0f); // Carro
        aprovar(1, 9999.0f); // Moto
    }
}

@end
