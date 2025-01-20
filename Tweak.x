#import <YouTubeHeader/YTColor.h>
#import <YouTubeHeader/YTMainAppVideoPlayerOverlayViewController.h>
#import <YouTubeHeader/YTQTMButton.h>
#import <YouTubeHeader/YTSettingsGroupData.h>
#import <YouTubeHeader/YTSettingsPickerViewController.h>
#import <YouTubeHeader/YTSettingsSectionItem.h>
#import <YouTubeHeader/YTSettingsSectionItemManager.h>
#import <YouTubeHeader/YTSettingsViewController.h>
#import <YouTubeHeader/YTTypeStyle.h>
#import "Header.h"
#import "Init.h"

static const NSInteger YTVideoOverlaySection = 1222;

NSMutableDictionary <NSString *, NSDictionary *> *tweaksMetadata;
NSMutableArray <NSString *> *topButtons;
NSMutableArray <NSString *> *bottomButtons;

static NSBundle *TweakBundle(NSString *name) {
    NSString *tweakBundlePath = [[NSBundle mainBundle] pathForResource:name ofType:@"bundle"];
#if TARGET_OS_SIMULATOR
    return [NSBundle bundleWithPath:tweakBundlePath ?: [NSString stringWithFormat:realPath(@"/Library/Application Support/%@.bundle"), name]];
#else
    return [NSBundle bundleWithPath:tweakBundlePath ?: [NSString stringWithFormat:ROOT_PATH_NS(@"/Library/Application Support/%@.bundle"), name]];
#endif
}

static NSString *EnabledKey(NSString *name) {
    return tweaksMetadata[name][ToggleKey] ?: [NSString stringWithFormat:@"YTVideoOverlay-%@-Enabled", name];
}

static BOOL TweakEnabled(NSString *name) {
    if (![[NSUserDefaults standardUserDefaults] objectForKey:EnabledKey(name)]) {
        // Nếu không có giá trị, đặt giá trị mặc định là YES
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:EnabledKey(name)];
    }
    return [[NSUserDefaults standardUserDefaults] boolForKey:EnabledKey(name)];
}

static NSString *PositionKey(NSString *name) {
    return [NSString stringWithFormat:@"YTVideoOverlay-%@-Position", name];
}

static int ButtonPosition(NSString *name) {
    return [[NSUserDefaults standardUserDefaults] integerForKey:PositionKey(name)];
}

static NSString *OrderKey(NSString *name) {
    return [NSString stringWithFormat:@"YTVideoOverlay-%@-Order", name];
}

static int ButtonOrder(NSString *name) {
    return [[NSUserDefaults standardUserDefaults] integerForKey:OrderKey(name)];
}

static BOOL UseTopButton(NSString *name) {
    return TweakEnabled(name) && ButtonPosition(name) == 0;
}

static BOOL UseBottomButton(NSString *name) {
    return TweakEnabled(name) && ButtonPosition(name) == 1;
}

static NSMutableArray *topControls(YTMainAppControlsOverlayView *self, NSMutableArray *controls) {
    for (NSString *name in topButtons) {
        if (UseTopButton(name))
            [controls insertObject:self.overlayButtons[name] atIndex:0];
    }
    return controls;
}

static void setDefaultTextStyle(YTQTMButton *button) {
    [button setTitleColor:[%c(YTColor) white1] forState:0];
    YTDefaultTypeStyle *defaultTypeStyle = [%c(YTTypeStyle) defaultTypeStyle];
    UIFont *font = [defaultTypeStyle respondsToSelector:@selector(ytSansFontOfSize:weight:)]
        ? [defaultTypeStyle ytSansFontOfSize:10 weight:UIFontWeightSemibold]
        : [defaultTypeStyle fontOfSize:10 weight:UIFontWeightSemibold];
    button.titleLabel.font = font;
    button.titleLabel.textAlignment = NSTextAlignmentCenter;
    CGRect frame = button.frame;
    frame.size.width = OVERLAY_BUTTON_SIZE;
    button.frame = frame;
}

