#import "Menu.h"
#import "Hooks.h"
#import <objc/runtime.h>
#import <UIKit/UIKit.h>

@class PurpouWindow;
static PurpouWindow *gOverlayWindow = nil;
static UIView *gMenuContainer = nil;
static UIView *gMiniBar = nil;
static UIView *gFovCircle = nil;
static BOOL gIsMinimized = YES;

// ============================================================
// Cores do Menu
// ============================================================
#define C_BG        [UIColor colorWithRed:0.08 green:0.08 blue:0.10 alpha:0.95]
#define C_SIDEBAR   [UIColor colorWithRed:0.05 green:0.05 blue:0.05 alpha:0.95]
#define C_ACCENT    [UIColor colorWithRed:0.8 green:0.3 blue:0.4 alpha:1.0]
#define C_TEXT      [UIColor whiteColor]
#define C_SUBTEXT   [UIColor lightGrayColor]

// ============================================================
// Checkbox Customizado
// ============================================================
@interface PurpouToggle : UIView
@property (nonatomic, assign) BOOL on;
@property (nonatomic, copy) void (^onChange)(BOOL);
@property (nonatomic, strong) UIView *box;
@property (nonatomic, strong) UILabel *label;
@end

@implementation PurpouToggle
- (instancetype)initWithTitle:(NSString*)title on:(BOOL)on onChange:(void(^)(BOOL))cb {
    if (self = [super init]) {
        self.on = on; self.onChange = cb;
        self.translatesAutoresizingMaskIntoConstraints = NO;
        
        self.box = [UIView new];
        self.box.translatesAutoresizingMaskIntoConstraints = NO;
        self.box.backgroundColor = on ? C_ACCENT : [UIColor clearColor];
        self.box.layer.borderColor = [UIColor grayColor].CGColor;
        self.box.layer.borderWidth = 1; self.box.layer.cornerRadius = 4;
        [self addSubview:self.box];
        
        self.label = [UILabel new];
        self.label.text = title; self.label.textColor = C_TEXT;
        self.label.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        self.label.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:self.label];
        
        [NSLayoutConstraint activateConstraints:@[
            [self.box.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [self.box.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [self.box.widthAnchor constraintEqualToConstant:22], [self.box.heightAnchor constraintEqualToConstant:22],
            [self.label.leadingAnchor constraintEqualToAnchor:self.box.trailingAnchor constant:12],
            [self.label.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [self.heightAnchor constraintEqualToConstant:36]
        ]];
        
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggle)];
        [self addGestureRecognizer:tap];
    }
    return self;
}

- (void)toggle {
    self.on = !self.on;
    self.box.backgroundColor = self.on ? C_ACCENT : [UIColor clearColor];
    if (self.onChange) self.onChange(self.on);
}
@end

// ============================================================
// Slider Customizado (FOV)
// ============================================================
@interface PurpouSlider : UIView
@property (nonatomic, assign) float value;
@property (nonatomic, copy) void (^onChange)(float);
@property (nonatomic, strong) UISlider *slider;
@property (nonatomic, strong) UILabel *label;
@end

