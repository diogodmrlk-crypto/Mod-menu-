#import "Menu.h"
#import "Hooks.h"
#import <objc/runtime.h>

// Forward declaration pra o compilador saber que PurpouWindow existe
@class PurpouWindow;

// ============================================================
// Estado global
// ============================================================
static PurpouWindow *gOverlayWindow = nil;
static UIView *gMenuContainer = nil;
static UIView *gFloatingButton = nil;
static BOOL gVehicleESP = NO;
static BOOL gMoneyInf = NO;
static BOOL gAutoDrive = NO;

// ============================================================
// Cores PURPOU
// ============================================================
#define P_BG        [UIColor colorWithRed:0.08 green:0.08 blue:0.10 alpha:0.97]
#define P_BG2       [UIColor colorWithRed:0.13 green:0.13 blue:0.16 alpha:1.0]
#define P_ACCENT    [UIColor colorWithRed:0.55 green:0.25 blue:0.95 alpha:1.0]
#define P_TEXT      [UIColor colorWithWhite:0.95 alpha:1.0]
#define P_SUBTEXT   [UIColor colorWithWhite:0.6 alpha:1.0]

// ============================================================
// Botão com "squish"
// ============================================================
@interface PurpouButton : UIButton @end
@implementation PurpouButton
- (void)touchesBegan:(NSSet<UITouch*>*)t withEvent:(UIEvent*)e {
    [super touchesBegan:t withEvent:e];
    [UIView animateWithDuration:0.1 animations:^{ self.transform = CGAffineTransformMakeScale(0.94,0.94); }];
}
- (void)touchesEnded:(NSSet<UITouch*>*)t withEvent:(UIEvent*)e {
    [super touchesEnded:t withEvent:e];
    [UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:0.5 initialSpringVelocity:1.0 options:0 animations:^{ self.transform = CGAffineTransformIdentity; } completion:nil];
}
- (void)touchesCancelled:(NSSet<UITouch*>*)t withEvent:(UIEvent*)e {
    [super touchesCancelled:t withEvent:e];
    [UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:0.5 initialSpringVelocity:1.0 options:0 animations:^{ self.transform = CGAffineTransformIdentity; } completion:nil];
}
@end

// ============================================================
// PassThroughWindow
// ============================================================
@interface PurpouWindow : UIWindow
@property (nonatomic, weak) UIView *interactive1;
@property (nonatomic, weak) UIView *interactive2;
@end
@implementation PurpouWindow
- (UIView*)hitTest:(CGPoint)p withEvent:(UIEvent*)e {
    UIView *v = [super hitTest:p withEvent:e];
    if (!v) return nil;
    if (self.interactive1 && !self.interactive1.hidden) {
        CGPoint q = [self.interactive1 convertPoint:p fromView:self];
        if ([self.interactive1 pointInside:q withEvent:e]) return v;
    }
    if (self.interactive2 && !self.interactive2.hidden) {
        CGPoint q = [self.interactive2 convertPoint:p fromView:self];
        if ([self.interactive2 pointInside:q withEvent:e]) return v;
    }
    return nil;
}
@end

// ============================================================
// Toggle customizado
// ============================================================
@interface PurpouToggle : UIView
@property (nonatomic, assign) BOOL on;
@property (nonatomic, copy) void (^onChange)(BOOL);
@property (nonatomic, strong) UIView *knob;
@property (nonatomic, strong) UILabel *label;
@end

@implementation PurpouToggle
- (instancetype)initWithTitle:(NSString*)title on:(BOOL)on onChange:(void(^)(BOOL))cb {
    if (self = [super init]) {
        self.on = on;
        self.onChange = cb;
        self.translatesAutoresizingMaskIntoConstraints = NO;

        self.label = [UILabel new];
        self.label.text = title;
        self.label.textColor = P_TEXT;
        self.label.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        self.label.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:self.label];

        UIView *track = [UIView new];
        track.translatesAutoresizingMaskIntoConstraints = NO;
        track.layer.cornerRadius = 14;
        track.backgroundColor = on ? P_ACCENT : [UIColor colorWithWhite:0.25 alpha:1.0];
        track.tag = 100;
        [self addSubview:track];

        self.knob = [UIView new];
        self.knob.translatesAutoresizingMaskIntoConstraints = NO;
        self.knob.backgroundColor = [UIColor whiteColor];
        self.knob.layer.cornerRadius = 11;
        [track addSubview:self.knob];

        [NSLayoutConstraint activateConstraints:@[
            [self.label.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [self.label.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],

            [track.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [track.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [track.widthAnchor constraintEqualToConstant:52],
            [track.heightAnchor constraintEqualToConstant:28],

            [self.knob.widthAnchor constraintEqualToConstant:22],
            [self.knob.heightAnchor constraintEqualToConstant:22],
            [self.knob.centerYAnchor constraintEqualToAnchor:track.centerYAnchor],
            [self.knob.leadingAnchor constraintEqualToAnchor:track.leadingAnchor constant:on ? 27 : 3],

            [self.heightAnchor constraintEqualToConstant:40]
        ]];

        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggle)];
        [self addGestureRecognizer:tap];
    }
    return self;
}