static YTQTMButton *createButtonTop(BOOL isText, YTMainAppControlsOverlayView *self, NSString *buttonId, NSString *accessibilityLabel, SEL selector) {
    if (!self) return nil;
    CGFloat padding = [[self class] topButtonAdditionalPadding];
    YTQTMButton *button;
    if (isText) {
        button = [%c(YTQTMButton) textButton];
        button.accessibilityLabel = accessibilityLabel;
        button.verticalContentPadding = padding;
        setDefaultTextStyle(button);
    } else {
        UIImage *image = [self buttonImage:buttonId];
        button = [self buttonWithImage:image accessibilityLabel:accessibilityLabel verticalContentPadding:padding];
    }
    button.hidden = YES;
    button.alpha = 0;
    [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    if (![topButtons containsObject:buttonId])
        [topButtons addObject:buttonId];
    @try {
        [[self valueForKey:@"_topControlsAccessibilityContainerView"] addSubview:button];
    } @catch (id ex) {
        [self addSubview:button];
    }
    return button;
}

static YTQTMButton *createButtonBottom(BOOL isText, YTInlinePlayerBarContainerView *self, NSString *buttonId, NSString *accessibilityLabel, SEL selector) {
    if (!self) return nil;
    YTQTMButton *button;
    if (isText) {
        button = [%c(YTQTMButton) textButton];
        button.accessibilityLabel = accessibilityLabel;
        setDefaultTextStyle(button);
    } else {
        UIImage *image = [self buttonImage:buttonId];
        button = [%c(YTQTMButton) iconButton];
        [button setImage:image forState:0];
        [button sizeToFit];
    }
    button.hidden = YES;
    button.exclusiveTouch = YES;
    button.alpha = 0;
    button.minHitTargetSize = 60;
    button.accessibilityLabel = accessibilityLabel;
    [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    if (![bottomButtons containsObject:buttonId])
        [bottomButtons addObject:buttonId];
    [self addSubview:button];
    return button;
}

%group Top

%hook YTMainAppVideoPlayerOverlayViewController

- (void)updateTopRightButtonAvailability {
    %orig;
    YTMainAppVideoPlayerOverlayView *v = [self videoPlayerOverlayView];
    YTMainAppControlsOverlayView *c = [v valueForKey:@"_controlsOverlayView"];
    for (NSString *name in topButtons)
        c.overlayButtons[name].hidden = !UseTopButton(name);
    [c setNeedsLayout];
}

%end

static NSMutableDictionary <NSString *, YTQTMButton *> *createOverlayButtons(BOOL isTop, id self) {
    NSMutableDictionary <NSString *, YTQTMButton *> *overlayButtons = [NSMutableDictionary dictionary];
    for (NSString *name in [tweaksMetadata allKeys]) {
        NSDictionary *metadata = tweaksMetadata[name];
        SEL selector = NSSelectorFromString(metadata[SelectorKey]);
        BOOL asText = [metadata[AsTextKey] boolValue];
        NSString *accessibilityLabel = metadata[AccessibilityLabelKey];
        YTQTMButton *button;
        if (isTop)
            button = createButtonTop(asText, (YTMainAppControlsOverlayView *)self, name, accessibilityLabel, selector);
        else
            button = createButtonBottom(asText, (YTInlinePlayerBarContainerView *)self, name, accessibilityLabel, selector);
        overlayButtons[name] = button;
    }
    return overlayButtons;
}

static void sortButtons(NSMutableArray <NSString *> *buttons) {
    [buttons sortUsingComparator:^NSComparisonResult (NSString *a, NSString *b) {
        int orderA = ButtonOrder(a);
        int orderB = ButtonOrder(b);
        if (orderA == 0 && orderB == 0)
            return [a caseInsensitiveCompare:b];
        if (orderA == 0)
            return NSOrderedDescending;
        if (orderB == 0)
            return NSOrderedAscending;
        return orderA < orderB ? NSOrderedAscending : NSOrderedDescending;
    }];
}

%hook YTMainAppControlsOverlayView

%property (retain, nonatomic) NSMutableDictionary *overlayButtons;

- (id)initWithDelegate:(id)delegate {
    self = %orig;
    self.overlayButtons = createOverlayButtons(YES, self);
    sortButtons(topButtons);
    return self;
}

- (id)initWithDelegate:(id)delegate autoplaySwitchEnabled:(BOOL)autoplaySwitchEnabled {
    self = %orig;
    self.overlayButtons = createOverlayButtons(YES, self);
    sortButtons(topButtons);
    return self;
}

%new(@@:@)
- (UIImage *)buttonImage:(NSString *)tweakId {
    return nil;
}

- (NSMutableArray *)topButtonControls {
    return topControls(self, %orig);
}

- (NSMutableArray *)topControls {
    return topControls(self, %orig);
}

- (void)setTopOverlayVisible:(BOOL)visible isAutonavCanceledState:(BOOL)canceledState {
    CGFloat alpha = canceledState || !visible ? 0.0 : 1.0;
    for (NSString *name in topButtons)
        self.overlayButtons[name].alpha = UseTopButton(name) ? alpha : 0;
    %orig;
}

%end

%end

%group Bottom

%hook YTInlinePlayerBarContainerView

%property (retain, nonatomic) NSMutableDictionary *overlayButtons;

- (id)init {
    self = %orig;
    self.overlayButtons = createOverlayButtons(NO, self);
    sortButtons(bottomButtons);
    return self;
}

%new(@@:@)
- (UIImage *)buttonImage:(NSString *)tweakId {
    return nil;
}

- (NSMutableArray *)rightIcons {
    NSMutableArray *icons = %orig;
    for (NSString *name in bottomButtons) {
        if (UseBottomButton(name)) {
            YTQTMButton *button = self.overlayButtons[name];
            [icons insertObject:button atIndex:0];
        }
    }
    return icons;
}

- (void)updateIconVisibility {
    %orig;
    for (NSString *name in bottomButtons) {
        if (UseBottomButton(name)) {
            YTQTMButton *button = self.overlayButtons[name];
            button.hidden = NO;
            if (tweaksMetadata[name][UpdateImageOnVisibleKey])
                [button setImage:[self buttonImage:name] forState:0];
        }
    }
}

- (void)updateIconsHiddenAttribute {
    %orig;
    for (NSString *name in bottomButtons) {
        if (UseBottomButton(name)) {
            YTQTMButton *button = self.overlayButtons[name];
            button.hidden = NO;
            if (tweaksMetadata[name][UpdateImageOnVisibleKey])
                [button setImage:[self buttonImage:name] forState:0];
        }
    }
}

- (void)hideScrubber {
    %orig;
    for (NSString *name in bottomButtons) {
        if (UseBottomButton(name))
            self.overlayButtons[name].alpha = 0;
    }
}

- (void)setPeekableViewVisible:(BOOL)visible {
    %orig;
    for (NSString *name in bottomButtons) {
        if (UseBottomButton(name))
            self.overlayButtons[name].alpha = visible ? 1 : 0;
    }
}

- (void)setPeekableViewVisible:(BOOL)visible fullscreenButtonVisibleShouldMatchPeekableView:(BOOL)match {
    %orig;
    for (NSString *name in bottomButtons) {
        if (UseBottomButton(name))
            self.overlayButtons[name].alpha = visible ? 1 : 0;
    }
}

- (void)peekWithShowScrubber:(BOOL)scrubber setControlsAbovePlayerBarVisible:(BOOL)visible {
    %orig;
    for (NSString *name in bottomButtons) {
        if (UseBottomButton(name))
            self.overlayButtons[name].alpha = visible ? 1 : 0;
    }
}

- (void)layoutSubviews {
    %orig;
    CGFloat multiFeedWidth = [self respondsToSelector:@selector(multiFeedElementView)] ? [self multiFeedElementView].frame.size.width : 0;
    YTQTMButton *enter = [self enterFullscreenButton];
    CGFloat shift = 0;
    CGRect frame = CGRectZero;
    if ([enter yt_isVisible]) {
        frame = enter.frame;
        shift = multiFeedWidth + (2 * frame.size.width);
    } else {
        YTQTMButton *exit = [self exitFullscreenButton];
        if ([exit yt_isVisible]) {
            frame = exit.frame;
            shift = multiFeedWidth + (2 * frame.size.width);
        }
    }
    if (CGRectIsEmpty(frame) || frame.origin.x <= 0 || frame.origin.y < -4) return;
    frame.origin.x -= shift;
    for (NSString *name in bottomButtons) {
        if (UseBottomButton(name)) {
            self.overlayButtons[name].frame = frame;
            frame.origin.x -= (2 * frame.size.width);
            if (frame.origin.x < 0) frame.origin.x = 0;
        }
    }
}

%end

%end

%group Settings

%hook YTSettingsGroupData

- (NSArray <NSNumber *> *)orderedCategories {
    if (self.type != 1 || class_getClassMethod(objc_getClass("YTSettingsGroupData"), @selector(tweaks)))
        return %orig;
    NSMutableArray *mutableCategories = %orig.mutableCopy;
    [mutableCategories insertObject:@(YTVideoOverlaySection) atIndex:0];
    return mutableCategories.copy;
}

%end

%hook YTAppSettingsPresentationData

+ (NSArray <NSNumber *> *)settingsCategoryOrder {
    NSArray <NSNumber *> *order = %orig;
    NSUInteger insertIndex = [order indexOfObject:@(1)];
    if (insertIndex != NSNotFound) {
        NSMutableArray <NSNumber *> *mutableOrder = [order mutableCopy];
        [mutableOrder insertObject:@(YTVideoOverlaySection) atIndex:insertIndex + 1];
        order = mutableOrder.copy;
    }
    return order;
}

%end

%hook YTSettingsSectionItemManager

%new(v@:@@)
+ (void)registerTweak:(NSString *)tweakId metadata:(NSDictionary *)metadata {
    tweaksMetadata[tweakId] = metadata;
}

%new(v@:@)
- (void)updateYTVideoOverlaySectionWithEntry:(id)entry {
    NSMutableArray *sectionItems = [NSMutableArray array];
    NSBundle *tweakBundle = TweakBundle(@"YTVideoOverlay");
    Class YTSettingsSectionItemClass = %c(YTSettingsSectionItem);
    YTSettingsViewController *settingsViewController = [self valueForKey:@"_settingsViewControllerDelegate"];
    NSArray <NSString *> *sortedKeys = [[tweaksMetadata allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    for (NSString *name in sortedKeys) {
        NSBundle *bundle = TweakBundle(name);
        YTSettingsSectionItem *header = [YTSettingsSectionItemClass itemWithTitle:name
            accessibilityIdentifier:nil
            detailTextBlock:nil
            selectBlock:nil];
        header.enabled = NO;
        [sectionItems addObject:header];
        if (tweaksMetadata[name][ToggleKey] == nil) {
            YTSettingsSectionItem *master = [YTSettingsSectionItemClass switchItemWithTitle:_LOC(bundle, @"ENABLED")
                titleDescription:nil
                accessibilityIdentifier:nil
                switchOn:TweakEnabled(name)
                switchBlock:^BOOL (YTSettingsCell *cell, BOOL enabled) {
                    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:EnabledKey(name)];
                    return YES;
                }
                settingItemId:0];
            [sectionItems addObject:master];
        }
        NSString *topText = LOC(@"TOP");
        NSString *bottomText = LOC(@"BOTTOM");
        YTSettingsSectionItem *position = [YTSettingsSectionItemClass itemWithTitle:_LOC(bundle, @"POSITION")
            accessibilityIdentifier:nil
            detailTextBlock:^NSString *() {
                return ButtonPosition(name) ? bottomText : topText;
            }
            selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                NSArray <YTSettingsSectionItem *> *rows = @[
                    [YTSettingsSectionItemClass checkmarkItemWithTitle:topText titleDescription:LOC(@"TOP_DESC") selectBlock:^BOOL (YTSettingsCell *top, NSUInteger arg1) {
                        [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:PositionKey(name)];
                        [settingsViewController reloadData];
                        return YES;
                    }],
                    [YTSettingsSectionItemClass checkmarkItemWithTitle:bottomText titleDescription:LOC(@"BOTTOM_DESC") selectBlock:^BOOL (YTSettingsCell *bottom, NSUInteger arg1) {
                        [[NSUserDefaults standardUserDefaults] setInteger:1 forKey:PositionKey(name)];
                        [settingsViewController reloadData];
                        return YES;
                    }]
                ];
                YTSettingsPickerViewController *picker = [[%c(YTSettingsPickerViewController) alloc] initWithNavTitle:_LOC(bundle, @"POSITION") pickerSectionTitle:nil rows:rows selectedItemIndex:ButtonPosition(name) parentResponder:[self parentResponder]];
                [settingsViewController pushViewController:picker];
                return YES;
            }];
        [sectionItems addObject:position];
        int orderValue = ButtonOrder(name);
        NSString *orderText = LOC(@"ORDER");
        NSString *orderNoneText = LOC(@"ORDER_NONE");
        YTSettingsSectionItem *order = [YTSettingsSectionItemClass itemWithTitle:orderText
            accessibilityIdentifier:nil
            detailTextBlock:^NSString *() {
                return orderValue ? [NSString stringWithFormat:@"%d", orderValue] : orderNoneText;
            }
            selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                int count = tweaksMetadata.count;
                NSMutableArray <YTSettingsSectionItem *> *rows = [NSMutableArray arrayWithCapacity:count + 1];
                [rows addObject:[YTSettingsSectionItemClass checkmarkItemWithTitle:orderNoneText titleDescription:nil selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                    [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:OrderKey(name)];
                    [settingsViewController reloadData];
                    sortButtons(topButtons);
                    sortButtons(bottomButtons);
                    return YES;
                }]];
                for (int i = 0; i < count; ++i) {
                    [rows addObject:[YTSettingsSectionItemClass checkmarkItemWithTitle:[NSString stringWithFormat:@"%d", i + 1] titleDescription:nil selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                        [[NSUserDefaults standardUserDefaults] setInteger:i + 1 forKey:OrderKey(name)];
                        [settingsViewController reloadData];
                        sortButtons(topButtons);
                        sortButtons(bottomButtons);
                        return YES;
                    }]];
                }
                int selectedItemIndex = orderValue;
                if (selectedItemIndex >= count) selectedItemIndex = 0;
                NSString *pickerTitle = [NSString stringWithFormat:@"%@ - %@", orderText, name];
                YTSettingsPickerViewController *picker = [[%c(YTSettingsPickerViewController) alloc] initWithNavTitle:pickerTitle pickerSectionTitle:nil rows:rows selectedItemIndex:selectedItemIndex parentResponder:[self parentResponder]];
                [settingsViewController pushViewController:picker];
                return YES;
            }];
        [sectionItems addObject:order];
    }
    NSString *title = LOC(@"VIDEO_OVERLAY");
    if ([settingsViewController respondsToSelector:@selector(setSectionItems:forCategory:title:icon:titleDescription:headerHidden:)]) {
        YTIIcon *icon = [%c(YTIIcon) new];
        icon.iconType = YT_TV;
        [settingsViewController setSectionItems:sectionItems forCategory:YTVideoOverlaySection title:title icon:icon titleDescription:nil headerHidden:NO];
    } else
        [settingsViewController setSectionItems:sectionItems forCategory:YTVideoOverlaySection title:title titleDescription:nil headerHidden:NO];
}

- (void)updateSectionForCategory:(NSUInteger)category withEntry:(id)entry {
    if (category == YTVideoOverlaySection) {
        [self updateYTVideoOverlaySectionWithEntry:entry];
        return;
    }
    %orig;
}

%end

%end

%ctor {
    tweaksMetadata = [NSMutableDictionary dictionary];
    topButtons = [NSMutableArray array];
    bottomButtons = [NSMutableArray array];
    %init(Settings);
    %init(Top);
    %init(Bottom);
}

%dtor {
    [tweaksMetadata removeAllObjects];
    [topButtons removeAllObjects];
    [bottomButtons removeAllObjects];
}
