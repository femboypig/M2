//
//  ViewController.m
//  M2
//
//  Created by loser on 22.02.2026.
//

#import "ViewController.h"

#import <math.h>
#import <TargetConditionals.h>
#if TARGET_OS_MACCATALYST
#import <AppKit/AppKit.h>
#endif

#import "M2MusicModule.h"
#import "M2Services.h"

static BOOL M2IsMacCatalyst(void) {
#if TARGET_OS_MACCATALYST
    return YES;
#else
    return NO;
#endif
}

static UIColor *M2AccentYellowColor(void) {
    return [UIColor colorWithRed:1.0 green:0.83 blue:0.08 alpha:1.0];
}

static UIColor *M2TabActiveIconColor(void) {
    return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull trait) {
        if (trait.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return UIColor.whiteColor;
        }
        return [UIColor colorWithWhite:0.08 alpha:1.0];
    }];
}

static UIColor *M2TabInactiveIconColor(void) {
    return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull trait) {
        if (trait.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithWhite:1.0 alpha:0.36];
        }
        return [UIColor colorWithWhite:0.0 alpha:0.34];
    }];
}

static UIColor *M2TabBarBackgroundColor(void) {
    return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull trait) {
        if (trait.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithWhite:0.02 alpha:1.0];
        }
        return [UIColor colorWithWhite:0.985 alpha:1.0];
    }];
}

static UIColor *M2MiniPlayerBackgroundColor(void) {
    return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull trait) {
        if (trait.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithWhite:0.0 alpha:0.30];
        }
        return [UIColor colorWithWhite:1.0 alpha:0.32];
    }];
}

static UIColor *M2MiniPlayerBorderColor(void) {
    return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull trait) {
        if (trait.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithWhite:1.0 alpha:0.14];
        }
        return [UIColor colorWithWhite:0.0 alpha:0.10];
    }];
}

static CGFloat M2MiniPlayerHeight(void) {
    return M2IsMacCatalyst() ? 68.0 : 62.0;
}

static CGFloat M2MiniPlayerHorizontalInset(void) {
    return M2IsMacCatalyst() ? 6.0 : 8.0;
}

static CGFloat M2MiniPlayerBottomSpacing(void) {
    return M2IsMacCatalyst() ? 10.0 : 6.0;
}

static CGFloat M2DesktopSidebarWidth(void) {
    return 220.0;
}

static CGFloat M2DesktopContentLeftInset(void) {
    return M2DesktopSidebarWidth();
}

static CGFloat M2DesktopContentTopInset(void) {
    return 10.0;
}

static CGFloat M2DesktopContentRightInset(void) {
    return 10.0;
}

static UIColor *M2DesktopShellBackgroundColor(void) {
    return UIColor.blackColor;
}

static UIColor *M2DesktopSidebarBackgroundColor(void) {
    return UIColor.blackColor;
}

static UIColor *M2DesktopSidebarSecondaryTextColor(void) {
    return [UIColor colorWithWhite:1.0 alpha:0.72];
}

static UIColor *M2DesktopSidebarButtonColor(BOOL selected) {
    (void)selected;
    return [UIColor colorWithWhite:0.0 alpha:0.0];
}

static CGFloat M2DesktopSidebarButtonTitleFontSize(void) {
    return 14.0;
}

static CGFloat M2DesktopSidebarButtonSymbolPointSize(void) {
    return 25.0;
}

static CGFloat M2DesktopSidebarButtonIconColumnWidth(void) {
    return 36.0;
}

static CGFloat M2DesktopSidebarSymbolVerticalOffset(NSString *symbolName) {
    if ([symbolName isEqualToString:@"heart.fill"]) {
        return 0.8;
    }
    if ([symbolName isEqualToString:@"rectangle.stack.fill"]) {
        return 0.4;
    }
    if ([symbolName isEqualToString:@"music.note.list"]) {
        return -0.2;
    }
    return 0.0;
}

static UIImage *M2DesktopSidebarSymbolImage(NSString *symbolName, UIColor *color) {
    if (symbolName.length == 0) {
        return nil;
    }

    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:M2DesktopSidebarButtonSymbolPointSize()
                                                                                           weight:UIImageSymbolWeightSemibold];
    UIImage *symbol = [UIImage systemImageNamed:symbolName withConfiguration:config];
    if (symbol == nil) {
        return nil;
    }

    CGFloat targetWidth = M2DesktopSidebarButtonIconColumnWidth();
    CGFloat targetHeight = M2DesktopSidebarButtonSymbolPointSize() + 3.0;
    CGSize canvasSize = CGSizeMake(MAX(targetWidth, symbol.size.width),
                                   MAX(targetHeight, symbol.size.height));
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
    format.opaque = NO;
    format.scale = symbol.scale > 0.0 ? symbol.scale : UIScreen.mainScreen.scale;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:canvasSize
                                                                                format:format];
    UIImage *paddedSymbol = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull context) {
        (void)context;
        CGFloat originX = floor((canvasSize.width - symbol.size.width) * 0.5);
        CGFloat originY = floor((canvasSize.height - symbol.size.height) * 0.5 + M2DesktopSidebarSymbolVerticalOffset(symbolName));
        [symbol drawInRect:CGRectMake(originX, originY, symbol.size.width, symbol.size.height)];
    }];

    UIColor *resolvedColor = color ?: UIColor.whiteColor;
    return [paddedSymbol imageWithTintColor:resolvedColor
                               renderingMode:UIImageRenderingModeAlwaysOriginal];
}

static UIImage *M2DesktopSidebarLogoImage(void) {
    UIImage *logo = [UIImage imageNamed:@"SidebarLogoSVG"];
    if (logo == nil) {
        logo = [UIImage imageNamed:@"launch-icon-any"];
    }
    if (logo == nil) {
        logo = [UIImage imageNamed:@"LaunchIcon"];
    }
    if (logo == nil) {
        logo = [UIImage systemImageNamed:@"music.note"];
    }
    return [logo imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
}

static UIKeyCommand *M2KeyCommand(NSString *input,
                                  UIKeyModifierFlags modifierFlags,
                                  SEL action,
                                  NSString *discoverabilityTitle) {
    UIKeyCommand *command = [UIKeyCommand keyCommandWithInput:input
                                                modifierFlags:modifierFlags
                                                       action:action];
    command.discoverabilityTitle = discoverabilityTitle;
    return command;
}

@interface ViewController () <UITabBarControllerDelegate, UINavigationControllerDelegate>

@property (nonatomic, strong) UIView *miniPlayerContainer;
@property (nonatomic, strong) UIVisualEffectView *miniPlayerBlurView;
@property (nonatomic, strong) UIImageView *miniPlayerArtworkView;
@property (nonatomic, strong) UILabel *miniPlayerTitleLabel;
@property (nonatomic, strong) UILabel *miniPlayerSubtitleLabel;
@property (nonatomic, strong) UIButton *miniPlayerOpenButton;
@property (nonatomic, strong) UIButton *miniPlayerPreviousButton;
@property (nonatomic, strong) UIButton *miniPlayerPlayPauseButton;
@property (nonatomic, strong) UIButton *miniPlayerNextButton;
@property (nonatomic, strong) NSLayoutConstraint *miniPlayerBottomConstraint;
@property (nonatomic, strong) NSLayoutConstraint *miniPlayerLeadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *miniPlayerTrailingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *miniPlayerTitleTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *miniPlayerTitleCenterYConstraint;
@property (nonatomic, assign) BOOL miniPlayerTransitionAnimating;
@property (nonatomic, strong) UIView *desktopSidebarView;
@property (nonatomic, strong) UIButton *desktopMusicButton;
@property (nonatomic, strong) UIButton *desktopPlaylistsButton;
@property (nonatomic, strong) UIButton *desktopFavoritesButton;
@property (nonatomic, strong) NSHashTable<UIButton *> *desktopHoveredButtons;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.delegate = self;
    [self setupTabs];
    self.desktopHoveredButtons = [NSHashTable weakObjectsHashTable];
    [self setupAppearance];
    if (M2IsMacCatalyst()) {
        self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
        self.tabBar.hidden = YES;
        [self applyDesktopTabBarHiddenState];
    }
    [self setupMiniPlayer];
    [self setupDesktopSidebarIfNeeded];
    [self updateDesktopSidebarSelection];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(handlePlaybackStateChanged)
                                               name:M2PlaybackStateDidChangeNotification
                                             object:nil];

    [self updateMiniPlayer];
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self applyDesktopTabBarHiddenState];
    [self updateDesktopContentLayoutIfNeeded];
    [self updateMiniPlayerPosition];
    [self updateMiniPlayer];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self becomeFirstResponder];
}

- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (NSArray<UIKeyCommand *> *)keyCommands {
    UIKeyModifierFlags command = UIKeyModifierCommand;
    UIKeyModifierFlags media = (UIKeyModifierCommand | UIKeyModifierAlternate);
    return @[
        M2KeyCommand(@"1", command, @selector(selectMusicTabKeyCommand), @"Go to Music"),
        M2KeyCommand(@"2", command, @selector(selectPlaylistsTabKeyCommand), @"Go to Playlists"),
        M2KeyCommand(@"3", command, @selector(selectFavoritesTabKeyCommand), @"Go to Favorites"),
        M2KeyCommand(@"f", command, @selector(findKeyCommand), @"Search"),
        M2KeyCommand(@" ", media, @selector(togglePlayPauseKeyCommand), @"Play or Pause"),
        M2KeyCommand(UIKeyInputRightArrow, media, @selector(playNextKeyCommand), @"Next Track"),
        M2KeyCommand(UIKeyInputLeftArrow, media, @selector(playPreviousKeyCommand), @"Previous Track"),
        M2KeyCommand(@"p", (UIKeyModifierCommand | UIKeyModifierShift), @selector(openPlayerKeyCommand), @"Open Player")
    ];
}

- (void)setupTabs {
    BOOL desktop = M2IsMacCatalyst();

    M2MusicViewController *musicVC = [[M2MusicViewController alloc] init];
    UINavigationController *musicNav = [[UINavigationController alloc] initWithRootViewController:musicVC];
    musicNav.delegate = self;
    musicNav.navigationBar.prefersLargeTitles = NO;
    UIImage *musicIcon = [self tabIconNamed:@"tab_note"];
    musicNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:(desktop ? @"Music" : nil)
                                                         image:musicIcon
                                                 selectedImage:musicIcon];
    if (!desktop) {
        musicNav.tabBarItem.imageInsets = UIEdgeInsetsMake(2.0, 0.0, -2.0, 0.0);
    }

    M2PlaylistsViewController *playlistsVC = [[M2PlaylistsViewController alloc] init];
    UINavigationController *playlistsNav = [[UINavigationController alloc] initWithRootViewController:playlistsVC];
    playlistsNav.delegate = self;
    playlistsNav.navigationBar.prefersLargeTitles = NO;
    UIImage *playlistIcon = [self tabIconNamed:@"tab_lib"];
    playlistsNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:(desktop ? @"Playlists" : nil)
                                                             image:playlistIcon
                                                     selectedImage:playlistIcon];
    if (!desktop) {
        playlistsNav.tabBarItem.imageInsets = UIEdgeInsetsMake(2.0, 0.0, -2.0, 0.0);
    }

    M2FavoritesViewController *favoritesVC = [[M2FavoritesViewController alloc] init];
    UINavigationController *favoritesNav = [[UINavigationController alloc] initWithRootViewController:favoritesVC];
    favoritesNav.delegate = self;
    favoritesNav.navigationBar.prefersLargeTitles = NO;
    UIImage *favoritesIcon = [self tabSymbolIconNamed:@"heart.fill" pointSize:18.0];
    favoritesNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:(desktop ? @"Favorites" : nil)
                                                             image:favoritesIcon
                                                     selectedImage:favoritesIcon];
    if (!desktop) {
        favoritesNav.tabBarItem.imageInsets = UIEdgeInsetsMake(2.0, 0.0, -2.0, 0.0);
    }

    self.viewControllers = @[musicNav, playlistsNav, favoritesNav];
}

