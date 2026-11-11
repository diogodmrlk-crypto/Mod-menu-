#import "Hooks.h"
#import "Menu.h"

%ctor {
    // Inicia os hooks de memória (RVAs achadas)
    [[PurpouHooks shared] setup];
    
    // Instala o hook de gesto de 3 dedos
    [[PurpouMenu shared] setupHooks];
    
    NSLog(@"[PURPOU] Carregado. Faça o gesto de 3 dedos (5x) para abrir o menu.");
}
