#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#include "hooks.hpp"
#include "memory.hpp"

namespace Hooks {
    extern bool killauraEnabled;
    extern bool aimassistEnabled;
    extern bool triggerbotEnabled;
    extern bool flyEnabled;
    extern bool espEnabled;
    extern bool tracerEnabled;
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
}

@interface ESPView : UIView
@property (nonatomic, strong) CADisplayLink *displayLink;
@end

@implementation ESPView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO; // Passthrough touch events so gameplay is unaffected
        
        // Refresh drawing on every screen frame
        _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(redraw)];
        [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    }
    return self;
}

- (void)redraw {
    if (Hooks::espEnabled || Hooks::tracerEnabled || 
        Hooks::storageChestEnabled || Hooks::storageEnderChestEnabled ||
        Hooks::storageHopperEnabled || Hooks::storageSpawnerEnabled || 
        Hooks::storagePistonEnabled || Hooks::storageBarrelEnabled) {
        [self setNeedsDisplay];
    } else {
        // Clear screen when all are disabled
        self.layer.sublayers = nil;
    }
}

// Helper to convert float array to UIColor
static UIColor* ColorFromFloat(float color[3]) {
    return [UIColor colorWithRed:color[0] green:color[1] blue:color[2] alpha:1.0];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (!context) return;
    
    // 1. Draw Player ESP & Tracers
    CGRect espBox = CGRectMake(rect.size.width / 2.0 - 50, rect.size.height / 2.0 - 100, 100, 200);
    
    if (Hooks::espEnabled) {
        UIColor *c = ColorFromFloat(Hooks::espColor);
        CGContextSetStrokeColorWithColor(context, c.CGColor);
        CGContextSetLineWidth(context, 2.0);
        CGContextStrokeRect(context, espBox);
        
        NSString *text = @"Enemy Player [15m]";
        NSDictionary *attributes = @{
            NSFontAttributeName: [UIFont systemFontOfSize:12.0 weight:UIFontWeightBold],
            NSForegroundColorAttributeName: c
        };
        [text drawAtPoint:CGPointMake(espBox.origin.x, espBox.origin.y - 20) withAttributes:attributes];
    }
    
    if (Hooks::tracerEnabled) {
        UIColor *c = ColorFromFloat(Hooks::tracerColor);
        CGContextSetStrokeColorWithColor(context, c.CGColor);
        CGContextSetLineWidth(context, 1.5);
        
        CGPoint screenBottom = CGPointMake(rect.size.width / 2.0, rect.size.height);
        CGPoint targetFeet = CGPointMake(espBox.origin.x + espBox.size.width / 2.0, espBox.origin.y + espBox.size.height);
        
        CGContextBeginPath(context);
        CGContextMoveToPoint(context, screenBottom.x, screenBottom.y);
        CGContextAddLineToPoint(context, targetFeet.x, targetFeet.y);
        CGContextStrokePath(context);
    }

    // Helper lambda to draw custom Storage ESP Box
    auto drawStorageBox = [&](CGRect box, UIColor *color, NSString *name) {
        CGContextSetStrokeColorWithColor(context, color.CGColor);
        CGContextSetLineWidth(context, 1.5);
        CGContextStrokeRect(context, box);
        
        NSDictionary *attributes = @{
            NSFontAttributeName: [UIFont systemFontOfSize:10.0 weight:UIFontWeightBold],
            NSForegroundColorAttributeName: color
        };
        [name drawAtPoint:CGPointMake(box.origin.x, box.origin.y - 14) withAttributes:attributes];
    };

    if (Hooks::storageChestEnabled) {
        drawStorageBox(CGRectMake(60, 150, 40, 40), ColorFromFloat(Hooks::storageChestColor), @"Chest [8m]");
    }
    if (Hooks::storageEnderChestEnabled) {
        drawStorageBox(CGRectMake(60, 210, 40, 40), ColorFromFloat(Hooks::storageEnderChestColor), @"Ender Chest [11m]");
    }
    if (Hooks::storageHopperEnabled) {
        drawStorageBox(CGRectMake(rect.size.width - 100, 180, 40, 45), ColorFromFloat(Hooks::storageHopperColor), @"Hopper [12m]");
    }
    if (Hooks::storageSpawnerEnabled) {
        drawStorageBox(CGRectMake(120, rect.size.height - 220, 50, 50), ColorFromFloat(Hooks::storageSpawnerColor), @"Spawner [18m]");
    }
    if (Hooks::storagePistonEnabled) {
        drawStorageBox(CGRectMake(rect.size.width - 160, rect.size.height - 180, 40, 40), ColorFromFloat(Hooks::storagePistonColor), @"Piston [5m]");
    }
    if (Hooks::storageBarrelEnabled) {
        drawStorageBox(CGRectMake(80, rect.size.height - 320, 35, 45), ColorFromFloat(Hooks::storageBarrelColor), @"Barrel [14m]");
    }
}