- (void)setupAppearance {
    BOOL desktop = M2IsMacCatalyst();

    UITabBarAppearance *tabAppearance = [[UITabBarAppearance alloc] init];
    [tabAppearance configureWithOpaqueBackground];
    tabAppearance.backgroundEffect = nil;
    tabAppearance.backgroundColor = M2TabBarBackgroundColor();
    tabAppearance.shadowColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull trait) {
        if (trait.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithWhite:1.0 alpha:0.07];
        }
        return [UIColor colorWithWhite:0.0 alpha:0.08];
    }];

    UIColor *inactiveColor = M2TabInactiveIconColor();
    UIColor *activeColor = M2TabActiveIconColor();

    void (^configureTabItemAppearance)(UITabBarItemAppearance *) = ^(UITabBarItemAppearance *appearance) {
        appearance.normal.iconColor = inactiveColor;
        appearance.selected.iconColor = activeColor;
        if (desktop) {
            appearance.normal.titleTextAttributes = @{
                NSForegroundColorAttributeName: inactiveColor,
                NSFontAttributeName: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold]
            };
            appearance.selected.titleTextAttributes = @{
                NSForegroundColorAttributeName: activeColor,
                NSFontAttributeName: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold]
            };
            appearance.normal.titlePositionAdjustment = UIOffsetZero;
            appearance.selected.titlePositionAdjustment = UIOffsetZero;
        } else {
            appearance.normal.titleTextAttributes = @{NSForegroundColorAttributeName: UIColor.clearColor};
            appearance.selected.titleTextAttributes = @{NSForegroundColorAttributeName: UIColor.clearColor};
            appearance.normal.titlePositionAdjustment = UIOffsetMake(0.0, 14.0);
            appearance.selected.titlePositionAdjustment = UIOffsetMake(0.0, 14.0);
        }
    };

    configureTabItemAppearance(tabAppearance.stackedLayoutAppearance);
    configureTabItemAppearance(tabAppearance.inlineLayoutAppearance);
    configureTabItemAppearance(tabAppearance.compactInlineLayoutAppearance);

    self.tabBar.standardAppearance = tabAppearance;
    if (@available(iOS 15.0, *)) {
        self.tabBar.scrollEdgeAppearance = tabAppearance;
    }
    self.tabBar.itemPositioning = desktop ? UITabBarItemPositioningAutomatic : UITabBarItemPositioningCentered;
    self.tabBar.tintColor = activeColor;
    self.tabBar.unselectedItemTintColor = inactiveColor;

    UINavigationBarAppearance *navAppearance = [[UINavigationBarAppearance alloc] init];
    [navAppearance configureWithDefaultBackground];
    if (desktop) {
        navAppearance.backgroundColor = M2DesktopShellBackgroundColor();
        navAppearance.shadowColor = [UIColor colorWithWhite:1.0 alpha:0.08];
    } else {
        navAppearance.backgroundColor = UIColor.systemBackgroundColor;
    }
    navAppearance.titleTextAttributes = @{
        NSForegroundColorAttributeName: (desktop ? UIColor.whiteColor : UIColor.labelColor),
        NSFontAttributeName: [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold]
    };
    navAppearance.largeTitleTextAttributes = @{
        NSForegroundColorAttributeName: (desktop ? UIColor.whiteColor : UIColor.labelColor),
        NSFontAttributeName: [UIFont systemFontOfSize:30.0 weight:UIFontWeightBold]
    };

    UIBarButtonItemAppearance *barButtonAppearance = [[UIBarButtonItemAppearance alloc] init];
    barButtonAppearance.normal.titleTextAttributes = @{
        NSForegroundColorAttributeName: (desktop ? UIColor.whiteColor : UIColor.labelColor)
    };
    barButtonAppearance.highlighted.titleTextAttributes = @{
        NSForegroundColorAttributeName: (desktop ? M2DesktopSidebarSecondaryTextColor() : UIColor.secondaryLabelColor)
    };
    navAppearance.buttonAppearance = barButtonAppearance;
    navAppearance.doneButtonAppearance = barButtonAppearance;
    navAppearance.backButtonAppearance = barButtonAppearance;

    UINavigationBar.appearance.standardAppearance = navAppearance;
    UINavigationBar.appearance.compactAppearance = navAppearance;
    if (@available(iOS 15.0, *)) {
        UINavigationBar.appearance.scrollEdgeAppearance = navAppearance;
    }
    UINavigationBar.appearance.tintColor = desktop ? UIColor.whiteColor : UIColor.labelColor;

    self.view.backgroundColor = desktop ? M2DesktopShellBackgroundColor() : UIColor.systemBackgroundColor;
    self.view.tintColor = M2AccentYellowColor();
}

