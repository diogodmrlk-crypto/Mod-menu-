#import "Hooks.h"
#import "Menu.h"

%ctor {
    // 1. Inicia os hooks de memória (RVAs achadas)
    [[PurpouHooks shared] setup];
    
    // 2. Instala o hook de toque via Dobby
    [[PurpouMenu shared] setupHooks];
    
    NSLog(@"[PURPOU] Carregado com Dobby.");
}