@end

// FloatMenu: A floating premium UIKit panel for managing cheat settings on iOS
@interface FloatMenu : UIView {
    CGPoint lastPoint;
}
@property (nonatomic, strong) UIButton *toggleButton;
@property (nonatomic, strong) UIView *panelView;
@property (nonatomic, strong) UIScrollView *scrollView;

@property (nonatomic, strong) UISwitch *flySwitch;
@property (nonatomic, strong) UISwitch *killauraSwitch;
@property (nonatomic, strong) UISwitch *aimassistSwitch;
@property (nonatomic, strong) UISwitch *triggerbotSwitch;
@property (nonatomic, strong) UISwitch *espSwitch;
@property (nonatomic, strong) UISwitch *tracerSwitch;

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
    seg.frame = CGRectMake(20, y, 240, 24);
    seg.selectedSegmentIndex = idx;
    seg.tag = tag;
    
    seg.backgroundColor = [UIColor colorWithRed:0.15 green:0.15 blue:0.18 alpha:1.0];
    seg.selectedSegmentTintColor = [UIColor colorWithRed:0.25 green:0.25 blue:0.32 alpha:1.0];
    
    NSDictionary *attr = @{NSForegroundColorAttributeName: [UIColor whiteColor]};
    [seg setTitleTextAttributes:attr forState:UIControlStateNormal];
    [seg setTitleTextAttributes:attr forState:UIControlStateSelected];
    
    [seg addTarget:self action:@selector(colorChanged:) forControlEvents:UIControlEventValueChanged];
    return seg;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        
        _panelView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 280, 360)];
        _panelView.backgroundColor = [UIColor colorWithRed:0.10 green:0.10 blue:0.12 alpha:0.92];
        _panelView.layer.cornerRadius = 16.0;
        _panelView.layer.shadowColor = [UIColor blackColor].CGColor;
        _panelView.layer.shadowOpacity = 0.5;
        _panelView.layer.shadowOffset = CGSizeMake(0, 4);
        _panelView.layer.shadowRadius = 8.0;
        _panelView.layer.borderWidth = 1.0;
        _panelView.layer.borderColor = [UIColor colorWithRed:0.25 green:0.25 blue:0.30 alpha:1.0].CGColor;
        _panelView.hidden = YES;
        [self addSubview:_panelView];
        
        // Drag Gesture for the Panel
        UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [_panelView addGestureRecognizer:panGesture];
        
        // Drag handle bar
        UIView *dragHandle = [[UIView alloc] initWithFrame:CGRectMake(110, 8, 60, 4)];
        dragHandle.backgroundColor = [UIColor grayColor];
        dragHandle.layer.cornerRadius = 2.0;
        [_panelView addSubview:dragHandle];
        
        // Title Label
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 15, 260, 30)];
        titleLabel.text = @"ytpavlov client";
        titleLabel.textColor = [UIColor whiteColor];
        titleLabel.font = [UIFont systemFontOfSize:18.0 weight:UIFontWeightBold];
        titleLabel.textAlignment = NSTextAlignmentCenter;
        [_panelView addSubview:titleLabel];

        // 2. ScrollView initialization
        _scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 50, 280, 300)];
        _scrollView.showsVerticalScrollIndicator = YES;
        _scrollView.contentSize = CGSizeMake(280, 1100); // Expanded content height for all controllers
        [_panelView addSubview:_scrollView];
        
        CGFloat currentY = 10;
        
        // --- General Section ---
        UILabel *generalSec = [[UILabel alloc] initWithFrame:CGRectMake(15, currentY, 250, 20)];
        generalSec.text = @"GENERAL CHEATS";
        generalSec.textColor = [UIColor systemPurpleColor];
        generalSec.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightBold];
        [_scrollView addSubview:generalSec];
        currentY += 25;

        // Fly Switch
        UILabel *flyText = [[UILabel alloc] initWithFrame:CGRectMake(20, currentY, 120, 30)];
        flyText.text = @"Fly Hack";
        flyText.textColor = [UIColor whiteColor];
        [_scrollView addSubview:flyText];
        
        _flySwitch = [[UISwitch alloc] initWithFrame:CGRectMake(200, currentY, 50, 30)];
        _flySwitch.onTintColor = [UIColor systemPurpleColor];
        [_flySwitch addTarget:self action:@selector(flyToggled:) forControlEvents:UIControlEventValueChanged];
        [_scrollView addSubview:_flySwitch];
        currentY += 40;
        
        // Killaura Switch
        UILabel *killText = [[UILabel alloc] initWithFrame:CGRectMake(20, currentY, 120, 30)];
        killText.text = @"Killaura";
        killText.textColor = [UIColor whiteColor];
        [_scrollView addSubview:killText];
        
        _killauraSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(200, currentY, 50, 30)];
        _killauraSwitch.onTintColor = [UIColor systemPurpleColor];
        [_killauraSwitch addTarget:self action:@selector(killauraToggled:) forControlEvents:UIControlEventValueChanged];
        [_scrollView addSubview:_killauraSwitch];
        currentY += 40;

        // AimAssist Switch
        UILabel *aimText = [[UILabel alloc] initWithFrame:CGRectMake(20, currentY, 120, 30)];
        aimText.text = @"Aim Assist";
        aimText.textColor = [UIColor whiteColor];
        [_scrollView addSubview:aimText];
        
        _aimassistSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(200, currentY, 50, 30)];
        _aimassistSwitch.onTintColor = [UIColor systemPurpleColor];
        [_aimassistSwitch addTarget:self action:@selector(aimassistToggled:) forControlEvents:UIControlEventValueChanged];
        [_scrollView addSubview:_aimassistSwitch];
        currentY += 40;

        // Triggerbot Switch
        UILabel *triggerText = [[UILabel alloc] initWithFrame:CGRectMake(20, currentY, 120, 30)];
        triggerText.text = @"Triggerbot";
        triggerText.textColor = [UIColor whiteColor];
        [_scrollView addSubview:triggerText];
        
        _triggerbotSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(200, currentY, 50, 30)];
        _triggerbotSwitch.onTintColor = [UIColor systemPurpleColor];
        [_triggerbotSwitch addTarget:self action:@selector(triggerbotToggled:) forControlEvents:UIControlEventValueChanged];
        [_scrollView addSubview:_triggerbotSwitch];
        currentY += 40;

        // Speed Hack Switch
        UILabel *speedText = [[UILabel alloc] initWithFrame:CGRectMake(20, currentY, 120, 30)];
        speedText.text = @"Speed Hack";
        speedText.textColor = [UIColor whiteColor];
        [_scrollView addSubview:speedText];

        _speedSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(200, currentY, 50, 30)];
        _speedSwitch.onTintColor = [UIColor systemPurpleColor];
        [_speedSwitch addTarget:self action:@selector(speedToggled:) forControlEvents:UIControlEventValueChanged];
        [_scrollView addSubview:_speedSwitch];
        currentY += 35;

        // Speed Value Slider
        _speedValLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, currentY, 150, 20)];
        _speedValLabel.text = @"Speed Multiplier: 2.0";
        _speedValLabel.textColor = [UIColor lightGrayColor];
        _speedValLabel.font = [UIFont systemFontOfSize:12.0];
        [_scrollView addSubview:_speedValLabel];
        currentY += 20;

        _speedValSlider = [[UISlider alloc] initWithFrame:CGRectMake(20, currentY, 240, 30)];
        _speedValSlider.minimumValue = 1.0f;
        _speedValSlider.maximumValue = 10.0f;
        _speedValSlider.value = 2.0f;
        _speedValSlider.tintColor = [UIColor systemPurpleColor];
        [_speedValSlider addTarget:self action:@selector(speedValChanged:) forControlEvents:UIControlEventValueChanged];
        [_scrollView addSubview:_speedValSlider];
        currentY += 40;

        // Reach Switch
        UILabel *reachText = [[UILabel alloc] initWithFrame:CGRectMake(20, currentY, 120, 30)];
        reachText.text = @"Reach Hack";
        reachText.textColor = [UIColor whiteColor];
        [_scrollView addSubview:reachText];

        _reachSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(200, currentY, 50, 30)];
        _reachSwitch.onTintColor = [UIColor systemPurpleColor];
        [_reachSwitch addTarget:self action:@selector(reachToggled:) forControlEvents:UIControlEventValueChanged];
        [_scrollView addSubview:_reachSwitch];
        currentY += 35;

        // Reach Distance Slider
        _reachDistLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, currentY, 150, 20)];
        _reachDistLabel.text = @"Reach Distance: 5.0m";
        _reachDistLabel.textColor = [UIColor lightGrayColor];
        _reachDistLabel.font = [UIFont systemFontOfSize:12.0];
        [_scrollView addSubview:_reachDistLabel];
        currentY += 20;

        _reachDistSlider = [[UISlider alloc] initWithFrame:CGRectMake(20, currentY, 240, 30)];
        _reachDistSlider.minimumValue = 3.0f;
        _reachDistSlider.maximumValue = 10.0f;
        _reachDistSlider.value = 5.0f;
        _reachDistSlider.tintColor = [UIColor systemPurpleColor];
        [_reachDistSlider addTarget:self action:@selector(reachDistChanged:) forControlEvents:UIControlEventValueChanged];
        [_scrollView addSubview:_reachDistSlider];
        currentY += 40;

        // Velocity Switch
        UILabel *velText = [[UILabel alloc] initWithFrame:CGRectMake(20, currentY, 150, 30)];
        velText.text = @"Velocity (Anti-KB)";
        velText.textColor = [UIColor whiteColor];
        [_scrollView addSubview:velText];

        _velocitySwitch = [[UISwitch alloc] initWithFrame:CGRectMake(200, currentY, 50, 30)];
        _velocitySwitch.onTintColor = [UIColor systemPurpleColor];
        [_velocitySwitch addTarget:self action:@selector(velocityToggled:) forControlEvents:UIControlEventValueChanged];
        [_scrollView addSubview:_velocitySwitch];
        currentY += 35;

        // Velocity Slider
        _velocityValLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, currentY, 200, 20)];
        _velocityValLabel.text = @"Velocity Scale: 0% (Anti-KB)";
        _velocityValLabel.textColor = [UIColor lightGrayColor];
        _velocityValLabel.font = [UIFont systemFontOfSize:12.0];
        [_scrollView addSubview:_velocityValLabel];
        currentY += 20;

        _velocityValSlider = [[UISlider alloc] initWithFrame:CGRectMake(20, currentY, 240, 30)];
        _velocityValSlider.minimumValue = 0.0f; // 0% knockback
        _velocityValSlider.maximumValue = 1.0f; // 100% knockback
        _velocityValSlider.value = 0.0f;
        _velocityValSlider.tintColor = [UIColor systemPurpleColor];
        [_velocityValSlider addTarget:self action:@selector(velocityValChanged:) forControlEvents:UIControlEventValueChanged];
        [_scrollView addSubview:_velocityValSlider];
        currentY += 40;

        // Player ESP Switch & Color
        UILabel *espText = [[UILabel alloc] initWithFrame:CGRectMake(20, currentY, 120, 30)];
        espText.text = @"ESP (Boxes)";
        espText.textColor = [UIColor whiteColor];
        [_scrollView addSubview:espText];
        
        _espSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(200, currentY, 50, 30)];
        _espSwitch.onTintColor = [UIColor systemPurpleColor];
        [_espSwitch addTarget:self action:@selector(espToggled:) forControlEvents:UIControlEventValueChanged];
        [_scrollView addSubview:_espSwitch];
        currentY += 35;
        
        // Player ESP Color Picker (tag 100, default idx 0 = Red)
        [_scrollView addSubview:[self createColorPickerWithY:currentY tag:100 defaultIdx:0]];
        currentY += 35;
        
        // Tracer Switch & Color
        UILabel *tracerText = [[UILabel alloc] initWithFrame:CGRectMake(20, currentY, 120, 30)];
        tracerText.text = @"ESP (Tracers)";
        tracerText.textColor = [UIColor whiteColor];
        [_scrollView addSubview:tracerText];
        
        _tracerSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(200, currentY, 50, 30)];
        _tracerSwitch.onTintColor = [UIColor systemPurpleColor];
        [_tracerSwitch addTarget:self action:@selector(tracerToggled:) forControlEvents:UIControlEventValueChanged];
        [_scrollView addSubview:_tracerSwitch];
        currentY += 35;
        
        // Tracer ESP Color Picker (tag 101, default idx 4 = Purple)
        [_scrollView addSubview:[self createColorPickerWithY:currentY tag:101 defaultIdx:4]];
        currentY += 45;

        // --- Storage ESP Section ---
        UILabel *storageSec = [[UILabel alloc] initWithFrame:CGRectMake(15, currentY, 250, 20)];
        storageSec.text = @"STORAGE ESP";
        storageSec.textColor = [UIColor systemPurpleColor];
        storageSec.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightBold];
        [_scrollView addSubview:storageSec];
        currentY += 25;

        // Chest Switch & Color
        UILabel *chestText = [[UILabel alloc] initWithFrame:CGRectMake(20, currentY, 120, 30)];
        chestText.text = @"Chests ESP";
        chestText.textColor = [UIColor whiteColor];
        [_scrollView addSubview:chestText];

        _chestSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(200, currentY, 50, 30)];
        _chestSwitch.onTintColor = [UIColor systemPurpleColor];
        [_chestSwitch addTarget:self action:@selector(chestToggled:) forControlEvents:UIControlEventValueChanged];
        [_scrollView addSubview:_chestSwitch];
        currentY += 35;
        [_scrollView addSubview:[self createColorPickerWithY:currentY tag:102 defaultIdx:5]]; // Orange
        currentY += 40;

        // Ender Chest Switch & Color
        UILabel *enderChestText = [[UILabel alloc] initWithFrame:CGRectMake(20, currentY, 150, 30)];
        enderChestText.text = @"Ender Chests ESP";
        enderChestText.textColor = [UIColor whiteColor];
        [_scrollView addSubview:enderChestText];

        _enderChestSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(200, currentY, 50, 30)];
        _enderChestSwitch.onTintColor = [UIColor systemPurpleColor];
        [_enderChestSwitch addTarget:self action:@selector(enderChestToggled:) forControlEvents:UIControlEventValueChanged];
        [_scrollView addSubview:_enderChestSwitch];
        currentY += 35;
        [_scrollView addSubview:[self createColorPickerWithY:currentY tag:103 defaultIdx:2]]; // Blue/Cyan
        currentY += 40;

        // Hopper Switch & Color
        UILabel *hopperText = [[UILabel alloc] initWithFrame:CGRectMake(20, currentY, 120, 30)];
        hopperText.text = @"Hoppers ESP";
        hopperText.textColor = [UIColor whiteColor];
        [_scrollView addSubview:hopperText];

        _hopperSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(200, currentY, 50, 30)];
        _hopperSwitch.onTintColor = [UIColor systemPurpleColor];
        [_hopperSwitch addTarget:self action:@selector(hopperToggled:) forControlEvents:UIControlEventValueChanged];
        [_scrollView addSubview:_hopperSwitch];
        currentY += 35;
        [_scrollView addSubview:[self createColorPickerWithY:currentY tag:104 defaultIdx:6]]; // White/Gray
        currentY += 40;

        // Spawner Switch & Color
        UILabel *spawnerText = [[UILabel alloc] initWithFrame:CGRectMake(20, currentY, 120, 30)];
        spawnerText.text = @"Spawners ESP";
        spawnerText.textColor = [UIColor whiteColor];
        [_scrollView addSubview:spawnerText];

        _spawnerSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(200, currentY, 50, 30)];
        _spawnerSwitch.onTintColor = [UIColor systemPurpleColor];
        [_spawnerSwitch addTarget:self action:@selector(spawnerToggled:) forControlEvents:UIControlEventValueChanged];
        [_scrollView addSubview:_spawnerSwitch];
        currentY += 35;
        [_scrollView addSubview:[self createColorPickerWithY:currentY tag:105 defaultIdx:1]]; // Green
        currentY += 40;

        // Piston Switch & Color
        UILabel *pistonText = [[UILabel alloc] initWithFrame:CGRectMake(20, currentY, 120, 30)];
        pistonText.text = @"Pistons ESP";
        pistonText.textColor = [UIColor whiteColor];
        [_scrollView addSubview:pistonText];

        _pistonSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(200, currentY, 50, 30)];
        _pistonSwitch.onTintColor = [UIColor systemPurpleColor];
        [_pistonSwitch addTarget:self action:@selector(pistonToggled:) forControlEvents:UIControlEventValueChanged];
        [_scrollView addSubview:_pistonSwitch];
        currentY += 35;
        [_scrollView addSubview:[self createColorPickerWithY:currentY tag:106 defaultIdx:3]]; // Yellow/Brown preset
        currentY += 40;

        // Barrel Switch & Color
        UILabel *barrelText = [[UILabel alloc] initWithFrame:CGRectMake(20, currentY, 120, 30)];
        barrelText.text = @"Barrels ESP";
        barrelText.textColor = [UIColor whiteColor];
        [_scrollView addSubview:barrelText];

        _barrelSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(200, currentY, 50, 30)];
        _barrelSwitch.onTintColor = [UIColor systemPurpleColor];
        [_barrelSwitch addTarget:self action:@selector(barrelToggled:) forControlEvents:UIControlEventValueChanged];
        [_scrollView addSubview:_barrelSwitch];
        currentY += 35;
        [_scrollView addSubview:[self createColorPickerWithY:currentY tag:107 defaultIdx:3]]; // Yellow
        currentY += 45;

        // Speed Section
        _speedLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, currentY, 120, 20)];
        _speedLabel.text = @"Fly Speed: 1.5";
        _speedLabel.textColor = [UIColor lightGrayColor];
        _speedLabel.font = [UIFont systemFontOfSize:12.0];
        [_scrollView addSubview:_speedLabel];
        
        _speedSlider = [[UISlider alloc] initWithFrame:CGRectMake(120, currentY, 140, 30)];
        _speedSlider.minimumValue = 0.5f;
        _speedSlider.maximumValue = 5.0f;
        _speedSlider.value = 1.5f;
        _speedSlider.tintColor = [UIColor systemPurpleColor];
        [_speedSlider addTarget:self action:@selector(speedChanged:) forControlEvents:UIControlEventValueChanged];
        [_scrollView addSubview:_speedSlider];
        
        // 3. Float Toggle Button
        _toggleButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _toggleButton.frame = CGRectMake(0, 0, 50, 50);
        _toggleButton.backgroundColor = [UIColor systemPurpleColor];
        _toggleButton.layer.cornerRadius = 25.0;
        _toggleButton.layer.shadowColor = [UIColor blackColor].CGColor;
        _toggleButton.layer.shadowOpacity = 0.4;
        _toggleButton.layer.shadowOffset = CGSizeMake(0, 2);
        [_toggleButton setTitle:@"YP" forState:UIControlStateNormal];
        [_toggleButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _toggleButton.titleLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightBold];
        [_toggleButton addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
        
        // Drag Gesture for Toggle Button
        UIPanGestureRecognizer *btnPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleButtonPan:)];
        [_toggleButton addGestureRecognizer:btnPan];
        
        [self addSubview:_toggleButton];
    }
    return self;
}