- (void)setupMiniPlayer {
    CGFloat horizontalInset = M2MiniPlayerHorizontalInset();
    CGFloat containerHeight = M2MiniPlayerHeight();
    CGFloat artworkSize = M2IsMacCatalyst() ? 42.0 : 40.0;
    CGFloat artworkLeadingInset = M2IsMacCatalyst() ? 14.0 : 10.0;
    CGFloat controlsTrailingInset = M2IsMacCatalyst() ? 14.0 : 10.0;

    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.backgroundColor = M2MiniPlayerBackgroundColor();
    container.layer.borderWidth = 1.0;
    container.layer.borderColor = M2MiniPlayerBorderColor().CGColor;
    container.layer.cornerRadius = M2IsMacCatalyst() ? 18.0 : 16.0;
    container.layer.masksToBounds = YES;
    container.hidden = YES;
    self.miniPlayerContainer = container;

    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    blurView.translatesAutoresizingMaskIntoConstraints = NO;
    blurView.userInteractionEnabled = NO;
    blurView.alpha = M2IsMacCatalyst() ? 0.0 : 0.90;
    if (M2IsMacCatalyst()) {
        blurView.effect = nil;
    }
    self.miniPlayerBlurView = blurView;

    UIImageView *artworkView = [[UIImageView alloc] init];
    artworkView.translatesAutoresizingMaskIntoConstraints = NO;
    artworkView.contentMode = UIViewContentModeScaleAspectFill;
    artworkView.layer.cornerRadius = 8.0;
    artworkView.layer.masksToBounds = YES;
    artworkView.userInteractionEnabled = NO;
    self.miniPlayerArtworkView = artworkView;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [UIFont systemFontOfSize:(M2IsMacCatalyst() ? 14.0 : 13.5) weight:UIFontWeightSemibold];
    titleLabel.textColor = UIColor.labelColor;
    titleLabel.numberOfLines = 1;
    titleLabel.userInteractionEnabled = NO;
    self.miniPlayerTitleLabel = titleLabel;

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [UIFont systemFontOfSize:(M2IsMacCatalyst() ? 12.5 : 12.0) weight:UIFontWeightMedium];
    subtitleLabel.textColor = UIColor.secondaryLabelColor;
    subtitleLabel.numberOfLines = 1;
    subtitleLabel.userInteractionEnabled = NO;
    self.miniPlayerSubtitleLabel = subtitleLabel;

    UIButton *previousButton = [UIButton buttonWithType:UIButtonTypeSystem];
    previousButton.translatesAutoresizingMaskIntoConstraints = NO;
    previousButton.tintColor = UIColor.labelColor;
    UIImageSymbolConfiguration *previousConfig = [UIImageSymbolConfiguration configurationWithPointSize:15.0
                                                                                                 weight:UIImageSymbolWeightSemibold];
    [previousButton setImage:[UIImage systemImageNamed:@"backward.fill" withConfiguration:previousConfig]
                    forState:UIControlStateNormal];
    [previousButton addTarget:self action:@selector(miniPlayerPreviousTapped) forControlEvents:UIControlEventTouchUpInside];
    self.miniPlayerPreviousButton = previousButton;

    UIButton *playPauseButton = [UIButton buttonWithType:UIButtonTypeSystem];
    playPauseButton.translatesAutoresizingMaskIntoConstraints = NO;
    playPauseButton.tintColor = UIColor.labelColor;
    [playPauseButton addTarget:self action:@selector(miniPlayerPlayPauseTapped) forControlEvents:UIControlEventTouchUpInside];
    self.miniPlayerPlayPauseButton = playPauseButton;

    UIButton *nextButton = [UIButton buttonWithType:UIButtonTypeSystem];
    nextButton.translatesAutoresizingMaskIntoConstraints = NO;
    nextButton.tintColor = UIColor.labelColor;
    UIImageSymbolConfiguration *nextConfig = [UIImageSymbolConfiguration configurationWithPointSize:15.0
                                                                                             weight:UIImageSymbolWeightSemibold];
    [nextButton setImage:[UIImage systemImageNamed:@"forward.fill" withConfiguration:nextConfig]
                forState:UIControlStateNormal];
    [nextButton addTarget:self action:@selector(miniPlayerNextTapped) forControlEvents:UIControlEventTouchUpInside];
    self.miniPlayerNextButton = nextButton;

    UIButton *openButton = [UIButton buttonWithType:UIButtonTypeCustom];
    openButton.translatesAutoresizingMaskIntoConstraints = NO;
    [openButton addTarget:self action:@selector(miniPlayerOpenTapped) forControlEvents:UIControlEventTouchUpInside];
    self.miniPlayerOpenButton = openButton;

    UIPanGestureRecognizer *horizontalPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleMiniPlayerHorizontalPan:)];
    horizontalPan.cancelsTouchesInView = NO;
    [container addGestureRecognizer:horizontalPan];

    [self.view addSubview:container];
    [container addSubview:blurView];
    [container addSubview:openButton];
    [container addSubview:artworkView];
    [container addSubview:titleLabel];
    [container addSubview:subtitleLabel];
    [container addSubview:previousButton];
    [container addSubview:playPauseButton];
    [container addSubview:nextButton];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    NSLayoutConstraint *bottomConstraint = [container.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:0.0];
    NSLayoutConstraint *leadingConstraint = [container.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor
                                                                                     constant:horizontalInset];
    NSLayoutConstraint *trailingConstraint = [container.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor
                                                                                       constant:-horizontalInset];
    self.miniPlayerBottomConstraint = bottomConstraint;
    self.miniPlayerLeadingConstraint = leadingConstraint;
    self.miniPlayerTrailingConstraint = trailingConstraint;
    NSLayoutConstraint *titleTopConstraint = [titleLabel.topAnchor constraintEqualToAnchor:container.topAnchor constant:14.0];
    NSLayoutConstraint *titleCenterYConstraint = [titleLabel.centerYAnchor constraintEqualToAnchor:container.centerYAnchor];
    titleCenterYConstraint.active = NO;
    self.miniPlayerTitleTopConstraint = titleTopConstraint;
    self.miniPlayerTitleCenterYConstraint = titleCenterYConstraint;
    [NSLayoutConstraint activateConstraints:@[
        leadingConstraint,
        trailingConstraint,
        bottomConstraint,
        [container.heightAnchor constraintEqualToConstant:containerHeight],

        [blurView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [blurView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [blurView.topAnchor constraintEqualToAnchor:container.topAnchor],
        [blurView.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],

        [artworkView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:artworkLeadingInset],
        [artworkView.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
        [artworkView.widthAnchor constraintEqualToConstant:artworkSize],
        [artworkView.heightAnchor constraintEqualToConstant:artworkSize],

        [nextButton.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-controlsTrailingInset],
        [nextButton.centerYAnchor constraintEqualToAnchor:artworkView.centerYAnchor],
        [nextButton.widthAnchor constraintEqualToConstant:28.0],
        [nextButton.heightAnchor constraintEqualToConstant:28.0],

        [playPauseButton.trailingAnchor constraintEqualToAnchor:nextButton.leadingAnchor constant:-1.0],
        [playPauseButton.centerYAnchor constraintEqualToAnchor:artworkView.centerYAnchor],
        [playPauseButton.widthAnchor constraintEqualToConstant:34.0],
        [playPauseButton.heightAnchor constraintEqualToConstant:34.0],

        [previousButton.trailingAnchor constraintEqualToAnchor:playPauseButton.leadingAnchor constant:-1.0],
        [previousButton.centerYAnchor constraintEqualToAnchor:artworkView.centerYAnchor],
        [previousButton.widthAnchor constraintEqualToConstant:28.0],
        [previousButton.heightAnchor constraintEqualToConstant:28.0],

        [titleLabel.leadingAnchor constraintEqualToAnchor:artworkView.trailingAnchor constant:10.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:previousButton.leadingAnchor constant:-8.0],
        titleTopConstraint,
        titleCenterYConstraint,

        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:1.5],

        [openButton.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [openButton.topAnchor constraintEqualToAnchor:container.topAnchor],
        [openButton.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
        [openButton.trailingAnchor constraintEqualToAnchor:previousButton.leadingAnchor constant:-4.0],
    ]];

    [self.view bringSubviewToFront:container];
    [self updateMiniPlayerPosition];
}

- (UIButton *)desktopSidebarButtonWithTitle:(NSString *)title
                                     symbol:(NSString *)symbolName
                                     action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    button.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    button.layer.cornerRadius = 12.0;
    button.layer.masksToBounds = YES;
    button.tintColor = M2DesktopSidebarSecondaryTextColor();

    UIButtonConfiguration *configuration = [UIButtonConfiguration plainButtonConfiguration];
    configuration.contentInsets = NSDirectionalEdgeInsetsMake(0.0, 32.0, 0.0, 12.0);
    configuration.imagePadding = 24.0;
    configuration.imagePlacement = NSDirectionalRectEdgeLeading;
    configuration.titleAlignment = UIButtonConfigurationTitleAlignmentLeading;
    configuration.titleLineBreakMode = NSLineBreakByTruncatingTail;
    button.configuration = configuration;
    [self applySidebarTitle:title
                   toButton:button
                      color:M2DesktopSidebarSecondaryTextColor()];
    [self applySidebarSymbol:symbolName
                    toButton:button
                       color:M2DesktopSidebarSecondaryTextColor()];

    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    if (M2IsMacCatalyst()) {
        UIHoverGestureRecognizer *hoverGesture = [[UIHoverGestureRecognizer alloc] initWithTarget:self
                                                                                            action:@selector(handleDesktopSidebarButtonHover:)];
        [button addGestureRecognizer:hoverGesture];
    }
    return button;
}

- (void)applySidebarTitle:(NSString *)title toButton:(UIButton *)button color:(UIColor *)color {
    if (button == nil) {
        return;
    }

    UIButtonConfiguration *configuration = button.configuration ?: [UIButtonConfiguration plainButtonConfiguration];
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.alignment = NSTextAlignmentLeft;
    paragraphStyle.lineBreakMode = NSLineBreakByTruncatingTail;
    NSDictionary<NSAttributedStringKey, id> *attributes = @{
        NSFontAttributeName: [UIFont systemFontOfSize:M2DesktopSidebarButtonTitleFontSize() weight:UIFontWeightSemibold],
        NSForegroundColorAttributeName: color ?: UIColor.whiteColor,
        NSParagraphStyleAttributeName: paragraphStyle
    };
    configuration.attributedTitle = [[NSAttributedString alloc] initWithString:(title ?: @"")
                                                                     attributes:attributes];
    button.configuration = configuration;
}

- (UIView *)desktopSidebarBrandingView {
    UIImageView *brandView = [[UIImageView alloc] initWithImage:M2DesktopSidebarLogoImage()];
    brandView.translatesAutoresizingMaskIntoConstraints = NO;
    brandView.contentMode = UIViewContentModeScaleAspectFit;
    brandView.clipsToBounds = YES;
    return brandView;
}

- (void)setupDesktopSidebarIfNeeded {
    if (!M2IsMacCatalyst() || self.desktopSidebarView != nil) {
        return;
    }

    UIView *sidebar = [[UIView alloc] init];
    sidebar.translatesAutoresizingMaskIntoConstraints = NO;
    sidebar.backgroundColor = M2DesktopSidebarBackgroundColor();
    self.desktopSidebarView = sidebar;

    UIView *brandView = [self desktopSidebarBrandingView];
    CGFloat logoAspectRatio = 2.8;
    if ([brandView isKindOfClass:UIImageView.class]) {
        UIImage *logoImage = ((UIImageView *)brandView).image;
        if (logoImage != nil && logoImage.size.width > 1.0 && logoImage.size.height > 1.0) {
            logoAspectRatio = logoImage.size.width / logoImage.size.height;
        }
    }

    UIButton *musicButton = [self desktopSidebarButtonWithTitle:@"Music"
                                                         symbol:@"music.note.list"
                                                         action:@selector(selectMusicTabKeyCommand)];
    UIButton *playlistsButton = [self desktopSidebarButtonWithTitle:@"Playlists"
                                                             symbol:@"rectangle.stack.fill"
                                                             action:@selector(selectPlaylistsTabKeyCommand)];
    UIButton *favoritesButton = [self desktopSidebarButtonWithTitle:@"Favorites"
                                                             symbol:@"heart.fill"
                                                             action:@selector(selectFavoritesTabKeyCommand)];
    self.desktopMusicButton = musicButton;
    self.desktopPlaylistsButton = playlistsButton;
    self.desktopFavoritesButton = favoritesButton;

    UIStackView *buttonsStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        musicButton, playlistsButton, favoritesButton
    ]];
    buttonsStack.translatesAutoresizingMaskIntoConstraints = NO;
    buttonsStack.axis = UILayoutConstraintAxisVertical;
    buttonsStack.spacing = 8.0;
    buttonsStack.alignment = UIStackViewAlignmentFill;
    buttonsStack.distribution = UIStackViewDistributionFillEqually;
    [NSLayoutConstraint activateConstraints:@[
        [musicButton.heightAnchor constraintEqualToConstant:48.0],
        [playlistsButton.heightAnchor constraintEqualToConstant:48.0],
        [favoritesButton.heightAnchor constraintEqualToConstant:48.0]
    ]];

    UILabel *hintLabel = [[UILabel alloc] init];
    hintLabel.translatesAutoresizingMaskIntoConstraints = NO;
    hintLabel.text = @"Cmd+1  Cmd+2  Cmd+3";
    hintLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.50];
    hintLabel.font = [UIFont monospacedSystemFontOfSize:11.0 weight:UIFontWeightMedium];

    UIView *spacer = [[UIView alloc] init];
    spacer.translatesAutoresizingMaskIntoConstraints = NO;

    [sidebar addSubview:brandView];
    [sidebar addSubview:buttonsStack];
    [sidebar addSubview:spacer];
    [sidebar addSubview:hintLabel];
    [self.view addSubview:sidebar];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    NSLayoutConstraint *brandAspectConstraint = [brandView.widthAnchor constraintEqualToAnchor:brandView.heightAnchor
                                                                                      multiplier:logoAspectRatio];
    brandAspectConstraint.priority = UILayoutPriorityDefaultHigh;
    [NSLayoutConstraint activateConstraints:@[
        [sidebar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [sidebar.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [sidebar.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [sidebar.widthAnchor constraintEqualToConstant:M2DesktopSidebarWidth()],

        [brandView.centerXAnchor constraintEqualToAnchor:sidebar.centerXAnchor],
        [brandView.topAnchor constraintEqualToAnchor:safe.topAnchor constant:14.0],
        [brandView.heightAnchor constraintEqualToConstant:56.0],
        [brandView.widthAnchor constraintLessThanOrEqualToAnchor:sidebar.widthAnchor constant:-24.0],
        brandAspectConstraint,

        [buttonsStack.topAnchor constraintEqualToAnchor:brandView.bottomAnchor constant:14.0],
        [buttonsStack.leadingAnchor constraintEqualToAnchor:sidebar.leadingAnchor constant:24.0],
        [buttonsStack.trailingAnchor constraintEqualToAnchor:sidebar.trailingAnchor constant:-12.0],
        [buttonsStack.heightAnchor constraintEqualToConstant:142.0],

        [spacer.topAnchor constraintEqualToAnchor:buttonsStack.bottomAnchor constant:10.0],
        [spacer.leadingAnchor constraintEqualToAnchor:sidebar.leadingAnchor],
        [spacer.trailingAnchor constraintEqualToAnchor:sidebar.trailingAnchor],
        [spacer.bottomAnchor constraintEqualToAnchor:hintLabel.topAnchor constant:-10.0],

        [hintLabel.leadingAnchor constraintEqualToAnchor:sidebar.leadingAnchor constant:16.0],
        [hintLabel.trailingAnchor constraintEqualToAnchor:sidebar.trailingAnchor constant:-16.0],
        [hintLabel.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-14.0]
    ]];

    [self.view bringSubviewToFront:sidebar];
    [self.view bringSubviewToFront:self.miniPlayerContainer];
}

- (void)applySidebarSymbol:(NSString *)symbolName toButton:(UIButton *)button color:(UIColor *)color {
    if (button == nil || symbolName.length == 0) {
        return;
    }

    UIButtonConfiguration *configuration = button.configuration ?: [UIButtonConfiguration plainButtonConfiguration];
    configuration.image = M2DesktopSidebarSymbolImage(symbolName, color);
    button.configuration = configuration;
}

- (void)updateDesktopSidebarSelection {
    if (!M2IsMacCatalyst()) {
        return;
    }

    NSArray<UIButton *> *buttons = @[self.desktopMusicButton ?: UIButton.new,
                                     self.desktopPlaylistsButton ?: UIButton.new,
                                     self.desktopFavoritesButton ?: UIButton.new];
    NSArray<NSString *> *symbols = @[@"music.note.list", @"rectangle.stack.fill", @"heart.fill"];
    NSArray<NSString *> *titles = @[@"Music", @"Playlists", @"Favorites"];
    for (NSUInteger index = 0; index < buttons.count; index += 1) {
        UIButton *button = buttons[index];
        BOOL selected = (self.selectedIndex == (NSInteger)index);
        BOOL hovered = [self.desktopHoveredButtons containsObject:button];
        button.backgroundColor = M2DesktopSidebarButtonColor(selected);
        button.layer.borderWidth = 0.0;
        button.layer.borderColor = UIColor.clearColor.CGColor;
        UIColor *iconColor = selected ? UIColor.whiteColor : M2DesktopSidebarSecondaryTextColor();
        UIColor *titleColor = selected ? UIColor.whiteColor
                                       : (hovered ? [UIColor colorWithWhite:1.0 alpha:0.84]
                                                  : M2DesktopSidebarSecondaryTextColor());
        [self applySidebarTitle:titles[index] toButton:button color:titleColor];
        [self applySidebarSymbol:symbols[index] toButton:button color:iconColor];
    }
}

- (void)handleDesktopSidebarButtonHover:(UIHoverGestureRecognizer *)gesture {
    if (!M2IsMacCatalyst()) {
        return;
    }

    UIButton *button = (UIButton *)gesture.view;
    if (![button isKindOfClass:UIButton.class]) {
        return;
    }

    if (gesture.state == UIGestureRecognizerStateBegan ||
        gesture.state == UIGestureRecognizerStateChanged) {
        [self.desktopHoveredButtons addObject:button];
#if TARGET_OS_MACCATALYST
        [[NSCursor pointingHandCursor] set];
#endif
    } else {
        [self.desktopHoveredButtons removeObject:button];
#if TARGET_OS_MACCATALYST
        [[NSCursor arrowCursor] set];
#endif
    }

    [self updateDesktopSidebarSelection];
}

- (void)applyDesktopTabBarHiddenState {
    if (!M2IsMacCatalyst()) {
        return;
    }

    self.tabBar.hidden = YES;
    self.tabBar.alpha = 0.0;
    self.tabBar.userInteractionEnabled = NO;
    CGRect frame = self.tabBar.frame;
    frame.origin.y = CGRectGetHeight(self.view.bounds) + 120.0;
    self.tabBar.frame = frame;
}

- (CGRect)desktopContentFrame {
    CGFloat reservedBottom = M2MiniPlayerHeight() + 20.0;
    return UIEdgeInsetsInsetRect(self.view.bounds,
                                 UIEdgeInsetsMake(M2DesktopContentTopInset(),
                                                  M2DesktopContentLeftInset(),
                                                  reservedBottom,
                                                  M2DesktopContentRightInset()));
}

- (nullable UIView *)desktopPrimaryContentHostView {
    UIView *bestView = nil;
    CGFloat bestArea = 0.0;

    for (UIView *subview in self.view.subviews) {
        if (subview == self.tabBar ||
            subview == self.desktopSidebarView ||
            subview == self.miniPlayerContainer) {
            continue;
        }
        if (subview.hidden || subview.alpha <= 0.01) {
            continue;
        }

        CGSize size = subview.bounds.size;
        CGFloat area = MAX(size.width, 0.0) * MAX(size.height, 0.0);
        if (area > bestArea) {
            bestArea = area;
            bestView = subview;
        }
    }
    return bestView;
}

- (void)updateDesktopContentLayoutIfNeeded {
    if (!M2IsMacCatalyst()) {
        return;
    }

    CGRect contentFrame = [self desktopContentFrame];
    UIView *hostView = [self desktopPrimaryContentHostView];
    if (hostView == nil) {
        return;
    }

    if (!CGRectEqualToRect(hostView.frame, contentFrame)) {
        hostView.frame = contentFrame;
    }
    hostView.layer.cornerRadius = 18.0;
    hostView.layer.masksToBounds = YES;
    hostView.layer.borderWidth = 1.0;
    hostView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.10].CGColor;

    [self.view bringSubviewToFront:self.desktopSidebarView];
    [self.view bringSubviewToFront:self.miniPlayerContainer];
}

- (CGFloat)desktopContentLeadingInset {
    return M2IsMacCatalyst() ? M2DesktopContentLeftInset() : 0.0;
}

- (void)applyAdditionalSafeAreaInsets:(UIEdgeInsets)insets toController:(UIViewController *)controller {
    if (controller == nil) {
        return;
    }

    UIEdgeInsets current = controller.additionalSafeAreaInsets;
    BOOL unchanged = (fabs(current.top - insets.top) <= 0.5 &&
                      fabs(current.left - insets.left) <= 0.5 &&
                      fabs(current.bottom - insets.bottom) <= 0.5 &&
                      fabs(current.right - insets.right) <= 0.5);
    if (unchanged) {
        return;
    }
    controller.additionalSafeAreaInsets = insets;
}

- (void)selectTabAtIndex:(NSUInteger)index {
    if (index >= self.viewControllers.count) {
        return;
    }

    self.selectedIndex = index;
    [self updateDesktopContentLayoutIfNeeded];
    [self updateDesktopSidebarSelection];
    [self updateMiniPlayerPosition];
    [self updateMiniPlayer];
}

- (void)selectMusicTabKeyCommand {
    [self selectTabAtIndex:0];
}

- (void)selectPlaylistsTabKeyCommand {
    [self selectTabAtIndex:1];
}

- (void)selectFavoritesTabKeyCommand {
    [self selectTabAtIndex:2];
}

- (void)findKeyCommand {
    UINavigationController *navigation = [self selectedNavigationController];
    UIViewController *activeController = navigation.visibleViewController ?: navigation.topViewController;
    if (activeController == nil) {
        return;
    }

    SEL searchSelector = NSSelectorFromString(@"searchButtonTapped");
    if (![activeController respondsToSelector:searchSelector]) {
        return;
    }

    void (*function)(id, SEL) = (void *)[activeController methodForSelector:searchSelector];
    if (function != NULL) {
        function(activeController, searchSelector);
    }
}

- (void)togglePlayPauseKeyCommand {
    [M2PlaybackManager.sharedManager togglePlayPause];
    [self updateMiniPlayer];
}

- (void)playNextKeyCommand {
    [M2PlaybackManager.sharedManager playNext];
    [self updateMiniPlayer];
}

- (void)playPreviousKeyCommand {
    [M2PlaybackManager.sharedManager playPrevious];
    [self updateMiniPlayer];
}

- (void)openPlayerKeyCommand {
    [self openPlayerFromMiniPlayer];
}

- (void)handlePlaybackStateChanged {
    [self updateMiniPlayer];
}

- (nullable UINavigationController *)selectedNavigationController {
    if ([self.selectedViewController isKindOfClass:UINavigationController.class]) {
        return (UINavigationController *)self.selectedViewController;
    }
    return nil;
}

- (BOOL)isMiniPlayerAllowedForCurrentController {
    UINavigationController *navigation = [self selectedNavigationController];
    if (navigation == nil) {
        return YES;
    }

    id<UIViewControllerTransitionCoordinator> coordinator = navigation.transitionCoordinator;
    if (coordinator != nil) {
        UIViewController *toViewController = [coordinator viewControllerForKey:UITransitionContextToViewControllerKey];
        if (toViewController != nil) {
            return !toViewController.hidesBottomBarWhenPushed;
        }
    }

    UIViewController *active = navigation.visibleViewController ?: navigation.topViewController;
    if (active == nil) {
        return YES;
    }
    return !active.hidesBottomBarWhenPushed;
}

- (BOOL)isMiniPlayerAllowedForViewController:(UIViewController *)viewController {
    if (viewController == nil) {
        return YES;
    }
    return !viewController.hidesBottomBarWhenPushed;
}

- (BOOL)shouldShowMiniPlayer {
    if (M2IsMacCatalyst()) {
        return YES;
    }

    if (M2PlaybackManager.sharedManager.currentTrack == nil) {
        return NO;
    }

    if (self.tabBar.superview == nil) {
        return NO;
    }

    CGRect tabBarFrameInView = [self.view convertRect:self.tabBar.frame fromView:self.tabBar.superview];
    CGFloat tabBarTop = CGRectGetMinY(tabBarFrameInView);
    if (!isfinite(tabBarTop) || tabBarTop >= CGRectGetHeight(self.view.bounds)) {
        return NO;
    }

    return [self isMiniPlayerAllowedForCurrentController];
}

- (void)animateMiniPlayerAlongNavigationTransition:(UINavigationController *)navigationController {
    if (M2IsMacCatalyst()) {
        return;
    }

    id<UIViewControllerTransitionCoordinator> coordinator = navigationController.transitionCoordinator;
    if (coordinator == nil) {
        return;
    }

    UIViewController *fromViewController = [coordinator viewControllerForKey:UITransitionContextFromViewControllerKey];
    UIViewController *toViewController = [coordinator viewControllerForKey:UITransitionContextToViewControllerKey];
    BOOL fromAllows = [self isMiniPlayerAllowedForViewController:fromViewController];
    BOOL toAllows = [self isMiniPlayerAllowedForViewController:toViewController];
    BOOL hasTrack = (M2PlaybackManager.sharedManager.currentTrack != nil);

    if (!hasTrack || (fromAllows == toAllows)) {
        return;
    }

    CGFloat width = MAX(CGRectGetWidth(self.view.bounds), 1.0);
    CGFloat startX = 0.0;
    CGFloat endX = 0.0;

    if (fromAllows && !toAllows) {
        startX = 0.0;
        endX = -width;
    } else if (!fromAllows && toAllows) {
        startX = -width;
        endX = 0.0;
    }

    self.miniPlayerTransitionAnimating = YES;
    self.miniPlayerContainer.hidden = NO;
    self.miniPlayerContainer.transform = CGAffineTransformMakeTranslation(startX, 0.0);

    [coordinator animateAlongsideTransition:^(__unused id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        self.miniPlayerContainer.transform = CGAffineTransformMakeTranslation(endX, 0.0);
    } completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        self.miniPlayerContainer.transform = CGAffineTransformIdentity;
        self.miniPlayerTransitionAnimating = NO;

        if (context.isCancelled) {
            [self updateMiniPlayer];
            return;
        }

        [self updateMiniPlayer];
    }];
}

