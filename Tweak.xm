#import "Hooks.h"
#import "Menu.h"

%ctor {
    [[PurpouHooks shared] setup];
    [[PurpouMenu shared] show]; 
    
    // Se o app voltar do background, recria a janela de gestos se necessário
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        [[PurpouMenu shared] checkAndSetupGesture];
    }];
    
    NSLog(@"[PURPOU] Carregado. Gesto de 3 dedos (5x) para abrir.");
}
