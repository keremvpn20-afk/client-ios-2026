#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>
#include "hooks.hpp"
#include "memory.hpp"

namespace Hooks {
    extern bool killauraEnabled;
    extern bool aimassistEnabled;
    extern bool triggerbotEnabled;
    extern bool flyEnabled;
    extern bool espEnabled;
    extern bool tracerEnabled;
    extern bool storageEspEnabled;
    extern bool storageChestEnabled;
    extern bool storageEnderChestEnabled;
    extern bool storageHopperEnabled;
    extern bool storageSpawnerEnabled;
    extern bool storagePistonEnabled;
    extern bool storageBarrelEnabled;
    extern float flySpeed;
    extern bool speedEnabled;
    extern float speedValue;
    extern bool reachEnabled;
    extern float reachDistance;
    extern bool velocityEnabled;
    extern float velocityValue;

    extern float espColor[3];
    extern float tracerColor[3];
    extern float storageChestColor[3];
    extern float storageEnderChestColor[3];
    extern float storageHopperColor[3];
    extern float storageSpawnerColor[3];
    extern float storagePistonColor[3];
    extern float storageBarrelColor[3];

    extern std::vector<ESPObject> espObjects;
}

// Helper to swizzle methods dynamically
static void SwizzleMethod(Class c, SEL origSEL, SEL newSEL) {
    Method origMethod = class_getInstanceMethod(c, origSEL);
    Method newMethod = class_getInstanceMethod(c, newSEL);
    if (origMethod && newMethod) {
        if (class_addMethod(c, origSEL, method_getImplementation(newMethod), method_getTypeEncoding(newMethod))) {
            class_replaceMethod(c, newSEL, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
        } else {
            method_exchangeImplementations(origMethod, newMethod);
        }
    }
}

// WKWebView Category to intercept MSAL/Xbox login requests and push to Safari
@interface WKWebView (XboxBypass)
@end

@implementation WKWebView (XboxBypass)

- (void)hook_loadRequest:(NSURLRequest *)request {
    NSURL *url = request.URL;
    NSString *urlStr = url.absoluteString;
    
    if ([urlStr containsString:@"login.live.com"] || [urlStr containsString:@"login.microsoftonline.com"]) {
        NSLog(@"[yt] Redirecting Xbox login request to external Safari: %@", urlStr);
        dispatch_async(dispatch_get_main_queue(), ^{
            [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
        });
        return; // Prevent loading in game's limited/broken Web view
    }
    
    [self hook_loadRequest:request];
}

@end

// Helper class to hold our App Delegate hook implementation
@interface AppDelegateHook : NSObject
- (BOOL)hook_application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<NSString *, id> *)options;
@end

@implementation AppDelegateHook

- (BOOL)hook_application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<NSString *, id> *)options {
    NSString *urlStr = url.absoluteString;
    NSLog(@"[yt] Captured authentication redirect URL: %@", urlStr);
    
    // Save authentication parameters to shared memory/NSUserDefaults for the game engine to read
    if ([urlStr containsString:@"code="] || [urlStr containsString:@"access_token="]) {
        [[NSUserDefaults standardUserDefaults] setObject:urlStr forKey:@"XboxAuthTokenCallback"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        // Post global notification so the Minecraft authentication handlers update
        [[NSNotificationCenter defaultCenter] postNotificationName:@"XboxAuthTokenReceived" object:nil userInfo:@{@"url": urlStr}];
    }
    
    if ([self respondsToSelector:@selector(hook_application:openURL:options:)]) {
        return [self hook_application:app openURL:url options:options];
    }
    return YES;
}

@end

// Inject hooks dynamically at runtime
static void SetupXboxBypass() {
    // 1. Swizzle WKWebView
    SwizzleMethod([WKWebView class], @selector(loadRequest:), @selector(hook_loadRequest:));
    
    // 2. Swizzle App Delegate openURL to capture Safari redirects
    id delegate = [UIApplication sharedApplication].delegate;
    if (delegate) {
        Class delegateClass = [delegate class];
        SEL openURLSel = @selector(application:openURL:options:);
        
        Method hookMethod = class_getInstanceMethod([AppDelegateHook class], @selector(hook_application:openURL:options:));
        if (hookMethod) {
            class_addMethod(delegateClass, @selector(hook_application:openURL:options:), method_getImplementation(hookMethod), method_getTypeEncoding(hookMethod));
            SwizzleMethod(delegateClass, openURLSel, @selector(hook_application:openURL:options:));
            NSLog(@"[yt] Xbox Login bypass hooked onto App Delegate");
        }
    }
}

@interface ESPView : UIView
@property (nonatomic, strong) CADisplayLink *displayLink;
@end

@implementation ESPView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
        
        _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(redraw)];
        [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    }
    return self;
}

