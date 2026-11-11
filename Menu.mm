- (void)renderTab:(NSInteger)tab {
    for (UIView *v in contentArea.subviews) [v removeFromSuperview];
    UIStackView *col = [UIStackView new];
    col.axis = UILayoutConstraintAxisVertical;
    col.spacing = 10;
    col.translatesAutoresizingMaskIntoConstraints = NO;
    [contentArea addSubview:col];
    [NSLayoutConstraint activateConstraints:@[
        [col.topAnchor constraintEqualToAnchor:contentArea.topAnchor],
        [col.leadingAnchor constraintEqualToAnchor:contentArea.leadingAnchor],
        [col.trailingAnchor constraintEqualToAnchor:contentArea.trailingAnchor]
    ]];

    PurpouHooks *h = [PurpouHooks shared];

    if (tab == 0) { // Veículos
        [col addArrangedSubview:[[PurpouToggle alloc] initWithTitle:@"Desbloquear Todos" on:NO onChange:^(BOOL on){ [h toggleUnlockVehicles:on]; }]];
        [col addArrangedSubview:[[PurpouToggle alloc] initWithTitle:@"Velocidade Máxima" on:NO onChange:^(BOOL on){ [h toggleSpeed:on]; }]];
        [col addArrangedSubview:[[PurpouToggle alloc] initWithTitle:@"Aceleração Turbo" on:NO onChange:^(BOOL on){ [h toggleAcceleration:on]; }]];
        [col addArrangedSubview:[[PurpouToggle alloc] initWithTitle:@"Sem Dano" on:NO onChange:^(BOOL on){ [h toggleNoDamage:on]; }]];
    } else if (tab == 1) { // Money
        [col addArrangedSubview:[[PurpouToggle alloc] initWithTitle:@"Dinheiro Infinito" on:NO onChange:^(BOOL on){ [h toggleMoney:on]; }]];
        [col addArrangedSubview:[[PurpouToggle alloc] initWithTitle:@"Auto Salvar" on:YES onChange:^(BOOL on){ }]];
    } else { // Automático
        [col addArrangedSubview:[[PurpouToggle alloc] initWithTitle:@"Auto CNH" on:NO onChange:^(BOOL on){ [h toggleAutoCNH:on]; }]];
        [col addArrangedSubview:[[PurpouToggle alloc] initWithTitle:@"Auto Coleta (requer jailbreak)" on:NO onChange:^(BOOL on){ }]];
    }
}