@implementation PurpouSlider
- (instancetype)initWithTitle:(NSString*)title min:(float)min max:(float)max value:(float)val onChange:(void(^)(float))cb {
    if (self = [super init]) {
        self.value = val; self.onChange = cb;
        self.translatesAutoresizingMaskIntoConstraints = NO;
        
        self.label = [UILabel new];
        self.label.text = [NSString stringWithFormat:@"%@: %.0f", title, val];
        self.label.textColor = C_TEXT;
        self.label.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        self.label.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:self.label];

        self.slider = [UISlider new];
        self.slider.minimumValue = min; self.slider.maximumValue = max; self.slider.value = val;
        self.slider.translatesAutoresizingMaskIntoConstraints = NO;
        [self.slider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
        [self addSubview:self.slider];

        [NSLayoutConstraint activateConstraints:@[
            [self.label.topAnchor constraintEqualToAnchor:self.topAnchor],
            [self.label.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [self.slider.topAnchor constraintEqualToAnchor:self.label.bottomAnchor constant:8],
            [self.slider.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [self.slider.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [self.heightAnchor constraintEqualToConstant:50]
        ]];
    }
    return self;
}
- (void)sliderChanged:(UISlider*)s {
    self.value = s.value;
    self.label.text = [NSString stringWithFormat:@"%@: %.0f", self.label.text, s.value];
    if (self.onChange) self.onChange(s.value);
}
@end

// ============================================================
// PurpouWindow
// ============================================================
@interface PurpouWindow : UIWindow
@property (nonatomic, weak) UIView *interactive1;
@end
@implementation PurpouWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *v = [super hitTest:point withEvent:event];
    if (!v) return nil;
    if (self.interactive1 && !self.interactive1.hidden) {
        CGPoint p = [self.interactive1 convertPoint:point fromView:self];
        if ([self.interactive1 pointInside:p withEvent:event]) return v;
    }
    return nil;
}
@end

// ============================================================
// Menu Principal
// ============================================================
@interface PurpouMenuVC : UIViewController
@end

@implementation PurpouMenuVC {
    UIView *contentArea;
    NSArray *tabNames;
    NSInteger currentTab;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    tabNames = @[@"Visuals", @"Assistance", @"Player", @"Teleport", @"Misc", @"Customize"];
    [self buildLayout];
}

- (void)buildLayout {
    // 1. Menu Grande (Diminuído)
    gMenuContainer = [UIView new];
    gMenuContainer.translatesAutoresizingMaskIntoConstraints = NO;
    gMenuContainer.backgroundColor = C_BG;
    gMenuContainer.layer.cornerRadius = 12;
    gMenuContainer.hidden = YES;
    [self.view addSubview:gMenuContainer];
    
    UIPanGestureRecognizer *panMenu = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDragMenu:)];
    [gMenuContainer addGestureRecognizer:panMenu];

    [NSLayoutConstraint activateConstraints:@[
        [gMenuContainer.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [gMenuContainer.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [gMenuContainer.widthAnchor constraintEqualToConstant:420], 
        [gMenuContainer.heightAnchor constraintEqualToConstant:280]
    ]];

    UIView *sidebar = [UIView new];
    sidebar.translatesAutoresizingMaskIntoConstraints = NO; 
    sidebar.backgroundColor = C_SIDEBAR;
    sidebar.layer.cornerRadius = 12; 
    sidebar.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    [gMenuContainer addSubview:sidebar];
    
    [NSLayoutConstraint activateConstraints:@[
        [sidebar.topAnchor constraintEqualToAnchor:gMenuContainer.topAnchor],
        [sidebar.leadingAnchor constraintEqualToAnchor:gMenuContainer.leadingAnchor],
        [sidebar.bottomAnchor constraintEqualToAnchor:gMenuContainer.bottomAnchor],
        [sidebar.widthAnchor constraintEqualToConstant:130] // Sidebar menor
    ]];
    
    UILabel *title = [UILabel new];
    title.text = @"PURPOU DEV"; title.textColor = C_TEXT;
    title.font = [UIFont boldSystemFontOfSize:14]; 
    title.translatesAutoresizingMaskIntoConstraints = NO;
    [sidebar addSubview:title];
    
    // BOTÃO X (Minimizar)
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [closeBtn setTitle:@"X" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    closeBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [closeBtn addTarget:self action:@selector(minimizeMenu) forControlEvents:UIControlEventTouchUpInside];
    [sidebar addSubview:closeBtn];

    [NSLayoutConstraint activateConstraints:@[
        [title.topAnchor constraintEqualToAnchor:sidebar.topAnchor constant:15],
        [title.leadingAnchor constraintEqualToAnchor:sidebar.leadingAnchor constant:10],
        [closeBtn.trailingAnchor constraintEqualToAnchor:sidebar.trailingAnchor constant:-10],
        [closeBtn.centerYAnchor constraintEqualToAnchor:title.centerYAnchor],
        [closeBtn.widthAnchor constraintEqualToConstant:30], 
        [closeBtn.heightAnchor constraintEqualToConstant:30]
    ]];

    UIStackView *stack = [UIStackView new]; 
    stack.axis = UILayoutConstraintAxisVertical; 
    stack.spacing = 10; 
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [sidebar addSubview:stack];
    
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:20],
        [stack.leadingAnchor constraintEqualToAnchor:sidebar.leadingAnchor constant:5],
        [stack.trailingAnchor constraintEqualToAnchor:sidebar.trailingAnchor constant:-5]
    ]];
    
    for (int i=0; i<tabNames.count; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        [btn setTitle:tabNames[i] forState:UIControlStateNormal];
        [btn setTitleColor:(i==0)?C_ACCENT:C_SUBTEXT forState:UIControlStateNormal];
        [btn setContentHorizontalAlignment:UIControlContentHorizontalAlignmentLeft];
        btn.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
        btn.tag = i; 
        [btn addTarget:self action:@selector(tabTapped:) forControlEvents:UIControlEventTouchUpInside];
        [stack addArrangedSubview:btn];
    }

    contentArea = [UIView new]; 
    contentArea.translatesAutoresizingMaskIntoConstraints = NO;
    [gMenuContainer addSubview:contentArea];
    
    [NSLayoutConstraint activateConstraints:@[
        [contentArea.topAnchor constraintEqualToAnchor:gMenuContainer.topAnchor],
        [contentArea.leadingAnchor constraintEqualToAnchor:sidebar.trailingAnchor],
        [contentArea.trailingAnchor constraintEqualToAnchor:gMenuContainer.trailingAnchor],
        [contentArea.bottomAnchor constraintEqualToAnchor:gMenuContainer.bottomAnchor]
    ]];

    // 2. Barrinha (PURPOU DEV)
    [self buildMiniBar];
    [self renderTab:0];
}