- (void)redraw {
    if (Hooks::espEnabled || Hooks::tracerEnabled || 
        (Hooks::storageEspEnabled && (Hooks::storageChestEnabled || Hooks::storageEnderChestEnabled ||
        Hooks::storageHopperEnabled || Hooks::storageSpawnerEnabled || 
        Hooks::storagePistonEnabled || Hooks::storageBarrelEnabled))) {
        [self setNeedsDisplay];
    } else {
        self.layer.sublayers = nil;
    }
}

static UIColor* ColorFromFloat(float color[3]) {
    return [UIColor colorWithRed:color[0] green:color[1] blue:color[2] alpha:1.0];
}

static void DrawStorageBox(CGContextRef context, CGRect box, UIColor *color, NSString *name) {
    CGContextSetStrokeColorWithColor(context, color.CGColor);
    CGContextSetLineWidth(context, 1.5);
    CGContextStrokeRect(context, box);
    
    NSDictionary *attributes = @{
        NSFontAttributeName: [UIFont systemFontOfSize:10.0 weight:UIFontWeightBold],
        NSForegroundColorAttributeName: color
    };
    [name drawAtPoint:CGPointMake(box.origin.x, box.origin.y - 14) withAttributes:attributes];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (!context) return;
    
    for (const auto& obj : Hooks::espObjects) {
        UIColor *color = nil;
        NSString *name = nil;
        bool isEnabled = false;
        CGRect boxRect = CGRectZero;

        switch (obj.type) {
            case 0: // Player ESP
                isEnabled = Hooks::espEnabled;
                color = ColorFromFloat(Hooks::espColor);
                name = [NSString stringWithFormat:@"Player [%.0fm]", obj.distance];
                boxRect = CGRectMake(obj.screenPos.x - 25, obj.screenPos.y - 50, 50, 100);
                break;
            case 1: // Chest
                isEnabled = Hooks::storageEspEnabled && Hooks::storageChestEnabled;
                color = ColorFromFloat(Hooks::storageChestColor);
                name = [NSString stringWithFormat:@"Chest [%.0fm]", obj.distance];
                boxRect = CGRectMake(obj.screenPos.x - 15, obj.screenPos.y - 15, 30, 30);
                break;
            case 2: // Ender Chest
                isEnabled = Hooks::storageEspEnabled && Hooks::storageEnderChestEnabled;
                color = ColorFromFloat(Hooks::storageEnderChestColor);
                name = [NSString stringWithFormat:@"Ender Chest [%.0fm]", obj.distance];
                boxRect = CGRectMake(obj.screenPos.x - 15, obj.screenPos.y - 15, 30, 30);
                break;
            case 3: // Hopper
                isEnabled = Hooks::storageEspEnabled && Hooks::storageHopperEnabled;
                color = ColorFromFloat(Hooks::storageHopperColor);
                name = [NSString stringWithFormat:@"Hopper [%.0fm]", obj.distance];
                boxRect = CGRectMake(obj.screenPos.x - 15, obj.screenPos.y - 15, 30, 30);
                break;
            case 4: // Spawner
                isEnabled = Hooks::storageEspEnabled && Hooks::storageSpawnerEnabled;
                color = ColorFromFloat(Hooks::storageSpawnerColor);
                name = [NSString stringWithFormat:@"Spawner [%.0fm]", obj.distance];
                boxRect = CGRectMake(obj.screenPos.x - 20, obj.screenPos.y - 20, 40, 40);
                break;
            case 5: // Piston
                isEnabled = Hooks::storageEspEnabled && Hooks::storagePistonEnabled;
                color = ColorFromFloat(Hooks::storagePistonColor);
                name = [NSString stringWithFormat:@"Piston [%.0fm]", obj.distance];
                boxRect = CGRectMake(obj.screenPos.x - 15, obj.screenPos.y - 15, 30, 30);
                break;
            case 6: // Barrel
                isEnabled = Hooks::storageEspEnabled && Hooks::storageBarrelEnabled;
                color = ColorFromFloat(Hooks::storageBarrelColor);
                name = [NSString stringWithFormat:@"Barrel [%.0fm]", obj.distance];
                boxRect = CGRectMake(obj.screenPos.x - 15, obj.screenPos.y - 15, 30, 30);
                break;
        }

        if (isEnabled && color && !CGRectIsEmpty(boxRect)) {
            DrawStorageBox(context, boxRect, color, name);

            if (Hooks::tracerEnabled) {
                CGContextSetStrokeColorWithColor(context, color.CGColor);
                CGContextSetLineWidth(context, 1.0);
                CGContextBeginPath(context);
                CGContextMoveToPoint(context, rect.size.width / 2.0, rect.size.height / 2.0);
                CGContextAddLineToPoint(context, obj.screenPos.x, obj.screenPos.y);
                CGContextStrokePath(context);
            }
        }
    }
}

