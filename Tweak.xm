#import "Hooks.h"
#import "Menu.h"

%ctor {
    // 1. Inicia os hooks de memória (Dinheiro, CNH, etc)
    [[PurpouHooks shared] setup];
    
    // 2. Instala o hook na UIWindow pra capturar os 3 dedos
    [[PurpouMenu shared] setupHooks];
    
    NSLog(@"[PURPOU] Carregado. Faça 5 toques seguidos com 3 dedos para abrir.");
}