- (void)updateMiniPlayerPosition {
    if (self.miniPlayerBottomConstraint == nil ||
        self.miniPlayerLeadingConstraint == nil ||
        self.miniPlayerTrailingConstraint == nil) {
        return;
    }

    if (M2IsMacCatalyst()) {
        self.miniPlayerLeadingConstraint.constant = M2DesktopContentLeftInset();
        self.miniPlayerTrailingConstraint.constant = -M2DesktopContentRightInset();
    } else {
        self.miniPlayerLeadingConstraint.constant = [self desktopContentLeadingInset] + M2MiniPlayerHorizontalInset();
        self.miniPlayerTrailingConstraint.constant = -(M2MiniPlayerHorizontalInset() +
                                                       (M2IsMacCatalyst() ? M2DesktopContentRightInset() : 0.0));
    }
    if (M2IsMacCatalyst()) {
        CGFloat safeBottom = self.view.safeAreaInsets.bottom;
        self.miniPlayerBottomConstraint.constant = -(safeBottom + 10.0);
        return;
    }

    if (self.tabBar.superview == nil) {
        return;
    }

    CGRect tabBarFrameInView = [self.view convertRect:self.tabBar.frame fromView:self.tabBar.superview];
    CGFloat tabBarTop = CGRectGetMinY(tabBarFrameInView);
    if (!isfinite(tabBarTop) || tabBarTop <= 0.0) {
        tabBarTop = CGRectGetHeight(self.view.bounds) - CGRectGetHeight(self.tabBar.bounds);
    }

    CGFloat distanceFromBottom = MAX(0.0, CGRectGetHeight(self.view.bounds) - tabBarTop);
    self.miniPlayerBottomConstraint.constant = -(distanceFromBottom + M2MiniPlayerBottomSpacing());
}