@end

// FloatMenu: A floating premium UIKit panel for managing cheat settings on iOS
@interface FloatMenu : UIView {
    CGPoint lastPoint;
}
@property (nonatomic, strong) UIButton *toggleButton;
@property (nonatomic, strong) UIVisualEffectView *panelView;
@property (nonatomic, strong) UIScrollView *scrollView;

@property (nonatomic, strong) UISwitch *flySwitch;
@property (nonatomic, strong) UISwitch *killauraSwitch;
@property (nonatomic, strong) UISwitch *aimassistSwitch;
@property (nonatomic, strong) UISwitch *triggerbotSwitch;
@property (nonatomic, strong) UISwitch *espSwitch;
@property (nonatomic, strong) UISwitch *tracerSwitch;

@property (nonatomic, strong) UISwitch *storageEspSwitch;
@property (nonatomic, strong) UISwitch *chestSwitch;
@property (nonatomic, strong) UISwitch *enderChestSwitch;
@property (nonatomic, strong) UISwitch *hopperSwitch;
@property (nonatomic, strong) UISwitch *spawnerSwitch;
@property (nonatomic, strong) UISwitch *pistonSwitch;
@property (nonatomic, strong) UISwitch *barrelSwitch;

@property (nonatomic, strong) UISlider *speedSlider;
@property (nonatomic, strong) UILabel *speedLabel;

@property (nonatomic, strong) UISwitch *speedSwitch;
@property (nonatomic, strong) UISlider *speedValSlider;
@property (nonatomic, strong) UILabel *speedValLabel;

@property (nonatomic, strong) UISwitch *reachSwitch;
@property (nonatomic, strong) UISlider *reachDistSlider;
@property (nonatomic, strong) UILabel *reachDistLabel;

@property (nonatomic, strong) UISwitch *velocitySwitch;
@property (nonatomic, strong) UISlider *velocityValSlider;
@property (nonatomic, strong) UILabel *velocityValLabel;
@end

@implementation FloatMenu

- (UISegmentedControl *)createColorPickerWithY:(CGFloat)y tag:(NSInteger)tag defaultIdx:(NSInteger)idx {
    NSArray *items = @[@"🔴", @"🟢", @"🔵", @"🟡", @"🟣", @"🟠", @"⚪️"];
    UISegmentedControl *seg = [[UISegmentedControl alloc] initWithItems:items];
    seg.frame = CGRectMake(15, y, 220, 26);
    seg.selectedSegmentIndex = idx;
    seg.tag = tag;
    
    seg.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.06];
    seg.selectedSegmentTintColor = [UIColor colorWithRed:0.45 green:0.25 blue:0.90 alpha:0.60];
    
    NSDictionary *attr = @{NSForegroundColorAttributeName: [UIColor whiteColor]};
    [seg setTitleTextAttributes:attr forState:UIControlStateNormal];
    [seg setTitleTextAttributes:attr forState:UIControlStateSelected];
    
    [seg addTarget:self action:@selector(colorChanged:) forControlEvents:UIControlEventValueChanged];
    return seg;
}

- (UIView *)createCardWithFrame:(CGRect)frame title:(NSString *)title {
    UIView *card = [[UIView alloc] initWithFrame:frame];
    card.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.04];
    card.layer.cornerRadius = 14.0;
    card.layer.borderWidth = 1.0;
    card.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.08].CGColor;
    
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(15, 12, frame.size.width - 30, 16)];
    lbl.text = title.uppercaseString;
    lbl.textColor = [UIColor colorWithRed:0.75 green:0.55 blue:1.00 alpha:1.0];
    lbl.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightBold];
    [card addSubview:lbl];
    
    return card;
}

