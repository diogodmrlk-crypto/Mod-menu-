#import "Hooks.h"
#import "Menu.h"

%ctor {
    // 1. Inicia os hooks (Dinheiro, CNH, etc) e o Scan de memória
    [[PurpouHooks shared] setup];
    
    // 2. Inicia o Menu. O próprio menu já liga o detector de gestos (3 dedos) 
    // e a janela invisível que não trava o jogo.
    [[PurpouMenu shared] show]; 
    
    NSLog(@"[PURPOU] Carregado. Faça o gesto de 3 dedos (5 vezes) para abrir o menu.");
}
