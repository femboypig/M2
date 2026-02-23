//
//  SceneDelegate.m
//  M2
//
//  Created by loser on 22.02.2026.
//

#import "SceneDelegate.h"

#import "AppDelegate.h"
#import "ViewController.h"
#import "M2Services.h"
#import <TargetConditionals.h>

typedef void (^M2BootReadyHandler)(void);
static const NSTimeInterval kM2BootMinimumDuration = 0.35;
static const NSTimeInterval kM2BootMaximumWaitDuration = 1.2;

static UIColor *M2BootBackgroundColor(void) {
    return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull trait) {
        if (trait.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return UIColor.blackColor;
        }
        return UIColor.whiteColor;
    }];
}

static UIImage *M2AppIconImage(UITraitCollection *traitCollection) {
    UIImage *image = [UIImage imageNamed:@"LaunchIcon"
                                inBundle:NSBundle.mainBundle
           compatibleWithTraitCollection:traitCollection];
    if (image == nil) {
        image = [UIImage imageNamed:@"LaunchIcon"];
    }
    if (image == nil) {
        image = [UIImage imageNamed:@"launch-icon-any"];
    }
    if (image == nil) {
        image = [UIImage systemImageNamed:@"music.note"];
    }
    return image;
}

@interface M2BootViewController : UIViewController

@property (nonatomic, copy) M2BootReadyHandler readyHandler;
@property (nonatomic, assign) BOOL didStartPreload;
@property (nonatomic, assign) CFTimeInterval bootStartTime;
@property (nonatomic, assign) BOOL didCompleteBoot;

@end

@implementation M2BootViewController

- (void)completeBootIfNeeded {
    if (self.didCompleteBoot) {
        return;
    }

    self.didCompleteBoot = YES;
    M2BootReadyHandler handler = self.readyHandler;
    self.readyHandler = nil;
    if (handler != nil) {
        handler();
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = M2BootBackgroundColor();

    UIImageView *iconView = [[UIImageView alloc] init];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.contentMode = UIViewContentModeScaleAspectFill;
    iconView.image = M2AppIconImage(self.traitCollection);
    iconView.layer.cornerRadius = 24.0;
    iconView.layer.masksToBounds = YES;
    [self.view addSubview:iconView];

    [NSLayoutConstraint activateConstraints:@[
        [iconView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:124.0],
        [iconView.heightAnchor constraintEqualToConstant:124.0]
    ]];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    if (self.didStartPreload) {
        return;
    }
    self.didStartPreload = YES;
    self.bootStartTime = CFAbsoluteTimeGetCurrent();
    self.didCompleteBoot = NO;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kM2BootMaximumWaitDuration * (NSTimeInterval)NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self completeBootIfNeeded];
    });

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @autoreleasepool {
            M2LibraryManager *library = M2LibraryManager.sharedManager;
            NSArray<M2Track *> *tracks = [library reloadTracks];

            M2PlaylistStore *playlists = M2PlaylistStore.sharedStore;
            [playlists reloadPlaylists];

            M2FavoritesStore *favorites = M2FavoritesStore.sharedStore;
            [favorites favoriteTrackIDs];
            [favorites favoriteTracksWithLibrary:library];

            if (tracks.count > 0) {
                NSMutableArray<NSString *> *trackIDs = [NSMutableArray arrayWithCapacity:tracks.count];
                for (M2Track *track in tracks) {
                    if (track.identifier.length > 0) {
                        [trackIDs addObject:track.identifier];
                    }
                }
                if (trackIDs.count > 0) {
                    [M2TrackAnalyticsStore.sharedStore analyticsByTrackIDForTrackIDs:trackIDs];
                }
            }

            for (M2Playlist *playlist in playlists.playlists) {
                [playlists tracksForPlaylist:playlist library:library];
                [playlists coverForPlaylist:playlist library:library size:CGSizeMake(160.0, 160.0)];
            }

            (void)M2PlaybackManager.sharedManager;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            NSTimeInterval elapsed = CFAbsoluteTimeGetCurrent() - self.bootStartTime;
            NSTimeInterval remaining = MAX(0.0, kM2BootMinimumDuration - elapsed);
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(remaining * (NSTimeInterval)NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                [self completeBootIfNeeded];
            });
        });
    });
}

@end

@interface SceneDelegate ()

@property (nonatomic, assign) BOOL didAdjustMacTrafficLights;