- (UISwitch *)createSwitchAtX:(CGFloat)x y:(CGFloat)y action:(SEL)action targetCard:(UIView *)card {
    UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(x, y, 50, 30)];
    sw.onTintColor = [UIColor colorWithRed:0.45 green:0.25 blue:0.90 alpha:1.0];
    sw.thumbTintColor = [UIColor whiteColor];
    [sw addTarget:self action:action forControlEvents:UIControlEventValueChanged];
    [card addSubview:sw];
    return sw;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        
        UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        _panelView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
        _panelView.frame = CGRectMake(50, 140, 280, 420);
        _panelView.layer.cornerRadius = 20.0;
        _panelView.layer.masksToBounds = YES;
        _panelView.layer.borderWidth = 1.0;
        _panelView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.12].CGColor;
        _panelView.hidden = YES;
        [self addSubview:_panelView];
        
        UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [_panelView addGestureRecognizer:panGesture];
        
        UIView *contentView = _panelView.contentView;
        
        UIView *dragHandle = [[UIView alloc] initWithFrame:CGRectMake(110, 8, 60, 4)];
        dragHandle.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.3];
        dragHandle.layer.cornerRadius = 2.0;
        [contentView addSubview:dragHandle];
        
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 18, 260, 25)];
        titleLabel.text = @"YPAVLOV CLIENT";
        titleLabel.textColor = [UIColor whiteColor];
        titleLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightHeavy];
        titleLabel.textAlignment = NSTextAlignmentCenter;
        [contentView addSubview:titleLabel];

        _scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 50, 280, 370)];
        _scrollView.showsVerticalScrollIndicator = NO;
        _scrollView.contentSize = CGSizeMake(280, 900); // Dynamic content size
        [contentView addSubview:_scrollView];
        
        CGFloat cardY = 10;
        
        // 1. COMBAT CARD
        UIView *combatCard = [self createCardWithFrame:CGRectMake(15, cardY, 250, 260) title:@"Combat Modules"];
        [_scrollView addSubview:combatCard];
        
        UILabel *lblKillaura = [[UILabel alloc] initWithFrame:CGRectMake(15, 45, 120, 30)];
        lblKillaura.text = @"Killaura";
        lblKillaura.textColor = [UIColor colorWithWhite:0.9 alpha:1.0];
        lblKillaura.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
        [combatCard addSubview:lblKillaura];
        _killauraSwitch = [self createSwitchAtX:185 y:45 action:@selector(killauraToggled:) targetCard:combatCard];
        
        UILabel *lblAim = [[UILabel alloc] initWithFrame:CGRectMake(15, 90, 120, 30)];
        lblAim.text = @"Aim Assist";
        lblAim.textColor = [UIColor colorWithWhite:0.9 alpha:1.0];
        lblAim.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
        [combatCard addSubview:lblAim];
        _aimassistSwitch = [self createSwitchAtX:185 y:90 action:@selector(aimassistToggled:) targetCard:combatCard];

        UILabel *lblTrigger = [[UILabel alloc] initWithFrame:CGRectMake(15, 135, 120, 30)];
        lblTrigger.text = @"Triggerbot";
        lblTrigger.textColor = [UIColor colorWithWhite:0.9 alpha:1.0];
        lblTrigger.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
        [combatCard addSubview:lblTrigger];
        _triggerbotSwitch = [self createSwitchAtX:185 y:135 action:@selector(triggerbotToggled:) targetCard:combatCard];

        UILabel *lblReach = [[UILabel alloc] initWithFrame:CGRectMake(15, 180, 120, 30)];
        lblReach.text = @"Reach Hack";
        lblReach.textColor = [UIColor colorWithWhite:0.9 alpha:1.0];
        lblReach.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
        [combatCard addSubview:lblReach];
        _reachSwitch = [self createSwitchAtX:185 y:180 action:@selector(reachToggled:) targetCard:combatCard];

        _reachDistLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 215, 220, 15)];
        _reachDistLabel.text = @"Range: 5.0m";
        _reachDistLabel.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
        _reachDistLabel.font = [UIFont systemFontOfSize:11.0];
        [combatCard addSubview:_reachDistLabel];

        _reachDistSlider = [[UISlider alloc] initWithFrame:CGRectMake(15, 230, 220, 20)];
        _reachDistSlider.minimumValue = 3.0f;
        _reachDistSlider.maximumValue = 10.0f;
        _reachDistSlider.value = 5.0f;
        _reachDistSlider.minimumTrackTintColor = [UIColor colorWithRed:0.45 green:0.25 blue:0.90 alpha:1.0];
        [_reachDistSlider addTarget:self action:@selector(reachDistChanged:) forControlEvents:UIControlEventValueChanged];
        [combatCard addSubview:_reachDistSlider];

        cardY += 275;

        // 2. MOVEMENT CARD
        UIView *moveCard = [self createCardWithFrame:CGRectMake(15, cardY, 250, 320) title:@"Movement"];
        [_scrollView addSubview:moveCard];

        UILabel *lblFly = [[UILabel alloc] initWithFrame:CGRectMake(15, 45, 120, 30)];
        lblFly.text = @"Fly Hack";
        lblFly.textColor = [UIColor colorWithWhite:0.9 alpha:1.0];
        lblFly.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
        [moveCard addSubview:lblFly];
        _flySwitch = [self createSwitchAtX:185 y:45 action:@selector(flyToggled:) targetCard:moveCard];

        _speedLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 80, 220, 15)];
        _speedLabel.text = @"Fly Speed: 1.5";
        _speedLabel.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
        _speedLabel.font = [UIFont systemFontOfSize:11.0];
        [moveCard addSubview:_speedLabel];

        _speedSlider = [[UISlider alloc] initWithFrame:CGRectMake(15, 95, 220, 20)];
        _speedSlider.minimumValue = 0.5f;
        _speedSlider.maximumValue = 5.0f;
        _speedSlider.value = 1.5f;
        _speedSlider.minimumTrackTintColor = [UIColor colorWithRed:0.45 green:0.25 blue:0.90 alpha:1.0];
        [_speedSlider addTarget:self action:@selector(speedChanged:) forControlEvents:UIControlEventValueChanged];
        [moveCard addSubview:_speedSlider];

        UILabel *lblSpeed = [[UILabel alloc] initWithFrame:CGRectMake(15, 135, 120, 30)];
        lblSpeed.text = @"Speed Hack";
        lblSpeed.textColor = [UIColor colorWithWhite:0.9 alpha:1.0];
        lblSpeed.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
        [moveCard addSubview:lblSpeed];
        _speedSwitch = [self createSwitchAtX:185 y:135 action:@selector(speedToggled:) targetCard:moveCard];

        _speedValLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 170, 220, 15)];
        _speedValLabel.text = @"Speed Value: 2.0x";
        _speedValLabel.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
        _speedValLabel.font = [UIFont systemFontOfSize:11.0];
        [moveCard addSubview:_speedValLabel];

        _speedValSlider = [[UISlider alloc] initWithFrame:CGRectMake(15, 185, 220, 20)];
        _speedValSlider.minimumValue = 1.0f;
        _speedValSlider.maximumValue = 10.0f;
        _speedValSlider.value = 2.0f;
        _speedValSlider.minimumTrackTintColor = [UIColor colorWithRed:0.45 green:0.25 blue:0.90 alpha:1.0];
        [_speedValSlider addTarget:self action:@selector(speedValChanged:) forControlEvents:UIControlEventValueChanged];
        [moveCard addSubview:_speedValSlider];

        UILabel *lblVel = [[UILabel alloc] initWithFrame:CGRectMake(15, 225, 150, 30)];
        lblVel.text = @"Velocity (Anti-KB)";
        lblVel.textColor = [UIColor colorWithWhite:0.9 alpha:1.0];
        lblVel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
        [moveCard addSubview:lblVel];
        _velocitySwitch = [self createSwitchAtX:185 y:225 action:@selector(velocityToggled:) targetCard:moveCard];

        _velocityValLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 260, 220, 15)];
        _velocityValLabel.text = @"Velocity Scale: 0% (Anti-KB)";
        _velocityValLabel.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
        _velocityValLabel.font = [UIFont systemFontOfSize:11.0];
        [moveCard addSubview:_velocityValLabel];

        _velocityValSlider = [[UISlider alloc] initWithFrame:CGRectMake(15, 275, 220, 20)];
        _velocityValSlider.minimumValue = 0.0f;
        _velocityValSlider.maximumValue = 1.0f;
        _velocityValSlider.value = 0.0f;
        _velocityValSlider.minimumTrackTintColor = [UIColor colorWithRed:0.45 green:0.25 blue:0.90 alpha:1.0];
        [_velocityValSlider addTarget:self action:@selector(velocityValChanged:) forControlEvents:UIControlEventValueChanged];
        [moveCard addSubview:_velocityValSlider];

        cardY += 335;

        // 3. VISUALS CARD
        UIView *visualsCard = [self createCardWithFrame:CGRectMake(15, cardY, 250, 200) title:@"Visuals / Overlay"];
        [_scrollView addSubview:visualsCard];

        UILabel *lblEsp = [[UILabel alloc] initWithFrame:CGRectMake(15, 45, 120, 30)];
        lblEsp.text = @"ESP Boxes";
        lblEsp.textColor = [UIColor colorWithWhite:0.9 alpha:1.0];
        lblEsp.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
        [visualsCard addSubview:lblEsp];
        _espSwitch = [self createSwitchAtX:185 y:45 action:@selector(espToggled:) targetCard:visualsCard];

        [visualsCard addSubview:[self createColorPickerWithY:80 tag:100 defaultIdx:0]];

        UILabel *lblTracer = [[UILabel alloc] initWithFrame:CGRectMake(15, 120, 120, 30)];
        lblTracer.text = @"ESP Tracers";
        lblTracer.textColor = [UIColor colorWithWhite:0.9 alpha:1.0];
        lblTracer.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
        [visualsCard addSubview:lblTracer];
        _tracerSwitch = [self createSwitchAtX:185 y:120 action:@selector(tracerToggled:) targetCard:visualsCard];

        [visualsCard addSubview:[self createColorPickerWithY:155 tag:101 defaultIdx:4]];

        cardY += 215;

        // 4. STORAGE ESP CARD
        UILabel *storageSec = [[UILabel alloc] initWithFrame:CGRectMake(15, cardY, 250, 20)];
        storageSec.text = @"STORAGE ESP";
        storageSec.textColor = [UIColor systemPurpleColor];
        storageSec.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightBold];
        [_scrollView addSubview:storageSec];
        cardY += 25;

        // Master Switch
        UILabel *masterText = [[UILabel alloc] initWithFrame:CGRectMake(20, cardY, 150, 30)];
        masterText.text = @"Enable Storage ESP";
        masterText.textColor = [UIColor whiteColor];
        [_scrollView addSubview:masterText];

        _storageEspSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(200, cardY, 50, 30)];
        _storageEspSwitch.onTintColor = [UIColor systemPurpleColor];
        [_storageEspSwitch addTarget:self action:@selector(storageEspToggled:) forControlEvents:UIControlEventValueChanged];
        [_scrollView addSubview:_storageEspSwitch];
        cardY += 40;

        // Create Container for Sub-Options
        UIView *storageSubContainer = [[UIView alloc] initWithFrame:CGRectMake(0, cardY, 280, 520)];
        storageSubContainer.tag = 999;
        storageSubContainer.hidden = YES; // Hidden by default
        [_scrollView addSubview:storageSubContainer];
        
        CGFloat subY = 0;

        // Chest
        UILabel *chestText = [[UILabel alloc] initWithFrame:CGRectMake(20, subY, 120, 30)];
        chestText.text = @"Chests ESP";
        chestText.textColor = [UIColor whiteColor];
        [storageSubContainer addSubview:chestText];
        _chestSwitch = [self createSwitchAtX:200 y:subY action:@selector(chestToggled:) targetCard:storageSubContainer];
        subY += 35;
        [storageSubContainer addSubview:[self createColorPickerWithY:subY tag:102 defaultIdx:5]];
        subY += 40;

        // Ender Chest
        UILabel *enderChestText = [[UILabel alloc] initWithFrame:CGRectMake(20, subY, 150, 30)];
        enderChestText.text = @"Ender Chests ESP";
        enderChestText.textColor = [UIColor whiteColor];
        [storageSubContainer addSubview:enderChestText];
        _enderChestSwitch = [self createSwitchAtX:200 y:subY action:@selector(enderChestToggled:) targetCard:storageSubContainer];
        subY += 35;
        [storageSubContainer addSubview:[self createColorPickerWithY:subY tag:103 defaultIdx:2]];
        subY += 40;

        // Hopper
        UILabel *hopperText = [[UILabel alloc] initWithFrame:CGRectMake(20, subY, 120, 30)];
        hopperText.text = @"Hoppers ESP";
        hopperText.textColor = [UIColor whiteColor];
        [storageSubContainer addSubview:hopperText];
        _hopperSwitch = [self createSwitchAtX:200 y:subY action:@selector(hopperToggled:) targetCard:storageSubContainer];
        subY += 35;
        [storageSubContainer addSubview:[self createColorPickerWithY:subY tag:104 defaultIdx:6]];
        subY += 40;

        // Spawner
        UILabel *spawnerText = [[UILabel alloc] initWithFrame:CGRectMake(20, subY, 120, 30)];
        spawnerText.text = @"Spawners ESP";
        spawnerText.textColor = [UIColor whiteColor];
        [storageSubContainer addSubview:spawnerText];
        _spawnerSwitch = [self createSwitchAtX:200 y:subY action:@selector(spawnerToggled:) targetCard:storageSubContainer];
        subY += 35;
        [storageSubContainer addSubview:[self createColorPickerWithY:subY tag:105 defaultIdx:1]];
        subY += 40;

        // Piston
        UILabel *pistonText = [[UILabel alloc] initWithFrame:CGRectMake(20, subY, 120, 30)];
        pistonText.text = @"Pistons ESP";
        pistonText.textColor = [UIColor whiteColor];
        [storageSubContainer addSubview:pistonText];
        _pistonSwitch = [self createSwitchAtX:200 y:subY action:@selector(pistonToggled:) targetCard:storageSubContainer];
        subY += 35;
        [storageSubContainer addSubview:[self createColorPickerWithY:subY tag:106 defaultIdx:3]];
        subY += 40;

        // Barrel
        UILabel *barrelText = [[UILabel alloc] initWithFrame:CGRectMake(20, subY, 120, 30)];
        barrelText.text = @"Barrels ESP";
        barrelText.textColor = [UIColor whiteColor];
        [storageSubContainer addSubview:barrelText];
        _barrelSwitch = [self createSwitchAtX:200 y:subY action:@selector(barrelToggled:) targetCard:storageSubContainer];
        subY += 35;
        [storageSubContainer addSubview:[self createColorPickerWithY:subY tag:107 defaultIdx:3]];
        
        cardY += 520;
        cardY += 45;

        // Speed Section
        _speedLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, cardY, 120, 20)];
        _speedLabel.text = @"Fly Speed: 1.5";
        _speedLabel.textColor = [UIColor lightGrayColor];
        _speedLabel.font = [UIFont systemFontOfSize:12.0];
        [_scrollView addSubview:_speedLabel];
        
        _speedSlider = [[UISlider alloc] initWithFrame:CGRectMake(120, cardY, 140, 30)];
        _speedSlider.minimumValue = 0.5f;
        _speedSlider.maximumValue = 5.0f;
        _speedSlider.value = 1.5f;
        _speedSlider.tintColor = [UIColor systemPurpleColor];
        [_speedSlider addTarget:self action:@selector(speedChanged:) forControlEvents:UIControlEventValueChanged];
        [_scrollView addSubview:_speedSlider];
        
        // 3. Float Toggle Button
        _toggleButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _toggleButton.frame = CGRectMake(50, 80, 54, 54);
        _toggleButton.backgroundColor = [UIColor colorWithRed:0.45 green:0.25 blue:0.90 alpha:0.90];
        _toggleButton.layer.cornerRadius = 27.0;
        _toggleButton.layer.borderWidth = 1.5;
        _toggleButton.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.35].CGColor;
        
        // Shadow/Glow effect
        _toggleButton.layer.shadowColor = [UIColor colorWithRed:0.55 green:0.35 blue:0.95 alpha:1.0].CGColor;
        _toggleButton.layer.shadowOpacity = 0.8;
        _toggleButton.layer.shadowOffset = CGSizeZero;
        _toggleButton.layer.shadowRadius = 8.0;
        
        [_toggleButton setTitle:@"YP" forState:UIControlStateNormal];
        [_toggleButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _toggleButton.titleLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightHeavy];
        [_toggleButton addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
        
        UIPanGestureRecognizer *btnPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleButtonPan:)];
        [_toggleButton addGestureRecognizer:btnPan];
        
        [self addSubview:_toggleButton];
        
        _scrollView.contentSize = CGSizeMake(280, 900);
    }
    return self;
}