- (void)updateMiniPlayer {
    [self updateMiniPlayerPosition];

    M2PlaybackManager *playback = M2PlaybackManager.sharedManager;
    M2Track *track = playback.currentTrack;
    BOOL shouldShow = [self shouldShowMiniPlayer];

    self.miniPlayerContainer.backgroundColor = M2MiniPlayerBackgroundColor();
    self.miniPlayerContainer.layer.borderColor = M2MiniPlayerBorderColor().CGColor;
    if (M2IsMacCatalyst()) {
        self.miniPlayerBlurView.effect = nil;
        self.miniPlayerBlurView.alpha = 0.0;
    } else {
        self.miniPlayerBlurView.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
        self.miniPlayerBlurView.alpha = 0.90;
    }
    if (!self.miniPlayerTransitionAnimating) {
        self.miniPlayerContainer.hidden = !shouldShow;
    }
    CGFloat inset = M2IsMacCatalyst() ? 0.0 : (shouldShow ? (M2MiniPlayerHeight() + M2MiniPlayerBottomSpacing() + 2.0) : 0.0);
    [self applyMiniPlayerInset:inset];

    if (!shouldShow) {
        return;
    }

    if (track == nil) {
        self.miniPlayerArtworkView.image = [UIImage systemImageNamed:@"music.note"];
        self.miniPlayerArtworkView.contentMode = UIViewContentModeCenter;
        self.miniPlayerArtworkView.tintColor = UIColor.secondaryLabelColor;
        self.miniPlayerTitleLabel.text = @"Nothing Playing";
        self.miniPlayerSubtitleLabel.text = @"Pick a track to start";
        self.miniPlayerSubtitleLabel.hidden = NO;
        self.miniPlayerTitleTopConstraint.active = YES;
        self.miniPlayerTitleCenterYConstraint.active = NO;
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:18.0
                                                                                               weight:UIImageSymbolWeightSemibold];
        [self.miniPlayerPlayPauseButton setImage:[UIImage systemImageNamed:@"play.fill" withConfiguration:config]
                                        forState:UIControlStateNormal];
        self.miniPlayerOpenButton.enabled = NO;
        self.miniPlayerPlayPauseButton.enabled = NO;
        self.miniPlayerPreviousButton.enabled = NO;
        self.miniPlayerNextButton.enabled = NO;
        self.miniPlayerPreviousButton.alpha = 0.45;
        self.miniPlayerNextButton.alpha = 0.45;
        return;
    }

    if (track.artwork != nil) {
        self.miniPlayerArtworkView.image = track.artwork;
        self.miniPlayerArtworkView.contentMode = UIViewContentModeScaleAspectFill;
        self.miniPlayerArtworkView.tintColor = nil;
    } else {
        self.miniPlayerArtworkView.image = [UIImage systemImageNamed:@"music.note"];
        self.miniPlayerArtworkView.contentMode = UIViewContentModeCenter;
        self.miniPlayerArtworkView.tintColor = UIColor.secondaryLabelColor;
    }

    NSString *title = track.title.length > 0 ? track.title : track.fileName;
    self.miniPlayerTitleLabel.text = title;
    BOOL hasArtist = (track.artist.length > 0);
    self.miniPlayerSubtitleLabel.text = hasArtist ? track.artist : @"";
    self.miniPlayerSubtitleLabel.hidden = !hasArtist;
    self.miniPlayerTitleTopConstraint.active = hasArtist;
    self.miniPlayerTitleCenterYConstraint.active = !hasArtist;

    NSString *symbolName = playback.isPlaying ? @"pause.fill" : @"play.fill";
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:18.0
                                                                                           weight:UIImageSymbolWeightSemibold];
    UIImage *playPauseImage = [UIImage systemImageNamed:symbolName withConfiguration:config];
    [self.miniPlayerPlayPauseButton setImage:playPauseImage forState:UIControlStateNormal];

    BOOL hasQueue = (playback.currentQueue.count > 0);
    BOOL canStep = (playback.currentQueue.count > 1) || playback.isShuffleEnabled || (playback.repeatMode != M2RepeatModeNone);
    self.miniPlayerOpenButton.enabled = hasQueue;
    self.miniPlayerPlayPauseButton.enabled = hasQueue;
    self.miniPlayerPreviousButton.enabled = hasQueue && canStep;
    self.miniPlayerNextButton.enabled = hasQueue && canStep;
    self.miniPlayerPreviousButton.alpha = self.miniPlayerPreviousButton.enabled ? 1.0 : 0.45;
    self.miniPlayerNextButton.alpha = self.miniPlayerNextButton.enabled ? 1.0 : 0.45;
}