- (void)toggle {
    self.on = !self.on;
    UIView *track = [self viewWithTag:100];
    [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.6 initialSpringVelocity:1.0 options:0 animations:^{
        track.backgroundColor = self.on ? P_ACCENT : [UIColor colorWithWhite:0.25 alpha:1.0];
        for (NSLayoutConstraint *c in self.knob.superview.constraints) {
            if (c.firstItem == self.knob && c.firstAttribute == NSLayoutAttributeLeading) {
                c.constant = self.on ? 27 : 3;
            }
        }
        [self layoutIfNeeded];
    } completion:nil];
    if (self.onChange) self.onChange(self.on);
}
@end

// ============================================================
// Menu principal
// ============================================================
@interface PurpouMenuVC : UIViewController
@end

@implementation PurpouMenuVC {
    NSArray *tabTitles;
    NSInteger currentTab;
    UIView *contentArea;
    UIView *tabButtonsBar;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    tabTitles = @[@"Veículos", @"Money", @"Automático"];
    currentTab = 0;
    [self buildMenu];
}

- (void)buildMenu {
    gMenuContainer = [UIView new];
    gMenuContainer.translatesAutoresizingMaskIntoConstraints = NO;
    gMenuContainer.backgroundColor = P_BG;
    gMenuContainer.layer.cornerRadius = 18;
    gMenuContainer.layer.borderWidth = 1;
    gMenuContainer.layer.borderColor = [P_ACCENT colorWithAlphaComponent:0.4].CGColor;
    gMenuContainer.layer.shadowColor = [UIColor blackColor].CGColor;
    gMenuContainer.layer.shadowOpacity = 0.7;
    gMenuContainer.layer.shadowRadius = 20;
    [self.view addSubview:gMenuContainer];

    [NSLayoutConstraint activateConstraints:@[
        [gMenuContainer.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [gMenuContainer.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [gMenuContainer.widthAnchor constraintEqualToConstant:340],
        [gMenuContainer.heightAnchor constraintEqualToConstant:420]
    ]];

    UIView *topBar = [UIView new];
    topBar.translatesAutoresizingMaskIntoConstraints = NO;
    topBar.backgroundColor = P_BG2;
    topBar.layer.cornerRadius = 18;
    topBar.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    [gMenuContainer addSubview:topBar];

    UILabel *title = [UILabel new];
    title.text = @"PURPOU CHEATS";
    title.textColor = P_TEXT;
    title.font = [UIFont boldSystemFontOfSize:15];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    [topBar addSubview:title];

    PurpouButton *minBtn = [PurpouButton buttonWithType:UIButtonTypeSystem];
    [minBtn setTitle:@"−" forState:UIControlStateNormal];
    [minBtn setTitleColor:P_TEXT forState:UIControlStateNormal];
    minBtn.titleLabel.font = [UIFont boldSystemFontOfSize:22];
    minBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [minBtn addTarget:self action:@selector(minimize) forControlEvents:UIControlEventTouchUpInside];
    [topBar addSubview:minBtn];

    [NSLayoutConstraint activateConstraints:@[
        [topBar.topAnchor constraintEqualToAnchor:gMenuContainer.topAnchor],
        [topBar.leadingAnchor constraintEqualToAnchor:gMenuContainer.leadingAnchor],
        [topBar.trailingAnchor constraintEqualToAnchor:gMenuContainer.trailingAnchor],
        [topBar.heightAnchor constraintEqualToConstant:48],

        [title.leadingAnchor constraintEqualToAnchor:topBar.leadingAnchor constant:16],
        [title.centerYAnchor constraintEqualToAnchor:topBar.centerYAnchor],

        [minBtn.trailingAnchor constraintEqualToAnchor:topBar.trailingAnchor constant:-12],
        [minBtn.centerYAnchor constraintEqualToAnchor:topBar.centerYAnchor],
        [minBtn.widthAnchor constraintEqualToConstant:34],
        [minBtn.heightAnchor constraintEqualToConstant:34]
    ]];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDrag:)];
    [topBar addGestureRecognizer:pan];

    tabButtonsBar = [UIView new];
    tabButtonsBar.translatesAutoresizingMaskIntoConstraints = NO;
    [gMenuContainer addSubview:tabButtonsBar];

    UIStackView *stack = [UIStackView new];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.distribution = UIStackViewDistributionFillEqually;
    stack.spacing = 6;
    [tabButtonsBar addSubview:stack];

    for (NSInteger i = 0; i < tabTitles.count; i++) {
        PurpouButton *b = [PurpouButton buttonWithType:UIButtonTypeSystem];
        [b setTitle:tabTitles[i] forState:UIControlStateNormal];
        [b setTitleColor:(i == 0) ? P_TEXT : P_SUBTEXT forState:UIControlStateNormal];
        b.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
        b.backgroundColor = (i == 0) ? P_ACCENT : P_BG2;
        b.layer.cornerRadius = 8;
        b.tag = i;
        [b addTarget:self action:@selector(tabTapped:) forControlEvents:UIControlEventTouchUpInside];
        [stack addArrangedSubview:b];
    }

    [NSLayoutConstraint activateConstraints:@[
        [tabButtonsBar.topAnchor constraintEqualToAnchor:topBar.bottomAnchor constant:12],
        [tabButtonsBar.leadingAnchor constraintEqualToAnchor:gMenuContainer.leadingAnchor constant:12],
        [tabButtonsBar.trailingAnchor constraintEqualToAnchor:gMenuContainer.trailingAnchor constant:-12],
        [tabButtonsBar.heightAnchor constraintEqualToConstant:36],

        [stack.topAnchor constraintEqualToAnchor:tabButtonsBar.topAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:tabButtonsBar.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:tabButtonsBar.trailingAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:tabButtonsBar.bottomAnchor]
    ]];

    contentArea = [UIView new];
    contentArea.translatesAutoresizingMaskIntoConstraints = NO;
    [gMenuContainer addSubview:contentArea];

    [NSLayoutConstraint activateConstraints:@[
        [contentArea.topAnchor constraintEqualToAnchor:tabButtonsBar.bottomAnchor constant:10],
        [contentArea.leadingAnchor constraintEqualToAnchor:gMenuContainer.leadingAnchor constant:16],
        [contentArea.trailingAnchor constraintEqualToAnchor:gMenuContainer.trailingAnchor constant:-16],
        [contentArea.bottomAnchor constraintEqualToAnchor:gMenuContainer.bottomAnchor constant:-16]
    ]];

    [self renderTab:0];
}