- (void)toggleMenu {
    BOOL isHidden = _panelView.hidden;
    
    if (isHidden) {
        _panelView.hidden = NO;
        _panelView.alpha = 0.0f;
        _panelView.transform = CGAffineTransformMakeScale(0.85f, 0.85f);
        
        [UIView animateWithDuration:0.3 delay:0.0 usingSpringWithDamping:0.75 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self->_panelView.alpha = 1.0f;
            self->_panelView.transform = CGAffineTransformIdentity;
        } completion:nil];
    } else {
        [UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self->_panelView.alpha = 0.0f;
            self->_panelView.transform = CGAffineTransformMakeScale(0.85f, 0.85f);
        } completion:^(BOOL finished) {
            self->_panelView.hidden = YES;
        }];
    }
}

- (void)colorChanged:(UISegmentedControl *)sender {
    float colorPresets[7][3] = {
        {1.0f, 0.0f, 0.0f},
        {0.0f, 1.0f, 0.0f},
        {0.0f, 0.0f, 1.0f},
        {1.0f, 1.0f, 0.0f},
        {0.5f, 0.0f, 0.5f},
        {1.0f, 0.6f, 0.0f},
        {1.0f, 1.0f, 1.0f}
    };
    
    NSInteger index = sender.selectedSegmentIndex;
    if (index < 0 || index > 6) return;
    
    float *targetColor = nullptr;
    switch (sender.tag) {
        case 100: targetColor = Hooks::espColor; break;
        case 101: targetColor = Hooks::tracerColor; break;
        case 102: targetColor = Hooks::storageChestColor; break;
        case 103: targetColor = Hooks::storageEnderChestColor; break;
        case 104: targetColor = Hooks::storageHopperColor; break;
        case 105: targetColor = Hooks::storageSpawnerColor; break;
        case 106: targetColor = Hooks::storagePistonColor; break;
        case 107: targetColor = Hooks::storageBarrelColor; break;
    }
    
    if (targetColor) {
        targetColor[0] = colorPresets[index][0];
        targetColor[1] = colorPresets[index][1];
        targetColor[2] = colorPresets[index][2];
    }
}

