#import "Hooks.h"
#import "Menu.h"

%ctor {
    // 1. Inicia os hooks de memória (RVAs)
    [[PurpouHooks shared] setup];
    
    // 2. Mostra a UI já na versão minimizada (barrinha)
    [[PurpouMenu shared] showMinimized];
    
    NSLog(@"[PURPOU] Carregado. Barrinha ativa.");
}