- (void)tabTapped:(PurpouButton*)sender {
    currentTab = sender.tag;
    for (PurpouButton *b in tabButtonsBar.subviews.firstObject.subviews) {
        if ([b isKindOfClass:[PurpouButton class]]) {
            b.backgroundColor = (b.tag == currentTab) ? P_ACCENT : P_BG2;
            [b setTitleColor:(b.tag == currentTab) ? P_TEXT : P_SUBTEXT forState:UIControlStateNormal];
        }
    }
    [self renderTab:currentTab];
}

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
        [col addArrangedSubview:[[PurpouToggle alloc] initWithTitle:@"Desbloquear Todos" on:gVehicleESP onChange:^(BOOL on){ [h toggleUnlockVehicles:on]; }]];
        [col addArrangedSubview:[[PurpouToggle alloc] initWithTitle:@"Velocidade Máxima" on:NO onChange:^(BOOL on){ [h toggleSpeed:on]; }]];
        [col addArrangedSubview:[[PurpouToggle alloc] initWithTitle:@"Aceleração Turbo" on:NO onChange:^(BOOL on){ [h toggleAcceleration:on]; }]];
        [col addArrangedSubview:[[PurpouToggle alloc] initWithTitle:@"Sem Dano" on:NO onChange:^(BOOL on){ [h toggleNoDamage:on]; }]];
    } else if (tab == 1) { // Money
        [col addArrangedSubview:[[PurpouToggle alloc] initWithTitle:@"Dinheiro x10" on:gMoneyInf onChange:^(BOOL on){ [h toggleMoney:on]; }]];
        [col addArrangedSubview:[[PurpouToggle alloc] initWithTitle:@"Auto Salvar" on:YES onChange:^(BOOL on){ }]];
        [col addArrangedSubview:[[PurpouToggle alloc] initWithTitle:@"Sem Taxa" on:NO onChange:^(BOOL on){ }]];
    } else { // Automático
        [col addArrangedSubview:[[PurpouToggle alloc] initWithTitle:@"Piloto Automático" on:gAutoDrive onChange:^(BOOL on){ [h toggleAutoDrive:on]; }]];
        [col addArrangedSubview:[[PurpouToggle alloc] initWithTitle:@"Auto CNH" on:NO onChange:^(BOOL on){ [h toggleAutoCNH:on]; }]];
        [col addArrangedSubview:[[PurpouToggle alloc] initWithTitle:@"Auto Coleta" on:NO onChange:^(BOOL on){ [h toggleAutoCollect:on]; }]];
    }
}