- (void)flyToggled:(UISwitch *)sender {
    Hooks::flyEnabled = sender.isOn;
}

- (void)speedToggled:(UISwitch *)sender {
    Hooks::speedEnabled = sender.isOn;
}

- (void)speedValChanged:(UISlider *)sender {
    Hooks::speedValue = sender.value;
    _speedValLabel.text = [NSString stringWithFormat:@"Speed Value: %.1fx", sender.value];
}

- (void)reachToggled:(UISwitch *)sender {
    Hooks::reachEnabled = sender.isOn;
}

- (void)reachDistChanged:(UISlider *)sender {
    Hooks::reachDistance = sender.value;
    _reachDistLabel.text = [NSString stringWithFormat:@"Range: %.1fm", sender.value];
}

- (void)velocityToggled:(UISwitch *)sender {
    Hooks::velocityEnabled = sender.isOn;
}

- (void)velocityValChanged:(UISlider *)sender {
    Hooks::velocityValue = sender.value;
    _velocityValLabel.text = [NSString stringWithFormat:@"Velocity Scale: %.0f%% (Anti-KB)", sender.value * 100.0f];
}

- (void)killauraToggled:(UISwitch *)sender {
    Hooks::killauraEnabled = sender.isOn;
}

- (void)aimassistToggled:(UISwitch *)sender {
    Hooks::aimassistEnabled = sender.isOn;
}