- (void)applyMiniPlayerInset:(CGFloat)bottomInset {
    for (UIViewController *controller in self.viewControllers ?: @[]) {
        BOOL desktop = M2IsMacCatalyst();
        CGFloat leftInset = desktop ? 0.0 : [self desktopContentLeadingInset];
        if ([controller isKindOfClass:UINavigationController.class]) {
            UINavigationController *navigation = (UINavigationController *)controller;
            UIEdgeInsets navigationInsets = desktop
            ? UIEdgeInsetsZero
            : UIEdgeInsetsMake(0.0, leftInset, 0.0, 0.0);
            [self applyAdditionalSafeAreaInsets:navigationInsets toController:navigation];

            UIViewController *top = navigation.topViewController ?: navigation;
            UIEdgeInsets topInsets = UIEdgeInsetsMake(0.0, 0.0, bottomInset, 0.0);
            [self applyAdditionalSafeAreaInsets:topInsets toController:top];
            continue;
        }

        UIEdgeInsets insets = desktop
        ? UIEdgeInsetsMake(0.0, 0.0, bottomInset, 0.0)
        : UIEdgeInsetsMake(0.0, leftInset, bottomInset, 0.0);
        [self applyAdditionalSafeAreaInsets:insets toController:controller];
    }
}

- (void)miniPlayerOpenTapped {
    [self openPlayerFromMiniPlayer];
}

