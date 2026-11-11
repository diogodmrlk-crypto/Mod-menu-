#import "Hooks.h"
#import "Menu.h"

%ctor {
    // 1. Inicia os hooks (Dinheiro, CNH, etc)
    [[PurpouHooks shared] setup];
    
    // 2. Inicia o Menu (e o detector de gestos)
    [[PurpouMenu shared] show]; 
    
    // 3. Se o app voltar do background, garante que a janela de gestos está ativa
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        [[PurpouMenu shared] checkAndSetupGesture];
    }];
    
    NSLog(@"[PURPOU] Carregado. Faça o gesto de 3 dedos (5x) para abrir o menu.");
}