- (void)triggerbotToggled:(UISwitch *)sender {
    Hooks::triggerbotEnabled = sender.isOn;
}

- (void)espToggled:(UISwitch *)sender {
    Hooks::espEnabled = sender.isOn;
}

- (void)tracerToggled:(UISwitch *)sender {
    Hooks::tracerEnabled = sender.isOn;
}

- (void)storageEspToggled:(UISwitch *)sender {
    Hooks::storageEspEnabled = sender.isOn;
    
    UIView *container = [_scrollView viewWithTag:999];
    if (container) {
        [UIView transitionWithView:container duration:0.3 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
            container.hidden = !sender.isOn;
        } completion:^(BOOL finished) {
            // Adjust scroll content size dynamically
            if (sender.isOn) {
                self->_scrollView.contentSize = CGSizeMake(280, 1420);
            } else {
                self->_scrollView.contentSize = CGSizeMake(280, 900);
            }
        }];
    }
}

- (void)chestToggled:(UISwitch *)sender {
    Hooks::storageChestEnabled = sender.isOn;
}

- (void)enderChestToggled:(UISwitch *)sender {
    Hooks::storageEnderChestEnabled = sender.isOn;
}

- (void)hopperToggled:(UISwitch *)sender {
    Hooks::storageHopperEnabled = sender.isOn;
}