@end

@implementation SceneDelegate

#if TARGET_OS_MACCATALYST
- (void)adjustMacTrafficLightsIfNeeded {
    if (self.didAdjustMacTrafficLights || self.window == nil) {
        return;
    }

    id nsWindow = nil;
    @try {
        nsWindow = [self.window valueForKey:@"nsWindow"];
    } @catch (__unused NSException *exception) {
        return;
    }

    if (nsWindow == nil) {
        return;
    }

    SEL standardWindowButtonSelector = NSSelectorFromString(@"standardWindowButton:");
    if (![nsWindow respondsToSelector:standardWindowButtonSelector]) {
        return;
    }

    // NSWindow close/minimize/zoom button indices.
    NSArray<NSNumber *> *buttonTypes = @[@0, @1, @2];
    NSMethodSignature *signature = [nsWindow methodSignatureForSelector:standardWindowButtonSelector];
    if (signature == nil) {
        return;
    }

    for (NSNumber *buttonType in buttonTypes) {
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
        invocation.target = nsWindow;
        invocation.selector = standardWindowButtonSelector;
        NSInteger type = buttonType.integerValue;
        [invocation setArgument:&type atIndex:2];
        [invocation invoke];

        __unsafe_unretained id button = nil;
        [invocation getReturnValue:&button];
        if (button == nil) {
            continue;
        }

        NSValue *frameValue = nil;
        @try {
            frameValue = [button valueForKey:@"frame"];
        } @catch (__unused NSException *exception) {
            continue;
        }
        if (![frameValue isKindOfClass:NSValue.class]) {
            continue;
        }

        CGRect frame = frameValue.CGRectValue;
        frame.origin.x += 2.0;
        frame.origin.y -= 2.0;

        @try {
            [button setValue:[NSValue valueWithCGRect:frame] forKey:@"frame"];
        } @catch (__unused NSException *exception) {
            continue;
        }
    }

    self.didAdjustMacTrafficLights = YES;
}
#endif

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    (void)session;
    (void)connectionOptions;

    if (![scene isKindOfClass:UIWindowScene.class]) {
        return;
    }

    UIWindowScene *windowScene = (UIWindowScene *)scene;
#if TARGET_OS_MACCATALYST
    UISceneSizeRestrictions *sizeRestrictions = windowScene.sizeRestrictions;
    if (sizeRestrictions != nil) {
        sizeRestrictions.minimumSize = CGSizeMake(980.0, 640.0);
    }
    if (@available(iOS 15.0, *)) {
        windowScene.titlebar.titleVisibility = UITitlebarTitleVisibilityHidden;
        windowScene.titlebar.toolbar = nil;
    }
#endif
    self.window = [[UIWindow alloc] initWithWindowScene:windowScene];
    M2BootViewController *bootViewController = [[M2BootViewController alloc] init];

    __weak typeof(self) weakSelf = self;
    bootViewController.readyHandler = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf == nil || strongSelf.window == nil) {
            return;
        }

        ViewController *mainController = [[ViewController alloc] init];
        [UIView transitionWithView:strongSelf.window
                          duration:0.18
                           options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowAnimatedContent
                        animations:^{
            strongSelf.window.rootViewController = mainController;
        } completion:^(__unused BOOL finished) {
#if TARGET_OS_MACCATALYST
            [strongSelf adjustMacTrafficLightsIfNeeded];
#endif
        }];
    };

    self.window.rootViewController = bootViewController;
    [self.window makeKeyAndVisible];
#if TARGET_OS_MACCATALYST
    dispatch_async(dispatch_get_main_queue(), ^{
        [self adjustMacTrafficLightsIfNeeded];
    });
#endif
}

- (void)sceneDidDisconnect:(UIScene *)scene {
    (void)scene;
}

- (void)sceneDidBecomeActive:(UIScene *)scene {
    (void)scene;
#if TARGET_OS_MACCATALYST
    [self adjustMacTrafficLightsIfNeeded];
#endif
}

- (void)sceneWillResignActive:(UIScene *)scene {
    (void)scene;
}

- (void)sceneWillEnterForeground:(UIScene *)scene {
    (void)scene;
}

- (void)sceneDidEnterBackground:(UIScene *)scene {
    (void)scene;
    [(AppDelegate *)UIApplication.sharedApplication.delegate saveContext];
}

@end