- (void)buildMiniBar {
    gMiniBar = [UIView new];
    gMiniBar.translatesAutoresizingMaskIntoConstraints = NO;
    gMiniBar.backgroundColor = C_BG;
    gMiniBar.layer.cornerRadius = 20;
    gMiniBar.layer.borderColor = C_ACCENT.CGColor;
    gMiniBar.layer.borderWidth = 1;
    gMiniBar.hidden = NO; // Começa visível
    [self.view addSubview:gMiniBar];
    
    UIPanGestureRecognizer *panBar = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDragMiniBar:)];
    [gMiniBar addGestureRecognizer:panBar];

    [NSLayoutConstraint activateConstraints:@[
        [gMiniBar.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [gMiniBar.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [gMiniBar.widthAnchor constraintEqualToConstant:150], 
        [gMiniBar.heightAnchor constraintEqualToConstant:44]
    ]];

    UILabel *miniTitle = [UILabel new];
    miniTitle.text = @"PURPOU DEV"; miniTitle.textColor = C_TEXT;
    miniTitle.font = [UIFont boldSystemFontOfSize:12];
    miniTitle.translatesAutoresizingMaskIntoConstraints = NO;
    [gMiniBar addSubview:miniTitle];

    UIButton *expandBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [expandBtn setTitle:@"+" forState:UIControlStateNormal];
    [expandBtn setTitleColor:C_ACCENT forState:UIControlStateNormal];
    expandBtn.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    expandBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [expandBtn addTarget:self action:@selector(expandMenu) forControlEvents:UIControlEventTouchUpInside];
    [gMiniBar addSubview:expandBtn];

    [NSLayoutConstraint activateConstraints:@[
        [miniTitle.leadingAnchor constraintEqualToAnchor:gMiniBar.leadingAnchor constant:15],
        [miniTitle.centerYAnchor constraintEqualToAnchor:gMiniBar.centerYAnchor],
        [expandBtn.trailingAnchor constraintEqualToAnchor:gMiniBar.trailingAnchor constant:-10],
        [expandBtn.centerYAnchor constraintEqualToAnchor:gMiniBar.centerYAnchor],
        [expandBtn.widthAnchor constraintEqualToConstant:30], 
        [expandBtn.heightAnchor constraintEqualToConstant:30]
    ]];
}

// FOV Circle (Apenas visual)
- (void)showFovCircle:(BOOL)show {
    if (show && !gFovCircle) {
        gFovCircle = [UIView new];
        gFovCircle.translatesAutoresizingMaskIntoConstraints = NO;
        gFovCircle.backgroundColor = [UIColor clearColor];
        gFovCircle.layer.borderColor = [UIColor whiteColor].CGColor;
        gFovCircle.layer.borderWidth = 1;
        gFovCircle.layer.cornerRadius = 75;
        [self.view addSubview:gFovCircle];
        [NSLayoutConstraint activateConstraints:@[
            [gFovCircle.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
            [gFovCircle.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
            [gFovCircle.widthAnchor constraintEqualToConstant:150],
            [gFovCircle.heightAnchor constraintEqualToConstant:150]
        ]];
    } else if (!show && gFovCircle) {
        [gFovCircle removeFromSuperview];
        gFovCircle = nil;
    }
}

// ============================================================
// Lógica de Minimizar / Expandir
// ============================================================
- (void)minimizeMenu {
    gIsMinimized = YES;
    [UIView animateWithDuration:0.3 animations:^{
        gMenuContainer.alpha = 0;
        gMenuContainer.transform = CGAffineTransformMakeScale(0.8, 0.8);
    } completion:^(BOOL finished) {
        gMenuContainer.hidden = YES;
        gMiniBar.hidden = NO;
        gMiniBar.alpha = 0;
        gMiniBar.transform = CGAffineTransformMakeScale(0.8, 0.8);
        [UIView animateWithDuration:0.3 animations:^{
            gMiniBar.alpha = 1;
            gMiniBar.transform = CGAffineTransformIdentity;
        }];
    }];
}

- (void)expandMenu {
    gIsMinimized = NO;
    [UIView animateWithDuration:0.3 animations:^{
        gMiniBar.alpha = 0;
        gMiniBar.transform = CGAffineTransformMakeScale(0.8, 0.8);
    } completion:^(BOOL finished) {
        gMiniBar.hidden = YES;
        gMenuContainer.hidden = NO;
        gMenuContainer.alpha = 0;
        gMenuContainer.transform = CGAffineTransformMakeScale(0.8, 0.8);
        [UIView animateWithDuration:0.3 animations:^{
            gMenuContainer.alpha = 1;
            gMenuContainer.transform = CGAffineTransformIdentity;
        }];
    }];
}

// Arrastar
- (void)handleDragMenu:(UIPanGestureRecognizer*)p {
    if (gIsMinimized) return;
    CGPoint t = [p translationInView:self.view];
    gMenuContainer.center = CGPointMake(gMenuContainer.center.x + t.x, gMenuContainer.center.y + t.y);
    [p setTranslation:CGPointZero inView:self.view];
}

- (void)handleDragMiniBar:(UIPanGestureRecognizer*)p {
    if (!gIsMinimized) return;
    CGPoint t = [p translationInView:self.view];
    gMiniBar.center = CGPointMake(gMiniBar.center.x + t.x, gMiniBar.center.y + t.y);
    [p setTranslation:CGPointZero inView:self.view];
}

// Abas
- (void)tabTapped:(UIButton*)sender {
    currentTab = sender.tag;
    for (UIButton *b in sender.superview.subviews) {
        if ([b isKindOfClass:[UIButton class]]) [b setTitleColor:(b.tag == currentTab) ? C_ACCENT : C_SUBTEXT forState:UIControlStateNormal];
    }
    [self renderTab:currentTab];
}

- (void)renderTab:(NSInteger)tab {
    for (UIView *v in contentArea.subviews) [v removeFromSuperview];
    UIStackView *col = [UIStackView new]; col.axis = UILayoutConstraintAxisVertical; col.spacing = 8; col.translatesAutoresizingMaskIntoConstraints = NO;
    [contentArea addSubview:col];
    
    [NSLayoutConstraint activateConstraints:@[
        [col.centerXAnchor constraintEqualToAnchor:contentArea.centerXAnchor],
        [col.centerYAnchor constraintEqualToAnchor:contentArea.centerYAnchor],
        [col.widthAnchor constraintEqualToConstant:250]
    ]];
    
    PurpouHooks *h = [PurpouHooks shared];
    if (tab == 0) { // Visuals
        [col addArrangedSubview:[[PurpouToggle alloc] initWithTitle:@"ESP Box" on:NO onChange:^(BOOL on){ [h setESPEnabled:on]; }]];
        [col addArrangedSubview:[[PurpouToggle alloc] initWithTitle:@"ESP Tracer" on:NO onChange:^(BOOL on){}]];
        [col addArrangedSubview:[[PurpouToggle alloc] initWithTitle:@"ESP Name" on:NO onChange:^(BOOL on){}]];
    } else if (tab == 1) { // Assistance
        [col addArrangedSubview:[[PurpouToggle alloc] initWithTitle:@"Aimbot" on:NO onChange:^(BOOL on){ 
            [h setAimbotEnabled:on]; 
            [self showFovCircle:on];
        }]];
        [col addArrangedSubview:[[PurpouSlider alloc] initWithTitle:@"FOV Slider" min:50 max:300 value:150 onChange:^(float v){
            // Atualiza o raio do FOV visual
            gFovCircle.layer.cornerRadius = v / 2;
            [gFovCircle.constraints enumerateObjectsUsingBlock:^(NSLayoutConstraint *c, NSUInteger idx, BOOL *stop) {
                if (c.firstAttribute == NSLayoutAttributeWidth || c.firstAttribute == NSLayoutAttributeHeight) c.constant = v;
            }];
            [self.view layoutIfNeeded];
        }]];
    } else if (tab == 4) { // Misc
        [col addArrangedSubview:[[PurpouToggle alloc] initWithTitle:@"Speed Hack" on:NO onChange:^(BOOL on){}]];
        [col addArrangedSubview:[[PurpouToggle alloc] initWithTitle:@"No Clip" on:NO onChange:^(BOOL on){}]];
    }
}
@end

// ============================================================
// PurpouMenu
// ============================================================
@implementation PurpouMenu
+ (instancetype)shared {
    static PurpouMenu *inst = nil; static dispatch_once_t once;
    dispatch_once(&once, ^{ inst = [PurpouMenu new]; });
    return inst;
}

- (void)show {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (gOverlayWindow) return;
        UIWindowScene *scene = nil;
        for (UIScene *s in [UIApplication sharedApplication].connectedScenes)
            if ([s isKindOfClass:[UIWindowScene class]]) { scene = (UIWindowScene*)s; break; }
        
        PurpouWindow *win = scene ? [[PurpouWindow alloc] initWithWindowScene:scene] : [[PurpouWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        win.frame = [UIScreen mainScreen].bounds;
        win.windowLevel = UIWindowLevelAlert + 1000;
        win.backgroundColor = [UIColor clearColor];
        
        // Força orientação vertical
        win.rootViewController = [PurpouMenuVC new];
        if (@available(iOS 16.0, *)) {
            [win.rootViewController setNeedsUpdateOfSupportedInterfaceOrientations];
        }
        
        gOverlayWindow = win;
        win.hidden = NO;
        [win makeKeyAndVisible];
        
        win.interactive1 = win.rootViewController.view;
    });
}

- (void)showMinimized {
    [self show];
}

- (void)hide {
    dispatch_async(dispatch_get_main_queue(), ^{
        gOverlayWindow.hidden = YES;
        gOverlayWindow = nil;
        gMenuContainer = nil;
        gMiniBar = nil;
        gFovCircle = nil;
    });
}
@end