- (void)toggleMenu {
    [UIView transitionWithView:_panelView duration:0.3 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
        self->_panelView.hidden = !self->_panelView.hidden;
    } completion:nil];
}

- (void)colorChanged:(UISegmentedControl *)sender {
    // Colors preset mapping: R, G, B
    float colorPresets[7][3] = {
        {1.0f, 0.0f, 0.0f}, // 🔴 Red
        {0.0f, 1.0f, 0.0f}, // 🟢 Green
        {0.0f, 0.0f, 1.0f}, // 🔵 Blue
        {1.0f, 1.0f, 0.0f}, // 🟡 Yellow
        {0.5f, 0.0f, 0.5f}, // 🟣 Purple
        {1.0f, 0.6f, 0.0f}, // 🟠 Orange
        {1.0f, 1.0f, 1.0f}  // ⚪ White
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
    _speedValLabel.text = [NSString stringWithFormat:@"Speed Multiplier: %.1f", sender.value];
}

- (void)reachToggled:(UISwitch *)sender {
    Hooks::reachEnabled = sender.isOn;
}

- (void)reachDistChanged:(UISlider *)sender {
    Hooks::reachDistance = sender.value;
    _reachDistLabel.text = [NSString stringWithFormat:@"Reach Distance: %.1fm", sender.value];
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

@end

void SetupGUI() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window && [UIApplication sharedApplication].windows.count > 0) {
            window = [UIApplication sharedApplication].windows.firstObject;
        }
        
        if (window) {
            ESPView *espView = [[ESPView alloc] initWithFrame:window.bounds];
            [window addSubview:espView];
            
            FloatMenu *menu = [[FloatMenu alloc] initWithFrame:CGRectMake(50, 100, 300, 300)];
            [window addSubview:menu];
            
            NSLog(@"[yt] gui loaded");
        } else {
            SetupGUI();
        }
    });
}

__attribute__((constructor))
static void initialize() {
    Hooks::SetupMinecraftHooks();
    SetupGUI();
}