- (void)spawnerToggled:(UISwitch *)sender {
    Hooks::storageSpawnerEnabled = sender.isOn;
}

- (void)pistonToggled:(UISwitch *)sender {
    Hooks::storagePistonEnabled = sender.isOn;
}

- (void)barrelToggled:(UISwitch *)sender {
    Hooks::storageBarrelEnabled = sender.isOn;
}

- (void)speedChanged:(UISlider *)sender {
    Hooks::flySpeed = sender.value;
    _speedLabel.text = [NSString stringWithFormat:@"Fly Speed: %.1f", sender.value];
}

- (void)handlePan:(UIPanGestureRecognizer *)sender {
    CGPoint translation = [sender translationInView:self];
    sender.view.center = CGPointMake(sender.view.center.x + translation.x, sender.view.center.y + translation.y);
    [sender setTranslation:CGPointZero inView:self];
}

- (void)handleButtonPan:(UIPanGestureRecognizer *)sender {
    CGPoint translation = [sender translationInView:self];
    sender.view.center = CGPointMake(sender.view.center.x + translation.x, sender.view.center.y + translation.y);
    [sender setTranslation:CGPointZero inView:self];
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    if (CGRectContainsPoint(_toggleButton.frame, point)) {
        return YES;
    }
    if (!_panelView.hidden && CGRectContainsPoint(_panelView.frame, point)) {
        return YES;
    }
    return NO;
}

@end

void SetupGUI() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window && [UIApplication sharedApplication].windows.count > 0) {
            window = [UIApplication sharedApplication].windows.firstObject;
        }
        
        if (window) {
            UIView *parentView = window.rootViewController.view ? window.rootViewController.view : window;
            
            ESPView *espView = [[ESPView alloc] initWithFrame:window.bounds];
            espView.layer.zPosition = 9999.0;
            [parentView addSubview:espView];
            
            FloatMenu *menu = [[FloatMenu alloc] initWithFrame:window.bounds];
            menu.layer.zPosition = 10000.0;
            [parentView addSubview:menu];
            
            NSLog(@"[yt] gui loaded");
        } else {
            SetupGUI();
        }
    });
}

__attribute__((constructor))
static void initialize() {
    Hooks::SetupMinecraftHooks();
    SetupXboxBypass();
    SetupGUI();
}
