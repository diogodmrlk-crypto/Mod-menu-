#import "Menu.h"
#import "Hooks.h"

%ctor {
    // Espera 8 segundos pro jogo carregar o Unity e o mapa
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[PurpouHooks shared] setup];
        [[PurpouMenu shared] show];
    });
}