- (void)miniPlayerPlayPauseTapped {
    [M2PlaybackManager.sharedManager togglePlayPause];
    [self updateMiniPlayer];
}

- (void)miniPlayerPreviousTapped {
    [M2PlaybackManager.sharedManager playPrevious];
    [self updateMiniPlayer];
}

- (void)miniPlayerNextTapped {
    [M2PlaybackManager.sharedManager playNext];
    [self updateMiniPlayer];
}

- (void)handleMiniPlayerHorizontalPan:(UIPanGestureRecognizer *)gesture {
    if (self.miniPlayerContainer.hidden) {
        return;
    }

    if (gesture.state != UIGestureRecognizerStateEnded) {
        return;
    }

    CGPoint translation = [gesture translationInView:self.miniPlayerContainer];
    CGPoint velocity = [gesture velocityInView:self.miniPlayerContainer];
    CGFloat absX = fabs(translation.x);
    CGFloat absY = fabs(translation.y);
    BOOL horizontalIntent = (absX > absY * 1.1);
    if (!horizontalIntent) {
        return;
    }

    if (translation.x <= -20.0 || velocity.x <= -300.0) {
        [self miniPlayerNextTapped];
    } else if (translation.x >= 20.0 || velocity.x >= 300.0) {
        [self miniPlayerPreviousTapped];
    }
}

- (void)openPlayerFromMiniPlayer {
    if (M2PlaybackManager.sharedManager.currentTrack == nil) {
        return;
    }

    UINavigationController *navigation = [self selectedNavigationController];
    if (navigation == nil) {
        return;
    }

    UIViewController *top = navigation.topViewController;
    if ([NSStringFromClass(top.class) isEqualToString:@"M2PlayerViewController"]) {
        return;
    }

    Class playerClass = NSClassFromString(@"M2PlayerViewController");
    if (playerClass == Nil || ![playerClass isSubclassOfClass:UIViewController.class]) {
        return;
    }

    UIViewController *player = [[playerClass alloc] init];
    player.hidesBottomBarWhenPushed = YES;
    [navigation pushViewController:player animated:!M2IsMacCatalyst()];
}

- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController {
    (void)tabBarController;
    (void)viewController;
    [self becomeFirstResponder];
    [self updateDesktopContentLayoutIfNeeded];
    [self updateDesktopSidebarSelection];
    [self updateMiniPlayerPosition];
    [self updateMiniPlayer];
}

- (void)navigationController:(UINavigationController *)navigationController
      willShowViewController:(UIViewController *)viewController
                    animated:(BOOL)animated {
    (void)viewController;
    [self updateDesktopContentLayoutIfNeeded];
    [self updateMiniPlayerPosition];
    if (animated && !M2IsMacCatalyst()) {
        [self animateMiniPlayerAlongNavigationTransition:navigationController];
    }
    [self becomeFirstResponder];
    [self updateMiniPlayer];
}

- (UIImage *)tabIconNamed:(NSString *)name {
    UIImage *image = [UIImage imageNamed:name];
    if (image == nil) {
        NSString *path = [NSBundle.mainBundle pathForResource:name ofType:@"png"];
        if (path != nil) {
            image = [UIImage imageWithContentsOfFile:path];
        }
    }

    if (image == nil) {
        image = [UIImage systemImageNamed:@"circle.fill"];
    }

    UIImage *normalized = [self normalizedIconImage:image targetSize:24.0];
    return [normalized imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

- (UIImage *)normalizedIconImage:(UIImage *)image targetSize:(CGFloat)targetSize {
    CGSize canvasSize = CGSizeMake(targetSize, targetSize);
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.opaque = NO;
    format.scale = UIScreen.mainScreen.scale;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:canvasSize format:format];

    return [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull context) {
        CGSize source = image.size;
        if (source.width <= 0.0 || source.height <= 0.0) {
            [image drawInRect:CGRectMake(0.0, 0.0, canvasSize.width, canvasSize.height)];
            return;
        }

        CGFloat scale = MIN(canvasSize.width / source.width, canvasSize.height / source.height);
        CGSize drawSize = CGSizeMake(source.width * scale, source.height * scale);
        CGRect drawRect = CGRectMake((canvasSize.width - drawSize.width) * 0.5,
                                     (canvasSize.height - drawSize.height) * 0.5,
                                     drawSize.width,
                                     drawSize.height);
        [image drawInRect:drawRect];
    }];
}

- (UIImage *)tabSymbolIconNamed:(NSString *)symbolName pointSize:(CGFloat)pointSize {
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:pointSize
                                                                                           weight:UIImageSymbolWeightSemibold];
    UIImage *image = [UIImage systemImageNamed:symbolName withConfiguration:config];
    if (image == nil) {
        image = [UIImage systemImageNamed:@"circle.fill"];
    }
    UIImage *normalized = [self normalizedIconImage:image targetSize:24.0];
    return [normalized imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

@end