- (void)handleDrag:(UIPanGestureRecognizer*)p {
    CGPoint t = [p translationInView:self.view];
    gMenuContainer.center = CGPointMake(gMenuContainer.center.x + t.x, gMenuContainer.center.y + t.y);
    [p setTranslation:CGPointZero inView:self.view];
}

- (void)minimize {
    gMenuContainer.hidden = YES;
    gFloatingButton.hidden = NO;
    gFloatingButton.transform = CGAffineTransformMakeScale(0.1, 0.1);
    [UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:0.5 initialSpringVelocity:1.0 options:0 animations:^{
        gFloatingButton.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)restoreMenu {
    gFloatingButton.hidden = YES;
    gMenuContainer.hidden = NO;
    gMenuContainer.transform = CGAffineTransformMakeScale(0.1, 0.1);
    gMenuContainer.alpha = 0;
    [UIView animateWithDuration:0.5 delay:0 usingSpringWithDamping:0.4 initialSpringVelocity:1.5 options:UIViewAnimationOptionAllowUserInteraction animations:^{
        gMenuContainer.transform = CGAffineTransformIdentity;
        gMenuContainer.alpha = 1;
    } completion:nil];
}

- (void)handleBallPan:(UIPanGestureRecognizer*)p {
    CGPoint t = [p translationInView:self.view];
    gFloatingButton.center = CGPointMake(gFloatingButton.center.x + t.x, gFloatingButton.center.y + t.y);
    [p setTranslation:CGPointZero inView:self.view];
}

@end

// ============================================================
// PurpouMenu
// ============================================================
@implementation PurpouMenu

+ (instancetype)shared {
    static PurpouMenu *inst = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ inst = [PurpouMenu new]; });
    return inst;
}

- (void)show {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindowScene *scene = nil;
        for (UIScene *s in [UIApplication sharedApplication].connectedScenes)
            if ([s isKindOfClass:[UIWindowScene class]]) { scene = (UIWindowScene*)s; break; }

        PurpouWindow *win = scene ? [[PurpouWindow alloc] initWithWindowScene:scene]
                                  : [[PurpouWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        win.frame = [UIScreen mainScreen].bounds;
        win.windowLevel = UIWindowLevelAlert + 1000;
        win.backgroundColor = [UIColor clearColor];
        gOverlayWindow = win;

        PurpouMenuVC *vc = [PurpouMenuVC new];
        win.rootViewController = vc;
        win.hidden = NO;
        [win makeKeyAndVisible];

        PurpouButton *ball = [PurpouButton buttonWithType:UIButtonTypeSystem];
        ball.frame = CGRectMake(20, 100, 54, 54);
        ball.backgroundColor = P_ACCENT;
        ball.layer.cornerRadius = 27;
        ball.layer.shadowColor = [UIColor blackColor].CGColor;
        ball.layer.shadowOpacity = 0.6;
        ball.layer.shadowRadius = 10;
        [ball setTitle:@"P" forState:UIControlStateNormal];
        [ball setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        ball.titleLabel.font = [UIFont boldSystemFontOfSize:22];
        ball.hidden = YES;
        [ball addTarget:vc action:@selector(restoreMenu) forControlEvents:UIControlEventTouchUpInside];

        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:vc action:@selector(handleBallPan:)];
        [ball addGestureRecognizer:pan];
        [vc.view addSubview:ball];
        gFloatingButton = ball;

        win.interactive1 = gMenuContainer;
        win.interactive2 = gFloatingButton;
    });
}

- (void)hide {
    dispatch_async(dispatch_get_main_queue(), ^{
        gOverlayWindow.hidden = YES;
        gOverlayWindow = nil;
        gMenuContainer = nil;
        gFloatingButton = nil;
    });
}

@end
