//
//  M2MusicModule.m
//  M2
//

#import "M2MusicModule.h"

#import <math.h>
#import <PhotosUI/PhotosUI.h>

#import "M2Cells.h"
#import "M2Services.h"

static UIColor *M2AccentYellowColor(void) {
    return [UIColor colorWithRed:1.0 green:0.83 blue:0.08 alpha:1.0];
}

static UIColor *M2LovelyAccentRedColor(void) {
    return [UIColor colorWithRed:0.90 green:0.12 blue:0.15 alpha:1.0];
}

static NSString * const M2LovelyPlaylistDefaultsKey = @"m2_lovely_playlist_id_v1";
static NSString * const M2LovelyPlaylistCoverMarkerKey = @"m2_lovely_playlist_cover_marker_v2";

static UIColor *M2PlayerBackgroundColor(void) {
    return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull trait) {
        if (trait.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return UIColor.blackColor;
        }
        return UIColor.systemBackgroundColor;
    }];
}

static UIColor *M2PlayerPrimaryColor(void) {
    return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull trait) {
        if (trait.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return UIColor.whiteColor;
        }
        return UIColor.labelColor;
    }];
}

static UIColor *M2PlayerSecondaryColor(void) {
    return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull trait) {
        if (trait.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithWhite:1.0 alpha:0.66];
        }
        return UIColor.secondaryLabelColor;
    }];
}

static UIColor *M2PlayerTimelineMaxColor(void) {
    return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull trait) {
        if (trait.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithWhite:1.0 alpha:0.24];
        }
        return [UIColor colorWithWhite:0.0 alpha:0.22];
    }];
}

static UIFont *M2HeadlineFont(CGFloat size) {
    UIFont *font = [UIFont fontWithName:@"YSMusic-HeadlineBold" size:size];
    if (font != nil) {
        return font;
    }
    return [UIFont boldSystemFontOfSize:size];
}

static UIImage *M2LovelySongsCoverImage(CGSize size) {
    UIImage *sourceImage = [UIImage imageNamed:@"LovelyCover"];
    if (sourceImage == nil) {
        sourceImage = [UIImage imageNamed:@"lovely-cover"];
    }

    CGSize normalizedSize = CGSizeMake(MAX(size.width, 240.0), MAX(size.height, 240.0));
    if (sourceImage == nil || sourceImage.size.width <= 1.0 || sourceImage.size.height <= 1.0) {
        sourceImage = [UIImage systemImageNamed:@"heart.fill"];
        if (sourceImage == nil) {
            return nil;
        }
    }

    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:normalizedSize];
    return [renderer imageWithActions:^(__unused UIGraphicsImageRendererContext * _Nonnull rendererContext) {
        [[UIColor colorWithRed:0.78 green:0.03 blue:0.08 alpha:1.0] setFill];
        UIRectFill(CGRectMake(0.0, 0.0, normalizedSize.width, normalizedSize.height));

        CGFloat scale = MAX(normalizedSize.width / sourceImage.size.width,
                            normalizedSize.height / sourceImage.size.height);
        CGSize drawSize = CGSizeMake(sourceImage.size.width * scale, sourceImage.size.height * scale);
        CGRect drawRect = CGRectMake((normalizedSize.width - drawSize.width) * 0.5,
                                     (normalizedSize.height - drawSize.height) * 0.5,
                                     drawSize.width,
                                     drawSize.height);
        [sourceImage drawInRect:drawRect];
    }];
}

static UILabel *M2WhiteSectionTitleLabel(NSString *text) {
    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    label.textColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull trait) {
        if (trait.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return UIColor.whiteColor;
        }
        return UIColor.blackColor;
    }];
    label.font = M2HeadlineFont(28.0);
    [label sizeToFit];
    return label;
}

static void M2PresentAlert(UIViewController *controller, NSString *title, NSString *message) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [controller presentViewController:alert animated:YES completion:nil];
}

static NSString *M2NormalizedSearchText(NSString *text) {
    NSString *trimmed = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return trimmed.lowercaseString ?: @"";
}

static BOOL M2TrackMatchesSearchQuery(M2Track *track, NSString *query) {
    if (query.length == 0) {
        return YES;
    }

    NSString *title = track.title.lowercaseString ?: @"";
    NSString *artist = track.artist.lowercaseString ?: @"";
    NSString *fileName = track.fileName.lowercaseString ?: @"";
    return ([title containsString:query] ||
            [artist containsString:query] ||
            [fileName containsString:query]);
}

static NSArray<M2Track *> *M2FilterTracksByQuery(NSArray<M2Track *> *tracks, NSString *query) {
    NSString *normalizedQuery = M2NormalizedSearchText(query);
    if (normalizedQuery.length == 0) {
        return tracks ?: @[];
    }

    NSMutableArray<M2Track *> *filtered = [NSMutableArray arrayWithCapacity:tracks.count];
    for (M2Track *track in tracks) {
        if (M2TrackMatchesSearchQuery(track, normalizedQuery)) {
            [filtered addObject:track];
        }
    }
    return [filtered copy];
}

static NSInteger M2IndexOfTrackByIdentifier(NSArray<M2Track *> *tracks, NSString *trackID) {
    if (trackID.length == 0 || tracks.count == 0) {
        return NSNotFound;
    }

    for (NSUInteger idx = 0; idx < tracks.count; idx += 1) {
        M2Track *track = tracks[idx];
        if ([track.identifier isEqualToString:trackID]) {
            return (NSInteger)idx;
        }
    }
    return NSNotFound;
}

static BOOL M2TrackQueuesMatchByIdentifier(NSArray<M2Track *> *first, NSArray<M2Track *> *second) {
    if (first.count != second.count) {
        return NO;
    }

    for (NSUInteger idx = 0; idx < first.count; idx += 1) {
        M2Track *leftTrack = first[idx];
        M2Track *rightTrack = second[idx];
        if (![leftTrack.identifier isEqualToString:rightTrack.identifier]) {
            return NO;
        }
    }
    return YES;
}

static NSArray<M2Playlist *> *M2FilterPlaylistsByQuery(NSArray<M2Playlist *> *playlists, NSString *query) {
    NSString *normalizedQuery = M2NormalizedSearchText(query);
    if (normalizedQuery.length == 0) {
        return playlists ?: @[];
    }

    NSMutableArray<M2Playlist *> *filtered = [NSMutableArray arrayWithCapacity:playlists.count];
    for (M2Playlist *playlist in playlists) {
        NSString *name = playlist.name.lowercaseString ?: @"";
        if ([name containsString:normalizedQuery]) {
            [filtered addObject:playlist];
        }
    }
    return [filtered copy];
}

static UISearchController *M2BuildSearchController(id<UISearchResultsUpdating> updater, NSString *placeholder) {
    UISearchController *searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    searchController.obscuresBackgroundDuringPresentation = NO;
    searchController.hidesNavigationBarDuringPresentation = NO;
    searchController.searchResultsUpdater = updater;
    searchController.searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
    searchController.searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
    if (placeholder.length > 0) {
        searchController.searchBar.placeholder = placeholder;
    }
    return searchController;
}

static CGFloat M2SearchPullDistance(UIScrollView *scrollView) {
    if (scrollView == nil) {
        return 0.0;
    }
    CGFloat topEdge = -scrollView.adjustedContentInset.top;
    return MAX(0.0, topEdge - scrollView.contentOffset.y);
}

static CGFloat const M2SearchRevealThreshold = 62.0;
static CGFloat const M2SearchDismissThreshold = 40.0;

static BOOL M2ShouldAttachSearchController(BOOL currentlyAttached,
                                           UISearchController *searchController,
                                           UIScrollView *scrollView,
                                           CGFloat revealThreshold) {
    if (searchController == nil || scrollView == nil) {
        return NO;
    }

    BOOL hasQuery = searchController.searchBar.text.length > 0;
    if (currentlyAttached) {
        if (searchController.isActive || hasQuery) {
            return YES;
        }

        CGFloat topEdge = -scrollView.adjustedContentInset.top;
        BOOL scrolledIntoContent = (scrollView.contentOffset.y > topEdge + M2SearchDismissThreshold);
        return !scrolledIntoContent;
    }

    CGFloat pullDistance = M2SearchPullDistance(scrollView);
    return (pullDistance >= revealThreshold);
}

static void M2ApplySearchControllerAttachment(UINavigationItem *navigationItem,
                                              UINavigationBar *navigationBar,
                                              UISearchController *searchController,
                                              BOOL shouldAttach,
                                              BOOL animated) {
    if (navigationItem == nil) {
        return;
    }

    UISearchController *targetController = shouldAttach ? searchController : nil;
    if (navigationItem.searchController == targetController) {
        return;
    }

    if (animated && navigationBar != nil) {
        [UIView transitionWithView:navigationBar
                          duration:0.20
                           options:(UIViewAnimationOptionTransitionCrossDissolve |
                                    UIViewAnimationOptionAllowUserInteraction |
                                    UIViewAnimationOptionBeginFromCurrentState)
                        animations:^{
            navigationItem.searchController = targetController;
            [navigationBar layoutIfNeeded];
        }
                        completion:nil];
        return;
    }

    navigationItem.searchController = targetController;
}

static void M2PresentQuickAddTrackToPlaylist(UIViewController *controller,
                                             NSString *trackID,
                                             dispatch_block_t completionHandler) {
    if (controller == nil || trackID.length == 0) {
        return;
    }

    [M2PlaylistStore.sharedStore reloadPlaylists];
    NSArray<M2Playlist *> *playlists = M2PlaylistStore.sharedStore.playlists;
    if (playlists.count == 0) {
        M2PresentAlert(controller, @"No Playlists", @"Create a playlist first.");
        return;
    }

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Add To Playlist"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    for (M2Playlist *playlist in playlists) {
        BOOL alreadyContains = [playlist.trackIDs containsObject:trackID];
        NSString *title = playlist.name ?: @"Playlist";
        if (alreadyContains) {
            title = [title stringByAppendingString:@"  ✓"];
        }

        UIAlertAction *action = [UIAlertAction actionWithTitle:title
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(__unused UIAlertAction * _Nonnull selectedAction) {
            BOOL added = [M2PlaylistStore.sharedStore addTrackIDs:@[trackID] toPlaylistID:playlist.playlistID];
            if (!added) {
                M2PresentAlert(controller, @"Already Added", @"Track already exists in that playlist.");
                return;
            }
            if (completionHandler != nil) {
                completionHandler();
            }
        }];
        action.enabled = !alreadyContains;
        [sheet addAction:action];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    UIPopoverPresentationController *popover = sheet.popoverPresentationController;
    if (popover != nil) {
        popover.sourceView = controller.view;
        popover.sourceRect = CGRectMake(CGRectGetMidX(controller.view.bounds),
                                        CGRectGetMidY(controller.view.bounds),
                                        1.0,
                                        1.0);
    }

    [controller presentViewController:sheet animated:YES completion:nil];
}

static UIButton *M2PlainIconButton(NSString *symbolName, CGFloat symbolSize, CGFloat weightValue) {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;

    UIImageSymbolWeight weight = UIImageSymbolWeightRegular;
    if (weightValue >= 700.0) {
        weight = UIImageSymbolWeightBold;
    } else if (weightValue >= 600.0) {
        weight = UIImageSymbolWeightSemibold;
    }

    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:symbolSize
                                                                                           weight:weight];
    [button setImage:[UIImage systemImageNamed:symbolName withConfiguration:config] forState:UIControlStateNormal];
    button.tintColor = M2PlayerPrimaryColor();
    button.backgroundColor = UIColor.clearColor;
    return button;
}

static UIImage *M2SliderThumbImage(CGFloat diameter, UIColor *color) {
    CGFloat normalizedDiameter = MAX(2.0, diameter);
    CGSize size = CGSizeMake(normalizedDiameter + 2.0, normalizedDiameter + 2.0);
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size];
    return [renderer imageWithActions:^(__unused UIGraphicsImageRendererContext * _Nonnull context) {
        CGRect circleRect = CGRectMake(1.0, 1.0, normalizedDiameter, normalizedDiameter);
        [color setFill];
        UIBezierPath *path = [UIBezierPath bezierPathWithOvalInRect:circleRect];
        [path fill];
    }];
}

static NSString *M2SleepTimerRemainingString(NSTimeInterval interval) {
    NSInteger totalSeconds = (NSInteger)llround(MAX(0.0, interval));
    NSInteger hours = totalSeconds / 3600;
    NSInteger minutes = (totalSeconds % 3600) / 60;
    NSInteger seconds = totalSeconds % 60;

    if (hours > 0) {
        return [NSString stringWithFormat:@"%ld:%02ld:%02ld", (long)hours, (long)minutes, (long)seconds];
    }
    return [NSString stringWithFormat:@"%ld:%02ld", (long)minutes, (long)seconds];
}

static NSTimeInterval M2SleepTimerDurationFromInput(NSString *input) {
    NSString *trimmed = [input stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmed.length == 0) {
        return 0.0;
    }

    NSArray<NSString *> *colonParts = [trimmed componentsSeparatedByString:@":"];
    if (colonParts.count == 2 || colonParts.count == 3) {
        NSMutableArray<NSNumber *> *values = [NSMutableArray arrayWithCapacity:colonParts.count];
        for (NSString *part in colonParts) {
            NSString *token = [part stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if (token.length == 0) {
                return 0.0;
            }

            NSScanner *scanner = [NSScanner scannerWithString:token];
            NSInteger value = 0;
            if (![scanner scanInteger:&value] || !scanner.isAtEnd || value < 0) {
                return 0.0;
            }
            [values addObject:@(value)];
        }

        NSTimeInterval duration = 0.0;
        if (values.count == 2) {
            NSInteger hours = values[0].integerValue;
            NSInteger minutes = values[1].integerValue;
            if (minutes >= 60) {
                return 0.0;
            }
            duration = (NSTimeInterval)(hours * 3600 + minutes * 60);
        } else {
            NSInteger hours = values[0].integerValue;
            NSInteger minutes = values[1].integerValue;
            NSInteger seconds = values[2].integerValue;
            if (minutes >= 60 || seconds >= 60) {
                return 0.0;
            }
            duration = (NSTimeInterval)(hours * 3600 + minutes * 60 + seconds);
        }

        if (duration <= 0.0 || duration > 24.0 * 3600.0) {
            return 0.0;
        }
        return duration;
    }

    NSScanner *scanner = [NSScanner scannerWithString:trimmed];
    double minutesValue = 0.0;
    if (![scanner scanDouble:&minutesValue] || !scanner.isAtEnd) {
        return 0.0;
    }

    NSTimeInterval duration = minutesValue * 60.0;
    if (!isfinite(duration) || duration <= 0.0 || duration > 24.0 * 3600.0) {
        return 0.0;
    }
    return duration;
}

static void M2PresentCustomSleepTimerAlert(UIViewController *controller, dispatch_block_t updateHandler) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Custom Sleep Timer"
                                                                   message:@"Enter minutes (e.g. 25) or h:mm (e.g. 1:30)."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"25 or 1:30";
        textField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
        NSTimeInterval remaining = M2SleepTimerManager.sharedManager.remainingTime;
        if (remaining > 0.0) {
            textField.text = [NSString stringWithFormat:@"%.0f", ceil(remaining / 60.0)];
        }
    }];

    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Set Timer"
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction * _Nonnull action) {
        NSString *rawValue = alert.textFields.firstObject.text ?: @"";
        NSTimeInterval duration = M2SleepTimerDurationFromInput(rawValue);
        if (duration <= 0.0) {
            M2PresentAlert(controller,
                           @"Invalid Time",
                           @"Use minutes (25) or h:mm (1:30). Max is 24 hours.");
            return;
        }

        [M2SleepTimerManager.sharedManager startWithDuration:duration];
        if (updateHandler != nil) {
            updateHandler();
        }
    }]];

    [controller presentViewController:alert animated:YES completion:nil];
}

static void M2PresentSleepTimerActionSheet(UIViewController *controller,
                                           UIView *sourceView,
                                           dispatch_block_t updateHandler) {
    M2SleepTimerManager *sleepTimer = M2SleepTimerManager.sharedManager;
    NSString *message = sleepTimer.isActive
    ? [NSString stringWithFormat:@"Will stop playback in %@.", M2SleepTimerRemainingString(sleepTimer.remainingTime)]
    : @"Stop playback automatically after selected time.";

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Sleep Timer"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    NSArray<NSNumber *> *durations = @[@(15 * 60), @(30 * 60), @(45 * 60), @(60 * 60)];
    for (NSNumber *durationValue in durations) {
        NSInteger minutes = durationValue.integerValue / 60;
        NSString *title = [NSString stringWithFormat:@"%ld min", (long)minutes];
        [sheet addAction:[UIAlertAction actionWithTitle:title
                                                  style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction * _Nonnull action) {
            [M2SleepTimerManager.sharedManager startWithDuration:durationValue.doubleValue];
            if (updateHandler != nil) {
                updateHandler();
            }
        }]];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:@"Custom..."
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction * _Nonnull action) {
        dispatch_async(dispatch_get_main_queue(), ^{
            M2PresentCustomSleepTimerAlert(controller, updateHandler);
        });
    }]];

    if (sleepTimer.isActive) {
        [sheet addAction:[UIAlertAction actionWithTitle:@"Turn Off Sleep Timer"
                                                  style:UIAlertActionStyleDestructive
                                                handler:^(__unused UIAlertAction * _Nonnull action) {
            [M2SleepTimerManager.sharedManager cancel];
            if (updateHandler != nil) {
                updateHandler();
            }
        }]];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    UIPopoverPresentationController *popover = sheet.popoverPresentationController;
    if (popover != nil) {
        UIView *anchorView = sourceView ?: controller.view;
        popover.sourceView = anchorView;
        popover.sourceRect = anchorView.bounds;
    }

    [controller presentViewController:sheet animated:YES completion:nil];
}

@interface M2PlayerViewController : UIViewController
@end

@interface M2PlaylistNameViewController : UIViewController
@end

@interface M2PlaylistTrackPickerViewController : UIViewController
- (instancetype)initWithPlaylistName:(NSString *)playlistName tracks:(NSArray<M2Track *> *)tracks;
@end

@interface M2PlaylistAddTracksViewController : UIViewController
- (instancetype)initWithPlaylistID:(NSString *)playlistID;
@end

@interface M2PlaylistCoverPickerViewController : UIViewController <PHPickerViewControllerDelegate>
- (instancetype)initWithPlaylistID:(NSString *)playlistID;
@end

@interface M2PlaylistDetailViewController : UIViewController
- (instancetype)initWithPlaylistID:(NSString *)playlistID;
@end

#pragma mark - Music

@interface M2MusicViewController () <UITableViewDataSource, UITableViewDelegate, UISearchResultsUpdating>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, copy) NSArray<M2Track *> *tracks;
@property (nonatomic, copy) NSArray<M2Track *> *filteredTracks;
@property (nonatomic, copy) NSString *searchQuery;
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, assign) BOOL searchControllerAttached;

@end

@implementation M2MusicViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Music";
    self.navigationItem.title = nil;
    self.navigationItem.titleView = nil;
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:M2WhiteSectionTitleLabel(@"Music")];
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    self.view.backgroundColor = UIColor.systemBackgroundColor;

    [self setupTableView];
    [self setupSearch];

    UIBarButtonItem *reloadItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"arrow.clockwise"]
                                                                    style:UIBarButtonItemStylePlain
                                                                   target:self
                                                                   action:@selector(reloadTracks)];
    UIBarButtonItem *searchItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"magnifyingglass"]
                                                                    style:UIBarButtonItemStylePlain
                                                                   target:self
                                                                   action:@selector(searchButtonTapped)];
    self.navigationItem.rightBarButtonItems = @[searchItem, reloadItem];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(handlePlaybackChanged)
                                               name:M2PlaybackStateDidChangeNotification
                                             object:nil];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(reloadTracks)
                                               name:UIApplicationWillEnterForegroundNotification
                                             object:nil];

    [self reloadTracks];
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self updateSearchControllerAttachment];
    [self.tableView reloadData];
}

- (void)setupTableView {
    UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    tableView.translatesAutoresizingMaskIntoConstraints = NO;
    tableView.dataSource = self;
    tableView.delegate = self;
    tableView.rowHeight = 54.0;
    tableView.alwaysBounceVertical = YES;
    tableView.sectionHeaderHeight = 0.0;
    tableView.sectionFooterHeight = 0.0;
    tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    if (@available(iOS 15.0, *)) {
        tableView.sectionHeaderTopPadding = 0.0;
    }
    [tableView registerClass:M2TrackCell.class forCellReuseIdentifier:@"MusicTrackCell"];

    self.tableView = tableView;
    [self.view addSubview:tableView];

    [NSLayoutConstraint activateConstraints:@[
        [tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)setupSearch {
    self.searchController = M2BuildSearchController(self, @"Search Music");
    self.navigationItem.searchController = nil;
    self.navigationItem.hidesSearchBarWhenScrolling = YES;
    self.definesPresentationContext = YES;
    self.searchControllerAttached = NO;
}

- (void)updateSearchControllerAttachment {
    BOOL shouldAttach = M2ShouldAttachSearchController(self.searchControllerAttached,
                                                       self.searchController,
                                                       self.tableView,
                                                       M2SearchRevealThreshold);
    if (shouldAttach == self.searchControllerAttached) {
        return;
    }

    self.searchControllerAttached = shouldAttach;
    M2ApplySearchControllerAttachment(self.navigationItem,
                                      self.navigationController.navigationBar,
                                      self.searchController,
                                      shouldAttach,
                                      (self.view.window != nil));
}

- (void)applySearchFilterAndReload {
    self.filteredTracks = M2FilterTracksByQuery(self.tracks, self.searchQuery);
    [self.tableView reloadData];
    [self updateEmptyState];
}

- (void)updateEmptyState {
    if (self.filteredTracks.count > 0) {
        self.tableView.backgroundView = nil;
        return;
    }

    UILabel *label = [[UILabel alloc] init];
    label.textColor = UIColor.secondaryLabelColor;
    label.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 0;

    if (self.tracks.count == 0) {
        label.text = @"No music files in On My iPhone/M2/M2";
    } else {
        label.text = @"No search results.";
    }
    self.tableView.backgroundView = label;
}

- (void)reloadTracks {
    self.tracks = [M2LibraryManager.sharedManager reloadTracks];
    [self applySearchFilterAndReload];
}

- (void)handlePlaybackChanged {
    [self.tableView reloadData];
}

- (void)openPlayer {
    M2PlayerViewController *player = [[M2PlayerViewController alloc] init];
    player.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:player animated:YES];
}

- (void)searchButtonTapped {
    if (self.searchController == nil) {
        return;
    }

    if (!self.searchControllerAttached) {
        self.searchControllerAttached = YES;
        M2ApplySearchControllerAttachment(self.navigationItem,
                                          self.navigationController.navigationBar,
                                          self.searchController,
                                          YES,
                                          (self.view.window != nil));
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        self.searchController.active = YES;
        [self.searchController.searchBar becomeFirstResponder];
    });
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView;
    (void)section;
    return self.filteredTracks.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    M2TrackCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MusicTrackCell" forIndexPath:indexPath];

    M2PlaybackManager *playback = M2PlaybackManager.sharedManager;
    M2Track *track = self.filteredTracks[indexPath.row];
    M2Track *currentTrack = playback.currentTrack;
    BOOL isCurrent = (currentTrack != nil && [currentTrack.identifier isEqualToString:track.identifier]);
    BOOL sameQueue = M2TrackQueuesMatchByIdentifier(playback.currentQueue, self.tracks);
    BOOL showsPlaybackIndicator = (sameQueue && isCurrent && playback.isPlaying);

    [cell configureWithTrack:track isCurrent:isCurrent showsPlaybackIndicator:showsPlaybackIndicator];
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.row >= self.filteredTracks.count) {
        return;
    }

    NSArray<M2Track *> *playlistQueue = self.tracks;
    if (playlistQueue.count == 0) {
        return;
    }

    M2Track *selectedTrack = self.filteredTracks[indexPath.row];
    NSInteger playlistIndex = M2IndexOfTrackByIdentifier(playlistQueue, selectedTrack.identifier);
    if (playlistIndex == NSNotFound) {
        return;
    }

    M2PlaybackManager *playback = M2PlaybackManager.sharedManager;
    M2Track *currentTrack = playback.currentTrack;
    BOOL sameTrack = (currentTrack != nil && [currentTrack.identifier isEqualToString:selectedTrack.identifier]);
    BOOL sameQueue = M2TrackQueuesMatchByIdentifier(playback.currentQueue, playlistQueue);
    if (sameTrack && sameQueue) {
        [self openPlayer];
        return;
    }

    [playback setShuffleEnabled:NO];
    [playback playTracks:playlistQueue startIndex:playlistIndex];
    [self openPlayer];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView;
    if (indexPath.row >= self.filteredTracks.count) {
        return [UISwipeActionsConfiguration configurationWithActions:@[]];
    }

    M2Track *track = self.filteredTracks[indexPath.row];

    UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                               title:@"Delete"
                                                                             handler:^(__unused UIContextualAction * _Nonnull action,
                                                                                       __unused UIView * _Nonnull sourceView,
                                                                                       void (^ _Nonnull completionHandler)(BOOL)) {
        NSError *deleteError = nil;
        BOOL removed = [M2LibraryManager.sharedManager deleteTrackWithIdentifier:track.identifier error:&deleteError];
        if (!removed) {
            NSString *message = deleteError.localizedDescription ?: @"Could not delete track file.";
            M2PresentAlert(self, @"Delete Failed", message);
            completionHandler(NO);
            return;
        }

        [M2FavoritesStore.sharedStore setTrackID:track.identifier favorite:NO];
        [M2PlaylistStore.sharedStore removeTrackIDFromAllPlaylists:track.identifier];
        [self reloadTracks];
        completionHandler(YES);
    }];
    deleteAction.image = [UIImage systemImageNamed:@"trash.fill"];

    UIContextualAction *addAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                            title:@"Add"
                                                                          handler:^(__unused UIContextualAction * _Nonnull action,
                                                                                    __unused UIView * _Nonnull sourceView,
                                                                                    void (^ _Nonnull completionHandler)(BOOL)) {
        M2PresentQuickAddTrackToPlaylist(self, track.identifier, nil);
        completionHandler(YES);
    }];
    addAction.image = [UIImage systemImageNamed:@"text.badge.plus"];
    addAction.backgroundColor = [UIColor colorWithRed:0.16 green:0.47 blue:0.95 alpha:1.0];

    UISwipeActionsConfiguration *configuration = [UISwipeActionsConfiguration configurationWithActions:@[deleteAction, addAction]];
    configuration.performsFirstActionWithFullSwipe = NO;
    return configuration;
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
leadingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView;
    if (indexPath.row >= self.filteredTracks.count) {
        return [UISwipeActionsConfiguration configurationWithActions:@[]];
    }

    M2Track *track = self.filteredTracks[indexPath.row];
    BOOL isFavorite = [M2FavoritesStore.sharedStore isTrackFavoriteByID:track.identifier];
    NSString *iconName = isFavorite ? @"heart.slash.fill" : @"heart.fill";
    UIColor *backgroundColor = isFavorite
    ? [UIColor colorWithWhite:0.40 alpha:1.0]
    : [UIColor colorWithRed:1.0 green:0.35 blue:0.42 alpha:1.0];

    UIContextualAction *favoriteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                                  title:nil
                                                                                handler:^(__unused UIContextualAction * _Nonnull action,
                                                                                          __unused UIView * _Nonnull sourceView,
                                                                                          void (^ _Nonnull completionHandler)(BOOL)) {
        [M2FavoritesStore.sharedStore setTrackID:track.identifier favorite:!isFavorite];
        [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
        completionHandler(YES);
    }];
    favoriteAction.image = [UIImage systemImageNamed:iconName];
    favoriteAction.backgroundColor = backgroundColor;

    UISwipeActionsConfiguration *configuration = [UISwipeActionsConfiguration configurationWithActions:@[favoriteAction]];
    configuration.performsFirstActionWithFullSwipe = YES;
    return configuration;
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    self.searchQuery = searchController.searchBar.text ?: @"";
    [self applySearchFilterAndReload];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView == self.tableView) {
        [self updateSearchControllerAttachment];
    }
}

@end

#pragma mark - Playlists

@interface M2PlaylistsViewController () <UITableViewDataSource, UITableViewDelegate, UISearchResultsUpdating>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, copy) NSArray<M2Playlist *> *playlists;
@property (nonatomic, copy) NSArray<M2Playlist *> *filteredPlaylists;
@property (nonatomic, copy) NSString *searchQuery;
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, assign) BOOL searchControllerAttached;
@property (nonatomic, assign) BOOL syncingLovelyPlaylist;
@property (nonatomic, assign) BOOL needsLovelyRefresh;

@end

@implementation M2PlaylistsViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = nil;
    self.navigationItem.title = nil;
    self.navigationItem.titleView = nil;
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:M2WhiteSectionTitleLabel(@"Playlists")];
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    self.view.backgroundColor = UIColor.systemBackgroundColor;

    [self setupTableView];
    [self setupSearch];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                                             target:self
                                                                                             action:@selector(addPlaylistTapped)];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(reloadPlaylists)
                                               name:M2PlaylistsDidChangeNotification
                                             object:nil];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(reloadPlaylists)
                                               name:UIApplicationWillEnterForegroundNotification
                                             object:nil];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(reloadPlaylists)
                                               name:M2FavoritesDidChangeNotification
                                             object:nil];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(markNeedsLovelyRefresh)
                                               name:M2PlaybackStateDidChangeNotification
                                             object:nil];

    self.needsLovelyRefresh = YES;
    [self reloadPlaylists];
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationItem.title = nil;
    self.navigationItem.titleView = nil;
    if (self.needsLovelyRefresh) {
        [self reloadPlaylists];
    }
    [self updateSearchControllerAttachment];
    [self.tableView reloadData];
}

- (void)markNeedsLovelyRefresh {
    self.needsLovelyRefresh = YES;
}

- (void)setupTableView {
    UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    tableView.translatesAutoresizingMaskIntoConstraints = NO;
    tableView.dataSource = self;
    tableView.delegate = self;
    tableView.rowHeight = 56.0;
    tableView.alwaysBounceVertical = YES;
    tableView.sectionHeaderHeight = 0.0;
    tableView.sectionFooterHeight = 0.0;
    tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    if (@available(iOS 15.0, *)) {
        tableView.sectionHeaderTopPadding = 0.0;
    }
    [tableView registerClass:M2PlaylistCell.class forCellReuseIdentifier:@"PlaylistCell"];

    self.tableView = tableView;
    [self.view addSubview:tableView];

    [NSLayoutConstraint activateConstraints:@[
        [tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)setupSearch {
    self.searchController = M2BuildSearchController(self, @"Search Playlists");
    self.navigationItem.searchController = nil;
    self.navigationItem.hidesSearchBarWhenScrolling = YES;
    self.definesPresentationContext = YES;
    self.searchControllerAttached = NO;
}

- (void)updateSearchControllerAttachment {
    BOOL shouldAttach = M2ShouldAttachSearchController(self.searchControllerAttached,
                                                       self.searchController,
                                                       self.tableView,
                                                       M2SearchRevealThreshold);
    if (shouldAttach == self.searchControllerAttached) {
        return;
    }

    self.searchControllerAttached = shouldAttach;
    M2ApplySearchControllerAttachment(self.navigationItem,
                                      self.navigationController.navigationBar,
                                      self.searchController,
                                      shouldAttach,
                                      (self.view.window != nil));
}

- (void)applySearchFilterAndReload {
    self.filteredPlaylists = M2FilterPlaylistsByQuery(self.playlists, self.searchQuery);
    [self.tableView reloadData];
    [self updateEmptyState];
}

- (void)updateEmptyState {
    if (self.filteredPlaylists.count > 0) {
        self.tableView.backgroundView = nil;
        return;
    }

    UILabel *label = [[UILabel alloc] init];
    label.textColor = UIColor.secondaryLabelColor;
    label.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 0;
    if (self.playlists.count == 0) {
        label.text = @"Tap + to create a playlist";
    } else {
        label.text = @"No matching playlists.";
    }
    self.tableView.backgroundView = label;
}

- (void)addPlaylistTapped {
    M2PlaylistNameViewController *nameVC = [[M2PlaylistNameViewController alloc] init];
    nameVC.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:nameVC animated:YES];
}

- (NSArray<NSString *> *)lovelyTrackIDsFromLibraryTracks:(NSArray<M2Track *> *)libraryTracks {
    if (libraryTracks.count == 0) {
        return @[];
    }

    NSMutableArray<NSString *> *trackIDs = [NSMutableArray arrayWithCapacity:libraryTracks.count];
    for (M2Track *track in libraryTracks) {
        if (track.identifier.length > 0) {
            [trackIDs addObject:track.identifier];
        }
    }
    if (trackIDs.count == 0) {
        return @[];
    }

    NSDictionary<NSString *, NSDictionary<NSString *, NSNumber *> *> *analyticsByTrackID =
    [M2TrackAnalyticsStore.sharedStore analyticsByTrackIDForTrackIDs:trackIDs];
    M2FavoritesStore *favoritesStore = M2FavoritesStore.sharedStore;

    NSMutableArray<M2Track *> *eligibleTracks = [NSMutableArray array];
    for (M2Track *track in libraryTracks) {
        NSDictionary<NSString *, NSNumber *> *metrics = analyticsByTrackID[track.identifier] ?: @{};
        NSInteger playCount = [metrics[@"playCount"] integerValue];
        NSInteger skipCount = [metrics[@"skipCount"] integerValue];
        double score = [metrics[@"score"] doubleValue];
        NSInteger activity = playCount + skipCount;
        BOOL isFavorite = [favoritesStore isTrackFavoriteByID:track.identifier];

        // Rule:
        // (playCount + skipCount) >= 3
        // AND ((isFavorite && score >= 0.60 && playCount >= 2) || (score >= 0.80 && playCount >= 4))
        // AND skipCount <= 3
        BOOL matchesFavoriteRule = (isFavorite && score >= 0.60 && playCount >= 2);
        BOOL matchesHighScoreRule = (score >= 0.80 && playCount >= 4);
        if (activity < 3 || skipCount > 3 || !(matchesFavoriteRule || matchesHighScoreRule)) {
            continue;
        }

        [eligibleTracks addObject:track];
    }

    if (eligibleTracks.count == 0) {
        return @[];
    }

    [eligibleTracks sortUsingComparator:^NSComparisonResult(M2Track * _Nonnull left, M2Track * _Nonnull right) {
        NSDictionary<NSString *, NSNumber *> *leftMetrics = analyticsByTrackID[left.identifier] ?: @{};
        NSDictionary<NSString *, NSNumber *> *rightMetrics = analyticsByTrackID[right.identifier] ?: @{};

        NSInteger leftPlay = [leftMetrics[@"playCount"] integerValue];
        NSInteger rightPlay = [rightMetrics[@"playCount"] integerValue];
        NSInteger leftSkip = [leftMetrics[@"skipCount"] integerValue];
        NSInteger rightSkip = [rightMetrics[@"skipCount"] integerValue];

        double leftScore = [leftMetrics[@"score"] doubleValue];
        double rightScore = [rightMetrics[@"score"] doubleValue];
        BOOL leftFavorite = [favoritesStore isTrackFavoriteByID:left.identifier];
        BOOL rightFavorite = [favoritesStore isTrackFavoriteByID:right.identifier];

        if (leftScore > rightScore) {
            return NSOrderedAscending;
        }
        if (leftScore < rightScore) {
            return NSOrderedDescending;
        }
        if (leftPlay > rightPlay) {
            return NSOrderedAscending;
        }
        if (leftPlay < rightPlay) {
            return NSOrderedDescending;
        }
        if (leftSkip < rightSkip) {
            return NSOrderedAscending;
        }
        if (leftSkip > rightSkip) {
            return NSOrderedDescending;
        }
        if (leftFavorite != rightFavorite) {
            return leftFavorite ? NSOrderedAscending : NSOrderedDescending;
        }

        NSString *leftTitle = left.title.length > 0 ? left.title : left.fileName;
        NSString *rightTitle = right.title.length > 0 ? right.title : right.fileName;
        return [leftTitle localizedCaseInsensitiveCompare:rightTitle];
    }];

    NSMutableArray<NSString *> *orderedIDs = [NSMutableArray arrayWithCapacity:eligibleTracks.count];
    for (M2Track *track in eligibleTracks) {
        if (track.identifier.length > 0) {
            [orderedIDs addObject:track.identifier];
        }
    }
    return [orderedIDs copy];
}

- (void)syncLovelyPlaylistIfNeeded {
    NSArray<M2Track *> *libraryTracks = M2LibraryManager.sharedManager.tracks;
    if (libraryTracks.count == 0) {
        libraryTracks = [M2LibraryManager.sharedManager reloadTracks];
    }
    NSArray<NSString *> *lovelyTrackIDs = [self lovelyTrackIDsFromLibraryTracks:libraryTracks];

    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSString *storedPlaylistID = [defaults stringForKey:M2LovelyPlaylistDefaultsKey];

    M2PlaylistStore *store = M2PlaylistStore.sharedStore;
    M2Playlist *lovelyPlaylist = (storedPlaylistID.length > 0)
    ? [store playlistWithID:storedPlaylistID]
    : nil;
    if (lovelyPlaylist == nil) {
        for (M2Playlist *playlist in store.playlists) {
            if ([playlist.name localizedCaseInsensitiveCompare:@"Lovely songs"] == NSOrderedSame) {
                lovelyPlaylist = playlist;
                [defaults setObject:playlist.playlistID forKey:M2LovelyPlaylistDefaultsKey];
                break;
            }
        }
    }

    if (lovelyPlaylist == nil) {
        [defaults removeObjectForKey:M2LovelyPlaylistDefaultsKey];
        [defaults removeObjectForKey:M2LovelyPlaylistCoverMarkerKey];
        if (lovelyTrackIDs.count == 0) {
            return;
        }

        UIImage *coverImage = M2LovelySongsCoverImage(CGSizeMake(768.0, 768.0));
        M2Playlist *created = [store addPlaylistWithName:@"Lovely songs"
                                                trackIDs:lovelyTrackIDs
                                              coverImage:coverImage];
        if (created != nil) {
            [defaults setObject:created.playlistID forKey:M2LovelyPlaylistDefaultsKey];
            [defaults setObject:created.playlistID forKey:M2LovelyPlaylistCoverMarkerKey];
        }
        return;
    }

    if (![lovelyPlaylist.name isEqualToString:@"Lovely songs"]) {
        [store renamePlaylistWithID:lovelyPlaylist.playlistID newName:@"Lovely songs"];
    }

    if (![lovelyPlaylist.trackIDs isEqualToArray:lovelyTrackIDs]) {
        [store replaceTrackIDs:lovelyTrackIDs forPlaylistID:lovelyPlaylist.playlistID];
    }

    NSString *coverMarker = [defaults stringForKey:M2LovelyPlaylistCoverMarkerKey];
    BOOL shouldRefreshCover = (lovelyPlaylist.customCoverFileName.length == 0 ||
                               ![coverMarker isEqualToString:lovelyPlaylist.playlistID]);
    if (shouldRefreshCover) {
        UIImage *coverImage = M2LovelySongsCoverImage(CGSizeMake(768.0, 768.0));
        BOOL coverSet = [store setCustomCoverImage:coverImage forPlaylistID:lovelyPlaylist.playlistID];
        if (coverSet) {
            [defaults setObject:lovelyPlaylist.playlistID forKey:M2LovelyPlaylistCoverMarkerKey];
        }
    }
}

- (void)reloadPlaylists {
    if (self.syncingLovelyPlaylist) {
        return;
    }

    self.syncingLovelyPlaylist = YES;
    @try {
        M2PlaylistStore *store = M2PlaylistStore.sharedStore;
        [store reloadPlaylists];
        [self syncLovelyPlaylistIfNeeded];
        [store reloadPlaylists];

        NSMutableArray<M2Playlist *> *orderedPlaylists = [store.playlists mutableCopy];
        NSString *lovelyID = [NSUserDefaults.standardUserDefaults stringForKey:M2LovelyPlaylistDefaultsKey];
        if (lovelyID.length > 0) {
            NSUInteger index = [orderedPlaylists indexOfObjectPassingTest:^BOOL(M2Playlist * _Nonnull playlist, __unused NSUInteger idx, __unused BOOL * _Nonnull stop) {
                return [playlist.playlistID isEqualToString:lovelyID];
            }];
            if (index != NSNotFound) {
                M2Playlist *lovely = orderedPlaylists[index];
                if (lovely.trackIDs.count == 0) {
                    [orderedPlaylists removeObjectAtIndex:index];
                } else if (index != 0) {
                    [orderedPlaylists removeObjectAtIndex:index];
                    [orderedPlaylists insertObject:lovely atIndex:0];
                }
            }
        }

        self.playlists = [orderedPlaylists copy];
        [self applySearchFilterAndReload];
    } @finally {
        self.needsLovelyRefresh = NO;
        self.syncingLovelyPlaylist = NO;
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView;
    (void)section;
    return self.filteredPlaylists.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    M2PlaylistCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PlaylistCell" forIndexPath:indexPath];

    M2Playlist *playlist = self.filteredPlaylists[indexPath.row];
    UIImage *cover = [M2PlaylistStore.sharedStore coverForPlaylist:playlist
                                                           library:M2LibraryManager.sharedManager
                                                              size:CGSizeMake(160.0, 160.0)];
    NSString *subtitle = [NSString stringWithFormat:@"%ld tracks", (long)playlist.trackIDs.count];
    NSString *lovelyID = [NSUserDefaults.standardUserDefaults stringForKey:M2LovelyPlaylistDefaultsKey];
    if (lovelyID.length > 0 && [playlist.playlistID isEqualToString:lovelyID]) {
        subtitle = @"";
    }

    [cell configureWithName:playlist.name subtitle:subtitle artwork:cover];
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.row >= self.filteredPlaylists.count) {
        return;
    }
    M2Playlist *playlist = self.filteredPlaylists[indexPath.row];
    M2PlaylistDetailViewController *detail = [[M2PlaylistDetailViewController alloc] initWithPlaylistID:playlist.playlistID];
    [self.navigationController pushViewController:detail animated:YES];
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    self.searchQuery = searchController.searchBar.text ?: @"";
    [self applySearchFilterAndReload];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView == self.tableView) {
        [self updateSearchControllerAttachment];
    }
}

@end

#pragma mark - Favorites

@interface M2FavoritesViewController () <UITableViewDataSource, UITableViewDelegate, UISearchResultsUpdating>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, copy) NSArray<M2Track *> *tracks;
@property (nonatomic, copy) NSArray<M2Track *> *filteredTracks;
@property (nonatomic, copy) NSString *searchQuery;
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, assign) BOOL searchControllerAttached;

@end

@implementation M2FavoritesViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Favorites";
    self.navigationItem.title = nil;
    self.navigationItem.titleView = nil;
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:M2WhiteSectionTitleLabel(@"Favorites")];
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"magnifyingglass"]
                                                                               style:UIBarButtonItemStylePlain
                                                                              target:self
                                                                              action:@selector(searchButtonTapped)];

    [self setupTableView];
    [self setupSearch];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(reloadFavorites)
                                               name:M2FavoritesDidChangeNotification
                                             object:nil];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(handlePlaybackChanged)
                                               name:M2PlaybackStateDidChangeNotification
                                             object:nil];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(handleAppForeground)
                                               name:UIApplicationWillEnterForegroundNotification
                                             object:nil];

    [self reloadFavorites];
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self updateSearchControllerAttachment];
    [self.tableView reloadData];
}

- (void)setupTableView {
    UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    tableView.translatesAutoresizingMaskIntoConstraints = NO;
    tableView.dataSource = self;
    tableView.delegate = self;
    tableView.rowHeight = 54.0;
    tableView.alwaysBounceVertical = YES;
    tableView.sectionHeaderHeight = 0.0;
    tableView.sectionFooterHeight = 0.0;
    tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    if (@available(iOS 15.0, *)) {
        tableView.sectionHeaderTopPadding = 0.0;
    }
    [tableView registerClass:M2TrackCell.class forCellReuseIdentifier:@"FavoriteTrackCell"];

    self.tableView = tableView;
    [self.view addSubview:tableView];

    [NSLayoutConstraint activateConstraints:@[
        [tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)setupSearch {
    self.searchController = M2BuildSearchController(self, @"Search Favorites");
    self.navigationItem.searchController = nil;
    self.navigationItem.hidesSearchBarWhenScrolling = YES;
    self.definesPresentationContext = YES;
    self.searchControllerAttached = NO;
}

- (void)updateSearchControllerAttachment {
    BOOL shouldAttach = M2ShouldAttachSearchController(self.searchControllerAttached,
                                                       self.searchController,
                                                       self.tableView,
                                                       M2SearchRevealThreshold);
    if (shouldAttach == self.searchControllerAttached) {
        return;
    }

    self.searchControllerAttached = shouldAttach;
    M2ApplySearchControllerAttachment(self.navigationItem,
                                      self.navigationController.navigationBar,
                                      self.searchController,
                                      shouldAttach,
                                      (self.view.window != nil));
}

- (void)applySearchFilterAndReload {
    self.filteredTracks = M2FilterTracksByQuery(self.tracks, self.searchQuery);
    [self.tableView reloadData];
    [self updateEmptyState];
}

- (void)updateEmptyState {
    if (self.filteredTracks.count > 0) {
        self.tableView.backgroundView = nil;
        return;
    }

    UILabel *label = [[UILabel alloc] init];
    label.textColor = UIColor.secondaryLabelColor;
    label.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
    label.numberOfLines = 0;
    label.textAlignment = NSTextAlignmentCenter;
    if (self.tracks.count == 0) {
        label.text = @"No favorites yet.\nTap heart in player to add tracks.";
    } else {
        label.text = @"No search results.";
    }
    self.tableView.backgroundView = label;
}

- (void)reloadFavorites {
    if (M2LibraryManager.sharedManager.tracks.count == 0 &&
        M2FavoritesStore.sharedStore.favoriteTrackIDs.count > 0) {
        [M2LibraryManager.sharedManager reloadTracks];
    }

    self.tracks = [M2FavoritesStore.sharedStore favoriteTracksWithLibrary:M2LibraryManager.sharedManager];
    [self applySearchFilterAndReload];
}

- (void)handleAppForeground {
    [M2LibraryManager.sharedManager reloadTracks];
    [self reloadFavorites];
}

- (void)handlePlaybackChanged {
    [self.tableView reloadData];
}

- (void)openPlayer {
    M2PlayerViewController *player = [[M2PlayerViewController alloc] init];
    player.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:player animated:YES];
}

- (void)searchButtonTapped {
    if (self.searchController == nil) {
        return;
    }

    if (!self.searchControllerAttached) {
        self.searchControllerAttached = YES;
        M2ApplySearchControllerAttachment(self.navigationItem,
                                          self.navigationController.navigationBar,
                                          self.searchController,
                                          YES,
                                          (self.view.window != nil));
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        self.searchController.active = YES;
        [self.searchController.searchBar becomeFirstResponder];
    });
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView;
    (void)section;
    return self.filteredTracks.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    M2TrackCell *cell = [tableView dequeueReusableCellWithIdentifier:@"FavoriteTrackCell" forIndexPath:indexPath];

    M2PlaybackManager *playback = M2PlaybackManager.sharedManager;
    M2Track *track = self.filteredTracks[indexPath.row];
    M2Track *currentTrack = playback.currentTrack;
    BOOL isCurrent = (currentTrack != nil && [currentTrack.identifier isEqualToString:track.identifier]);
    BOOL showsPlaybackIndicator = (isCurrent && playback.isPlaying);
    [cell configureWithTrack:track isCurrent:isCurrent showsPlaybackIndicator:showsPlaybackIndicator];

    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row >= self.filteredTracks.count) {
        return;
    }

    M2Track *selectedTrack = self.filteredTracks[indexPath.row];
    M2Track *currentTrack = M2PlaybackManager.sharedManager.currentTrack;
    if (currentTrack != nil && [currentTrack.identifier isEqualToString:selectedTrack.identifier]) {
        [self openPlayer];
        return;
    }

    [M2PlaybackManager.sharedManager setShuffleEnabled:NO];
    [M2PlaybackManager.sharedManager playTracks:self.filteredTracks startIndex:indexPath.row];
    [self openPlayer];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView;
    if (indexPath.row >= self.filteredTracks.count) {
        return [UISwipeActionsConfiguration configurationWithActions:@[]];
    }

    M2Track *track = self.filteredTracks[indexPath.row];

    UIContextualAction *removeAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                                title:@"Unfav"
                                                                              handler:^(__unused UIContextualAction * _Nonnull action,
                                                                                        __unused UIView * _Nonnull sourceView,
                                                                                        void (^ _Nonnull completionHandler)(BOOL)) {
        [M2FavoritesStore.sharedStore setTrackID:track.identifier favorite:NO];
        [self reloadFavorites];
        completionHandler(YES);
    }];
    removeAction.image = [UIImage systemImageNamed:@"heart.slash.fill"];

    UIContextualAction *addAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                            title:@"Add"
                                                                          handler:^(__unused UIContextualAction * _Nonnull action,
                                                                                    __unused UIView * _Nonnull sourceView,
                                                                                    void (^ _Nonnull completionHandler)(BOOL)) {
        M2PresentQuickAddTrackToPlaylist(self, track.identifier, nil);
        completionHandler(YES);
    }];
    addAction.image = [UIImage systemImageNamed:@"text.badge.plus"];
    addAction.backgroundColor = [UIColor colorWithRed:0.16 green:0.47 blue:0.95 alpha:1.0];

    UISwipeActionsConfiguration *configuration = [UISwipeActionsConfiguration configurationWithActions:@[removeAction, addAction]];
    configuration.performsFirstActionWithFullSwipe = NO;
    return configuration;
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
leadingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView;
    if (indexPath.row >= self.filteredTracks.count) {
        return [UISwipeActionsConfiguration configurationWithActions:@[]];
    }

    M2Track *track = self.filteredTracks[indexPath.row];
    UIContextualAction *favoriteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                                  title:nil
                                                                                handler:^(__unused UIContextualAction * _Nonnull action,
                                                                                          __unused UIView * _Nonnull sourceView,
                                                                                          void (^ _Nonnull completionHandler)(BOOL)) {
        [M2FavoritesStore.sharedStore setTrackID:track.identifier favorite:NO];
        [self reloadFavorites];
        completionHandler(YES);
    }];
    favoriteAction.image = [UIImage systemImageNamed:@"heart.slash.fill"];
    favoriteAction.backgroundColor = [UIColor colorWithWhite:0.40 alpha:1.0];

    UISwipeActionsConfiguration *configuration = [UISwipeActionsConfiguration configurationWithActions:@[favoriteAction]];
    configuration.performsFirstActionWithFullSwipe = YES;
    return configuration;
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    self.searchQuery = searchController.searchBar.text ?: @"";
    [self applySearchFilterAndReload];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView == self.tableView) {
        [self updateSearchControllerAttachment];
    }
}

@end

#pragma mark - Playlist Name Step

@interface M2PlaylistNameViewController () <UITextFieldDelegate>

@property (nonatomic, strong) UITextField *nameField;
@property (nonatomic, strong) UIButton *nextButton;
@property (nonatomic, strong) UILabel *counterLabel;

@end

@implementation M2PlaylistNameViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Create Playlist";
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    self.view.backgroundColor = UIColor.systemBackgroundColor;

    [self setupUI];
    [self updateNameUI];
}

- (void)setupUI {
    UIScrollView *scrollView = [[UIScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    [self.view addSubview:scrollView];

    UIView *content = [[UIView alloc] init];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [scrollView addSubview:content];

    UIView *heroCard = [[UIView alloc] init];
    heroCard.translatesAutoresizingMaskIntoConstraints = NO;
    heroCard.backgroundColor = UIColor.clearColor;

    UILabel *heroTitle = [[UILabel alloc] init];
    heroTitle.translatesAutoresizingMaskIntoConstraints = NO;
    heroTitle.text = @"Name Your Playlist";
    heroTitle.font = [UIFont systemFontOfSize:30.0 weight:UIFontWeightBold];
    heroTitle.textColor = UIColor.labelColor;
    heroTitle.numberOfLines = 1;

    [heroCard addSubview:heroTitle];

    UIView *inputCard = [[UIView alloc] init];
    inputCard.translatesAutoresizingMaskIntoConstraints = NO;
    inputCard.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull trait) {
        if (trait.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithWhite:1.0 alpha:0.06];
        }
        return [UIColor colorWithWhite:0.0 alpha:0.03];
    }];
    inputCard.layer.cornerRadius = 18.0;
    inputCard.layer.borderWidth = 1.0;
    inputCard.layer.borderColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull trait) {
        if (trait.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithWhite:1.0 alpha:0.14];
        }
        return [UIColor colorWithWhite:0.0 alpha:0.08];
    }].CGColor;

    UILabel *inputTitle = [[UILabel alloc] init];
    inputTitle.translatesAutoresizingMaskIntoConstraints = NO;
    inputTitle.text = @"Playlist Name";
    inputTitle.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    inputTitle.textColor = UIColor.secondaryLabelColor;

    UITextField *nameField = [[UITextField alloc] init];
    nameField.translatesAutoresizingMaskIntoConstraints = NO;
    nameField.borderStyle = UITextBorderStyleNone;
    nameField.placeholder = @"Example: Late Night Drive";
    nameField.returnKeyType = UIReturnKeyNext;
    nameField.clearButtonMode = UITextFieldViewModeWhileEditing;
    nameField.delegate = self;
    nameField.font = [UIFont systemFontOfSize:20.0 weight:UIFontWeightSemibold];
    nameField.textColor = UIColor.labelColor;
    [nameField addTarget:self action:@selector(nameDidChange) forControlEvents:UIControlEventEditingChanged];
    self.nameField = nameField;

    UILabel *counterLabel = [[UILabel alloc] init];
    counterLabel.translatesAutoresizingMaskIntoConstraints = NO;
    counterLabel.font = [UIFont monospacedDigitSystemFontOfSize:12.0 weight:UIFontWeightSemibold];
    counterLabel.textColor = UIColor.secondaryLabelColor;
    counterLabel.textAlignment = NSTextAlignmentRight;
    self.counterLabel = counterLabel;

    [inputCard addSubview:inputTitle];
    [inputCard addSubview:nameField];
    [inputCard addSubview:counterLabel];

    UIButton *nextButton = [UIButton buttonWithType:UIButtonTypeSystem];
    nextButton.translatesAutoresizingMaskIntoConstraints = NO;
    [nextButton setTitle:@"Next: Choose Music" forState:UIControlStateNormal];
    [nextButton setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    nextButton.titleLabel.font = [UIFont systemFontOfSize:18.0 weight:UIFontWeightBold];
    nextButton.layer.cornerRadius = 14.0;
    [nextButton addTarget:self action:@selector(nextTapped) forControlEvents:UIControlEventTouchUpInside];
    self.nextButton = nextButton;

    [content addSubview:heroCard];
    [content addSubview:inputCard];
    [self.view addSubview:nextButton];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    NSMutableArray<NSLayoutConstraint *> *constraints = [NSMutableArray arrayWithArray:@[
        [scrollView.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [scrollView.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:nextButton.topAnchor constant:-12.0],

        [content.topAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.topAnchor],
        [content.leadingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.trailingAnchor],
        [content.bottomAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.bottomAnchor],
        [content.widthAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.widthAnchor],

        [heroCard.topAnchor constraintEqualToAnchor:content.topAnchor constant:16.0],
        [heroCard.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:16.0],
        [heroCard.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-16.0],
        [heroCard.heightAnchor constraintEqualToConstant:58.0],

        [heroTitle.topAnchor constraintEqualToAnchor:heroCard.topAnchor constant:8.0],
        [heroTitle.leadingAnchor constraintEqualToAnchor:heroCard.leadingAnchor constant:14.0],
        [heroTitle.trailingAnchor constraintEqualToAnchor:heroCard.trailingAnchor constant:-14.0],

        [inputCard.topAnchor constraintEqualToAnchor:heroCard.bottomAnchor constant:10.0],
        [inputCard.leadingAnchor constraintEqualToAnchor:heroCard.leadingAnchor],
        [inputCard.trailingAnchor constraintEqualToAnchor:heroCard.trailingAnchor],
        [inputCard.heightAnchor constraintEqualToConstant:118.0],

        [inputTitle.topAnchor constraintEqualToAnchor:inputCard.topAnchor constant:14.0],
        [inputTitle.leadingAnchor constraintEqualToAnchor:inputCard.leadingAnchor constant:14.0],
        [inputTitle.trailingAnchor constraintEqualToAnchor:inputCard.trailingAnchor constant:-14.0],

        [nameField.topAnchor constraintEqualToAnchor:inputTitle.bottomAnchor constant:8.0],
        [nameField.leadingAnchor constraintEqualToAnchor:inputTitle.leadingAnchor],
        [nameField.trailingAnchor constraintEqualToAnchor:inputTitle.trailingAnchor],
        [nameField.heightAnchor constraintEqualToConstant:42.0],

        [counterLabel.trailingAnchor constraintEqualToAnchor:nameField.trailingAnchor],
        [counterLabel.bottomAnchor constraintEqualToAnchor:inputCard.bottomAnchor constant:-10.0],
        [counterLabel.widthAnchor constraintEqualToConstant:62.0],

        [content.bottomAnchor constraintEqualToAnchor:inputCard.bottomAnchor constant:24.0],

        [nextButton.leadingAnchor constraintEqualToAnchor:inputCard.leadingAnchor],
        [nextButton.trailingAnchor constraintEqualToAnchor:inputCard.trailingAnchor],
        [nextButton.heightAnchor constraintEqualToConstant:52.0]
    ]];

    if (@available(iOS 15.0, *)) {
        [constraints addObject:[nextButton.bottomAnchor constraintEqualToAnchor:self.view.keyboardLayoutGuide.topAnchor constant:-12.0]];
    } else {
        [constraints addObject:[nextButton.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-12.0]];
    }

    [NSLayoutConstraint activateConstraints:constraints];
}

- (void)nameDidChange {
    [self updateNameUI];
}

- (void)updateNameUI {
    NSString *trimmed = [self.nameField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSUInteger length = self.nameField.text.length;
    if (length > 32) {
        self.nameField.text = [self.nameField.text substringToIndex:32];
        length = 32;
    }

    self.counterLabel.text = [NSString stringWithFormat:@"%lu/32", (unsigned long)length];

    BOOL enabled = (trimmed.length > 0);
    self.nextButton.enabled = enabled;
    self.nextButton.alpha = enabled ? 1.0 : 0.45;
    self.nextButton.backgroundColor = enabled ? M2AccentYellowColor() : [UIColor colorWithWhite:0.65 alpha:0.4];
}

- (void)nextTapped {
    NSString *name = [self.nameField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (name.length == 0) {
        M2PresentAlert(self, @"Name Required", @"Enter playlist name.");
        return;
    }

    NSArray<M2Track *> *tracks = [M2LibraryManager.sharedManager reloadTracks];
    if (tracks.count == 0) {
        M2PresentAlert(self, @"No Music", @"Add music files in Files app first.");
        return;
    }

    M2PlaylistTrackPickerViewController *picker = [[M2PlaylistTrackPickerViewController alloc] initWithPlaylistName:name tracks:tracks];
    picker.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:picker animated:YES];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    (void)textField;
    [self nextTapped];
    return YES;
}

- (BOOL)textField:(UITextField *)textField
shouldChangeCharactersInRange:(NSRange)range
replacementString:(NSString *)string {
    NSString *current = textField.text ?: @"";
    NSString *updated = [current stringByReplacingCharactersInRange:range withString:string ?: @""];
    return (updated.length <= 32);
}

@end

#pragma mark - Playlist Track Step

@interface M2PlaylistTrackPickerViewController () <UITableViewDataSource, UITableViewDelegate, UISearchResultsUpdating>

@property (nonatomic, copy) NSString *playlistName;
@property (nonatomic, copy) NSArray<M2Track *> *tracks;
@property (nonatomic, copy) NSArray<M2Track *> *filteredTracks;
@property (nonatomic, strong) NSMutableSet<NSString *> *selectedTrackIDs;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, copy) NSString *searchQuery;
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, assign) BOOL searchControllerAttached;

@end

@implementation M2PlaylistTrackPickerViewController

- (instancetype)initWithPlaylistName:(NSString *)playlistName tracks:(NSArray<M2Track *> *)tracks {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _playlistName = [playlistName copy];
        _tracks = [[M2TrackAnalyticsStore.sharedStore tracksSortedByAffinity:tracks] copy];
        _filteredTracks = _tracks;
        _selectedTrackIDs = [NSMutableSet set];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Select Music";
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    self.view.backgroundColor = UIColor.systemBackgroundColor;

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Create"
                                                                               style:UIBarButtonItemStyleDone
                                                                              target:self
                                                                              action:@selector(createTapped)];

    [self setupTableView];
    [self setupSearch];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self updateSearchControllerAttachment];
}

- (void)setupTableView {
    UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    tableView.translatesAutoresizingMaskIntoConstraints = NO;
    tableView.dataSource = self;
    tableView.delegate = self;
    tableView.rowHeight = 54.0;
    tableView.alwaysBounceVertical = YES;
    tableView.sectionHeaderHeight = 0.0;
    tableView.sectionFooterHeight = 0.0;
    tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    if (@available(iOS 15.0, *)) {
        tableView.sectionHeaderTopPadding = 0.0;
    }
    [tableView registerClass:M2TrackCell.class forCellReuseIdentifier:@"TrackPickCell"];

    self.tableView = tableView;
    [self.view addSubview:tableView];

    [NSLayoutConstraint activateConstraints:@[
        [tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)setupSearch {
    self.searchController = M2BuildSearchController(self, @"Search Tracks");
    self.navigationItem.searchController = nil;
    self.navigationItem.hidesSearchBarWhenScrolling = YES;
    self.definesPresentationContext = YES;
    self.searchControllerAttached = NO;
}

- (void)updateSearchControllerAttachment {
    BOOL shouldAttach = M2ShouldAttachSearchController(self.searchControllerAttached,
                                                       self.searchController,
                                                       self.tableView,
                                                       M2SearchRevealThreshold);
    if (shouldAttach == self.searchControllerAttached) {
        return;
    }

    self.searchControllerAttached = shouldAttach;
    M2ApplySearchControllerAttachment(self.navigationItem,
                                      self.navigationController.navigationBar,
                                      self.searchController,
                                      shouldAttach,
                                      (self.view.window != nil));
}

- (void)applySearchFilterAndReload {
    self.filteredTracks = M2FilterTracksByQuery(self.tracks, self.searchQuery);
    [self.tableView reloadData];
}

- (void)createTapped {
    if (self.selectedTrackIDs.count == 0) {
        M2PresentAlert(self, @"No Music Selected", @"Select at least one track.");
        return;
    }

    NSMutableArray<NSString *> *orderedIDs = [NSMutableArray arrayWithCapacity:self.selectedTrackIDs.count];
    for (M2Track *track in self.tracks) {
        if ([self.selectedTrackIDs containsObject:track.identifier]) {
            [orderedIDs addObject:track.identifier];
        }
    }

    M2Playlist *playlist = [M2PlaylistStore.sharedStore addPlaylistWithName:self.playlistName
                                                                    trackIDs:orderedIDs
                                                                  coverImage:nil];
    if (playlist == nil) {
        M2PresentAlert(self, @"Error", @"Could not create playlist.");
        return;
    }

    M2PlaylistDetailViewController *detail = [[M2PlaylistDetailViewController alloc] initWithPlaylistID:playlist.playlistID];
    detail.hidesBottomBarWhenPushed = YES;
    UIViewController *root = self.navigationController.viewControllers.firstObject;
    if (root != nil) {
        [self.navigationController setViewControllers:@[root, detail] animated:YES];
    } else {
        [self.navigationController pushViewController:detail animated:YES];
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView;
    (void)section;
    return self.filteredTracks.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    M2TrackCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TrackPickCell" forIndexPath:indexPath];

    M2Track *track = self.filteredTracks[indexPath.row];
    BOOL selected = [self.selectedTrackIDs containsObject:track.identifier];
    [cell configureWithTrack:track isCurrent:selected];
    cell.accessoryType = selected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;

    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.row >= self.filteredTracks.count) {
        return;
    }
    M2Track *track = self.filteredTracks[indexPath.row];
    if ([self.selectedTrackIDs containsObject:track.identifier]) {
        [self.selectedTrackIDs removeObject:track.identifier];
    } else {
        [self.selectedTrackIDs addObject:track.identifier];
    }

    [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    self.searchQuery = searchController.searchBar.text ?: @"";
    [self applySearchFilterAndReload];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView == self.tableView) {
        [self updateSearchControllerAttachment];
    }
}

@end

#pragma mark - Playlist Add Tracks

@interface M2PlaylistAddTracksViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, copy) NSString *playlistID;
@property (nonatomic, copy) NSArray<M2Track *> *availableTracks;
@property (nonatomic, strong) NSMutableSet<NSString *> *selectedTrackIDs;
@property (nonatomic, strong) UITableView *tableView;

@end

@implementation M2PlaylistAddTracksViewController

- (instancetype)initWithPlaylistID:(NSString *)playlistID {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _playlistID = [playlistID copy];
        _availableTracks = @[];
        _selectedTrackIDs = [NSMutableSet set];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Add Music";
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    self.view.backgroundColor = UIColor.systemBackgroundColor;

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Add"
                                                                               style:UIBarButtonItemStyleDone
                                                                              target:self
                                                                              action:@selector(addTapped)];
    self.navigationItem.rightBarButtonItem.enabled = NO;

    [self setupTableView];
    [self reloadAvailableTracks];
}

- (void)setupTableView {
    UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    tableView.translatesAutoresizingMaskIntoConstraints = NO;
    tableView.dataSource = self;
    tableView.delegate = self;
    tableView.rowHeight = 54.0;
    tableView.alwaysBounceVertical = YES;
    tableView.sectionHeaderHeight = 0.0;
    tableView.sectionFooterHeight = 0.0;
    tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    if (@available(iOS 15.0, *)) {
        tableView.sectionHeaderTopPadding = 0.0;
    }
    [tableView registerClass:M2TrackCell.class forCellReuseIdentifier:@"PlaylistAddTrackCell"];

    self.tableView = tableView;
    [self.view addSubview:tableView];

    [NSLayoutConstraint activateConstraints:@[
        [tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)reloadAvailableTracks {
    [M2PlaylistStore.sharedStore reloadPlaylists];
    M2Playlist *playlist = [M2PlaylistStore.sharedStore playlistWithID:self.playlistID];
    if (playlist == nil) {
        [self.navigationController popViewControllerAnimated:YES];
        return;
    }

    NSArray<M2Track *> *libraryTracks = M2LibraryManager.sharedManager.tracks;
    if (libraryTracks.count == 0) {
        libraryTracks = [M2LibraryManager.sharedManager reloadTracks];
    }

    NSSet<NSString *> *existingIDs = [NSSet setWithArray:playlist.trackIDs ?: @[]];
    NSMutableArray<M2Track *> *filteredTracks = [NSMutableArray arrayWithCapacity:libraryTracks.count];
    for (M2Track *track in libraryTracks) {
        if (![existingIDs containsObject:track.identifier]) {
            [filteredTracks addObject:track];
        }
    }

    self.availableTracks = [filteredTracks copy];
    [self.selectedTrackIDs removeAllObjects];
    [self.tableView reloadData];
    [self updateAddButtonState];
    [self updateEmptyState];
}

- (void)updateAddButtonState {
    self.navigationItem.rightBarButtonItem.enabled = (self.selectedTrackIDs.count > 0);
}

- (void)updateEmptyState {
    if (self.availableTracks.count > 0) {
        self.tableView.backgroundView = nil;
        return;
    }

    UILabel *label = [[UILabel alloc] init];
    label.textAlignment = NSTextAlignmentCenter;
    label.textColor = UIColor.secondaryLabelColor;
    label.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
    label.numberOfLines = 2;

    if (M2LibraryManager.sharedManager.tracks.count == 0) {
        label.text = @"No tracks in library.";
    } else {
        label.text = @"All tracks are already in this playlist.";
    }

    self.tableView.backgroundView = label;
}

- (void)addTapped {
    if (self.selectedTrackIDs.count == 0) {
        return;
    }

    NSMutableArray<NSString *> *orderedIDs = [NSMutableArray arrayWithCapacity:self.selectedTrackIDs.count];
    for (M2Track *track in self.availableTracks) {
        if ([self.selectedTrackIDs containsObject:track.identifier]) {
            [orderedIDs addObject:track.identifier];
        }
    }

    BOOL added = [M2PlaylistStore.sharedStore addTrackIDs:orderedIDs toPlaylistID:self.playlistID];
    if (!added) {
        M2PresentAlert(self, @"Nothing Added", @"Selected tracks are already in this playlist.");
        return;
    }

    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView;
    (void)section;
    return self.availableTracks.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    M2TrackCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PlaylistAddTrackCell" forIndexPath:indexPath];

    M2Track *track = self.availableTracks[indexPath.row];
    BOOL selected = [self.selectedTrackIDs containsObject:track.identifier];
    [cell configureWithTrack:track isCurrent:selected];
    cell.accessoryType = selected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;

    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    M2Track *track = self.availableTracks[indexPath.row];
    if ([self.selectedTrackIDs containsObject:track.identifier]) {
        [self.selectedTrackIDs removeObject:track.identifier];
    } else {
        [self.selectedTrackIDs addObject:track.identifier];
    }

    [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    [self updateAddButtonState];
}

@end

#pragma mark - Playlist Cover Picker

@interface M2PlaylistCoverPickerViewController ()

@property (nonatomic, copy) NSString *playlistID;
@property (nonatomic, strong) UIImageView *previewView;

@end

@implementation M2PlaylistCoverPickerViewController

- (instancetype)initWithPlaylistID:(NSString *)playlistID {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _playlistID = [playlistID copy];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Change Playlist Cover";
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    self.view.backgroundColor = UIColor.systemBackgroundColor;

    [self setupUI];
    [self reloadPreview];
}

- (void)setupUI {
    UIImageView *previewView = [[UIImageView alloc] init];
    previewView.translatesAutoresizingMaskIntoConstraints = NO;
    previewView.contentMode = UIViewContentModeScaleAspectFill;
    previewView.layer.cornerRadius = 14.0;
    previewView.layer.masksToBounds = YES;
    self.previewView = previewView;

    UIButton *chooseButton = [UIButton buttonWithType:UIButtonTypeSystem];
    chooseButton.translatesAutoresizingMaskIntoConstraints = NO;
    [chooseButton setTitle:@"Choose Image" forState:UIControlStateNormal];
    chooseButton.titleLabel.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];
    [chooseButton addTarget:self action:@selector(chooseImageTapped) forControlEvents:UIControlEventTouchUpInside];

    UIButton *autoButton = [UIButton buttonWithType:UIButtonTypeSystem];
    autoButton.translatesAutoresizingMaskIntoConstraints = NO;
    [autoButton setTitle:@"Use Auto Cover" forState:UIControlStateNormal];
    autoButton.titleLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    [autoButton addTarget:self action:@selector(resetAutoCoverTapped) forControlEvents:UIControlEventTouchUpInside];

    UILabel *hintLabel = [[UILabel alloc] init];
    hintLabel.translatesAutoresizingMaskIntoConstraints = NO;
    hintLabel.text = @"Select an image from Gallery.\nThis changes playlist cover only.";
    hintLabel.textColor = UIColor.secondaryLabelColor;
    hintLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    hintLabel.textAlignment = NSTextAlignmentCenter;
    hintLabel.numberOfLines = 2;

    [self.view addSubview:previewView];
    [self.view addSubview:chooseButton];
    [self.view addSubview:autoButton];
    [self.view addSubview:hintLabel];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [previewView.topAnchor constraintEqualToAnchor:safe.topAnchor constant:20.0],
        [previewView.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor],
        [previewView.widthAnchor constraintEqualToConstant:220.0],
        [previewView.heightAnchor constraintEqualToConstant:220.0],

        [chooseButton.topAnchor constraintEqualToAnchor:previewView.bottomAnchor constant:20.0],
        [chooseButton.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor],

        [autoButton.topAnchor constraintEqualToAnchor:chooseButton.bottomAnchor constant:10.0],
        [autoButton.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor],

        [hintLabel.topAnchor constraintEqualToAnchor:autoButton.bottomAnchor constant:16.0],
        [hintLabel.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16.0],
        [hintLabel.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16.0]
    ]];
}

- (void)reloadPreview {
    [M2PlaylistStore.sharedStore reloadPlaylists];
    M2Playlist *playlist = [M2PlaylistStore.sharedStore playlistWithID:self.playlistID];
    if (playlist == nil) {
        [self.navigationController popViewControllerAnimated:YES];
        return;
    }

    self.previewView.image = [M2PlaylistStore.sharedStore coverForPlaylist:playlist
                                                                    library:M2LibraryManager.sharedManager
                                                                       size:CGSizeMake(320.0, 320.0)];
}

- (void)chooseImageTapped {
    PHPickerConfiguration *configuration = [[PHPickerConfiguration alloc] init];
    configuration.filter = [PHPickerFilter imagesFilter];
    configuration.selectionLimit = 1;

    PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:configuration];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)resetAutoCoverTapped {
    [M2PlaylistStore.sharedStore reloadPlaylists];
    M2Playlist *playlist = [M2PlaylistStore.sharedStore playlistWithID:self.playlistID];
    if (playlist == nil) {
        [self.navigationController popViewControllerAnimated:YES];
        return;
    }

    UIImage *autoCover = [self randomAutoCoverImageForPlaylist:playlist];
    BOOL success = [M2PlaylistStore.sharedStore setCustomCoverImage:autoCover forPlaylistID:self.playlistID];
    if (!success) {
        M2PresentAlert(self, @"Error", @"Could not reset cover.");
        return;
    }
    [self reloadPreview];
}

#pragma mark - PHPickerViewControllerDelegate

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    [picker dismissViewControllerAnimated:YES completion:nil];

    PHPickerResult *result = results.firstObject;
    if (result == nil) {
        return;
    }

    NSItemProvider *provider = result.itemProvider;
    if (![provider canLoadObjectOfClass:UIImage.class]) {
        M2PresentAlert(self, @"Error", @"Cannot read this image.");
        return;
    }

    __weak typeof(self) weakSelf = self;
    [provider loadObjectOfClass:UIImage.class
              completionHandler:^(id<NSItemProviderReading>  _Nullable object, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf == nil) {
                return;
            }

            if (error != nil || ![object isKindOfClass:UIImage.class]) {
                M2PresentAlert(strongSelf, @"Error", @"Cannot read this image.");
                return;
            }

            UIImage *image = (UIImage *)object;
            BOOL success = [M2PlaylistStore.sharedStore setCustomCoverImage:image forPlaylistID:strongSelf.playlistID];
            if (!success) {
                M2PresentAlert(strongSelf, @"Error", @"Could not set cover.");
                return;
            }

            [strongSelf reloadPreview];
        });
    }];
}

- (nullable UIImage *)randomAutoCoverImageForPlaylist:(M2Playlist *)playlist {
    if (playlist == nil) {
        return nil;
    }

    if (M2LibraryManager.sharedManager.tracks.count == 0) {
        [M2LibraryManager.sharedManager reloadTracks];
    }

    NSArray<M2Track *> *playlistTracks = [M2PlaylistStore.sharedStore tracksForPlaylist:playlist library:M2LibraryManager.sharedManager];
    if (playlistTracks.count == 0) {
        return nil;
    }

    NSMutableArray<M2Track *> *shuffledTracks = [playlistTracks mutableCopy];
    for (NSInteger i = shuffledTracks.count - 1; i > 0; i -= 1) {
        u_int32_t j = arc4random_uniform((u_int32_t)(i + 1));
        [shuffledTracks exchangeObjectAtIndex:i withObjectAtIndex:j];
    }

    NSUInteger limit = MIN((NSUInteger)4, shuffledTracks.count);
    NSMutableArray<NSString *> *randomTrackIDs = [NSMutableArray arrayWithCapacity:limit];
    for (NSUInteger index = 0; index < limit; index += 1) {
        M2Track *track = shuffledTracks[index];
        if (track.identifier.length > 0) {
            [randomTrackIDs addObject:track.identifier];
        }
    }

    if (randomTrackIDs.count == 0) {
        return nil;
    }

    M2Playlist *tempPlaylist = [[M2Playlist alloc] init];
    tempPlaylist.playlistID = @"m2-auto-cover-temp";
    tempPlaylist.name = playlist.name ?: @"Playlist";
    tempPlaylist.trackIDs = [randomTrackIDs copy];
    tempPlaylist.customCoverFileName = nil;

    return [M2PlaylistStore.sharedStore coverForPlaylist:tempPlaylist
                                                 library:M2LibraryManager.sharedManager
                                                    size:CGSizeMake(320.0, 320.0)];
}

@end

#pragma mark - Playlist Detail

@interface M2PlaylistDetailViewController () <UITableViewDataSource, UITableViewDelegate, UISearchResultsUpdating>

@property (nonatomic, copy) NSString *playlistID;
@property (nonatomic, strong, nullable) M2Playlist *playlist;
@property (nonatomic, copy) NSArray<M2Track *> *tracks;
@property (nonatomic, copy) NSArray<M2Track *> *filteredTracks;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIImageView *coverView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UIButton *sleepButton;
@property (nonatomic, strong) UIButton *shuffleButton;
@property (nonatomic, strong) UIButton *playButton;
@property (nonatomic, copy) NSString *searchQuery;
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, assign) BOOL compactTitleVisible;
@property (nonatomic, assign) BOOL searchControllerAttached;

@end

@implementation M2PlaylistDetailViewController

- (instancetype)initWithPlaylistID:(NSString *)playlistID {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _playlistID = [playlistID copy];
        _tracks = @[];
        _filteredTracks = @[];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.navigationItem.titleView = nil;
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    self.navigationItem.rightBarButtonItem = nil;
    self.view.backgroundColor = UIColor.systemBackgroundColor;

    [self setupTableView];
    [self setupSearch];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(reloadData)
                                               name:M2PlaylistsDidChangeNotification
                                             object:nil];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(handleAppForeground)
                                               name:UIApplicationWillEnterForegroundNotification
                                             object:nil];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(handlePlaybackChanged)
                                               name:M2PlaybackStateDidChangeNotification
                                             object:nil];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(updateSleepButton)
                                               name:M2SleepTimerDidChangeNotification
                                             object:nil];
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self updateSearchControllerAttachment];
    [self reloadData];
}

- (void)handleAppForeground {
    [M2LibraryManager.sharedManager reloadTracks];
    [self reloadData];
}

- (void)handlePlaybackChanged {
    [self updatePlayButtonState];
    [self.tableView reloadData];
}

- (void)setupTableView {
    UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    tableView.translatesAutoresizingMaskIntoConstraints = NO;
    tableView.dataSource = self;
    tableView.delegate = self;
    tableView.rowHeight = 54.0;
    tableView.alwaysBounceVertical = YES;
    tableView.sectionHeaderHeight = 0.0;
    tableView.sectionFooterHeight = 0.0;
    tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    if (@available(iOS 15.0, *)) {
        tableView.sectionHeaderTopPadding = 0.0;
    }
    [tableView registerClass:M2TrackCell.class forCellReuseIdentifier:@"PlaylistTrackCell"];

    self.tableView = tableView;
    [self.view addSubview:tableView];

    [NSLayoutConstraint activateConstraints:@[
        [tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    self.tableView.tableHeaderView = [self headerViewForWidth:self.view.bounds.size.width];
    [self updatePlayButtonState];
    [self updateSleepButton];
}

- (void)setupSearch {
    self.searchController = M2BuildSearchController(self, @"Search In Playlist");
    self.navigationItem.searchController = nil;
    self.navigationItem.hidesSearchBarWhenScrolling = YES;
    self.definesPresentationContext = YES;
    self.searchControllerAttached = NO;
}

- (void)updateSearchControllerAttachment {
    BOOL shouldAttach = M2ShouldAttachSearchController(self.searchControllerAttached,
                                                       self.searchController,
                                                       self.tableView,
                                                       M2SearchRevealThreshold);
    if (shouldAttach == self.searchControllerAttached) {
        return;
    }

    self.searchControllerAttached = shouldAttach;
    M2ApplySearchControllerAttachment(self.navigationItem,
                                      self.navigationController.navigationBar,
                                      self.searchController,
                                      shouldAttach,
                                      (self.view.window != nil));
}

- (void)applySearchFilterAndReload {
    self.filteredTracks = M2FilterTracksByQuery(self.tracks, self.searchQuery);
    [self.tableView reloadData];
    [self updateEmptyState];
}

- (void)updateEmptyState {
    if (self.filteredTracks.count > 0) {
        self.tableView.backgroundView = nil;
        return;
    }

    UILabel *label = [[UILabel alloc] init];
    label.textColor = UIColor.secondaryLabelColor;
    label.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 0;
    if (self.tracks.count == 0) {
        label.text = @"Tracks missing. Re-add files to On My iPhone/M2/M2";
    } else {
        label.text = @"No matching tracks.";
    }
    self.tableView.backgroundView = label;
}

- (UIView *)headerViewForWidth:(CGFloat)width {
    CGFloat totalWidth = MAX(width, 320.0);
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, totalWidth, 374.0)];

    UIImageView *coverView = [[UIImageView alloc] initWithFrame:CGRectMake((totalWidth - 212.0) * 0.5, 16.0, 212.0, 212.0)];
    coverView.layer.cornerRadius = 16.0;
    coverView.layer.masksToBounds = YES;
    coverView.contentMode = UIViewContentModeScaleAspectFill;
    self.coverView = coverView;

    UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(14.0, 236.0, totalWidth - 28.0, 32.0)];
    nameLabel.textAlignment = NSTextAlignmentCenter;
    nameLabel.font = M2HeadlineFont(28.0);
    nameLabel.textColor = UIColor.labelColor;
    self.nameLabel = nameLabel;

    CGFloat playSize = 66.0;
    CGFloat sideControlSize = 46.0;
    CGFloat shuffleSize = 46.0;
    CGFloat controlsY = 272.0;

    UIButton *playButton = [UIButton buttonWithType:UIButtonTypeSystem];
    playButton.frame = CGRectMake((totalWidth - playSize) * 0.5, controlsY, playSize, playSize);
    playButton.backgroundColor = M2AccentYellowColor();
    playButton.tintColor = UIColor.whiteColor;
    playButton.layer.cornerRadius = playSize * 0.5;
    playButton.layer.masksToBounds = YES;
    UIImageSymbolConfiguration *playConfig = [UIImageSymbolConfiguration configurationWithPointSize:29.0
                                                                                               weight:UIImageSymbolWeightSemibold];
    [playButton setImage:[UIImage systemImageNamed:@"play.fill" withConfiguration:playConfig] forState:UIControlStateNormal];
    [playButton addTarget:self action:@selector(playTapped) forControlEvents:UIControlEventTouchUpInside];
    self.playButton = playButton;

    UIButton *sleepButton = [UIButton buttonWithType:UIButtonTypeSystem];
    sleepButton.frame = CGRectMake(CGRectGetMinX(playButton.frame) - 16.0 - sideControlSize,
                                   controlsY + (playSize - sideControlSize) * 0.5,
                                   sideControlSize,
                                   sideControlSize);
    UIImageSymbolConfiguration *sleepConfig = [UIImageSymbolConfiguration configurationWithPointSize:22.0
                                                                                               weight:UIImageSymbolWeightSemibold];
    [sleepButton setImage:[UIImage systemImageNamed:@"moon.zzz" withConfiguration:sleepConfig] forState:UIControlStateNormal];
    sleepButton.tintColor = M2PlayerPrimaryColor();
    sleepButton.backgroundColor = UIColor.clearColor;
    [sleepButton addTarget:self action:@selector(sleepTimerTapped) forControlEvents:UIControlEventTouchUpInside];
    self.sleepButton = sleepButton;

    UIButton *shuffleButton = [UIButton buttonWithType:UIButtonTypeSystem];
    shuffleButton.frame = CGRectMake(CGRectGetMaxX(playButton.frame) + 16.0,
                                     controlsY + (playSize - shuffleSize) * 0.5,
                                     shuffleSize,
                                     shuffleSize);
    UIImageSymbolConfiguration *shuffleConfig = [UIImageSymbolConfiguration configurationWithPointSize:22.0
                                                                                                 weight:UIImageSymbolWeightSemibold];
    [shuffleButton setImage:[UIImage systemImageNamed:@"shuffle" withConfiguration:shuffleConfig] forState:UIControlStateNormal];
    shuffleButton.tintColor = M2PlayerPrimaryColor();
    shuffleButton.backgroundColor = UIColor.clearColor;
    [shuffleButton addTarget:self action:@selector(shuffleTapped) forControlEvents:UIControlEventTouchUpInside];
    self.shuffleButton = shuffleButton;

    [header addSubview:coverView];
    [header addSubview:nameLabel];
    [header addSubview:sleepButton];
    [header addSubview:playButton];
    [header addSubview:shuffleButton];

    return header;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGFloat width = self.view.bounds.size.width;
    if (fabs(self.tableView.tableHeaderView.bounds.size.width - width) > 1.0) {
        self.tableView.tableHeaderView = [self headerViewForWidth:width];
        [self updateHeader];
        [self updatePlayButtonState];
        [self updateSleepButton];
    }
    [self updateNavigationTitleVisibility];
}

- (BOOL)isLovelyPlaylist {
    if (self.playlist == nil) {
        return NO;
    }

    NSString *lovelyID = [NSUserDefaults.standardUserDefaults stringForKey:M2LovelyPlaylistDefaultsKey];
    if (lovelyID.length > 0 && [self.playlist.playlistID isEqualToString:lovelyID]) {
        return YES;
    }
    return ([self.playlist.name localizedCaseInsensitiveCompare:@"Lovely songs"] == NSOrderedSame);
}

- (void)updateOptionsButtonVisibility {
    if (self.playlist == nil || [self isLovelyPlaylist]) {
        self.navigationItem.rightBarButtonItem = nil;
        return;
    }

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"ellipsis"]
                                                                               style:UIBarButtonItemStylePlain
                                                                              target:self
                                                                              action:@selector(optionsTapped)];
}

- (void)reloadData {
    [M2PlaylistStore.sharedStore reloadPlaylists];

    self.playlist = [M2PlaylistStore.sharedStore playlistWithID:self.playlistID];
    if (self.playlist == nil) {
        [self.navigationController popViewControllerAnimated:YES];
        return;
    }
    [self updateOptionsButtonVisibility];

    if (M2LibraryManager.sharedManager.tracks.count == 0 && self.playlist.trackIDs.count > 0) {
        [M2LibraryManager.sharedManager reloadTracks];
    }
    self.tracks = [M2PlaylistStore.sharedStore tracksForPlaylist:self.playlist library:M2LibraryManager.sharedManager];
    [self updateHeader];
    [self updatePlayButtonState];
    [self updateSleepButton];
    [self updateNavigationTitleVisibility];
    [self applySearchFilterAndReload];
}

- (void)updateHeader {
    if (self.playlist == nil) {
        return;
    }

    self.nameLabel.text = self.playlist.name;
    UIImage *cover = [M2PlaylistStore.sharedStore coverForPlaylist:self.playlist
                                                           library:M2LibraryManager.sharedManager
                                                              size:CGSizeMake(240.0, 240.0)];
    self.coverView.image = cover;

    if (self.playButton != nil) {
        NSString *lovelyID = [NSUserDefaults.standardUserDefaults stringForKey:M2LovelyPlaylistDefaultsKey];
        BOOL isLovely = ((lovelyID.length > 0 && [self.playlist.playlistID isEqualToString:lovelyID]) ||
                         [self.playlist.name localizedCaseInsensitiveCompare:@"Lovely songs"] == NSOrderedSame);
        UIColor *targetColor = nil;
        if (isLovely) {
            targetColor = M2LovelyAccentRedColor();
        } else {
            UIImage *accentSource = cover;
            if (accentSource == nil || accentSource.CGImage == nil) {
                for (M2Track *track in self.tracks) {
                    if (track.artwork != nil) {
                        accentSource = track.artwork;
                        break;
                    }
                }
            }

            targetColor = [M2ArtworkAccentColorService dominantAccentColorForImage:accentSource
                                                                           fallback:M2AccentYellowColor()];
        }
        if (targetColor == nil) {
            targetColor = M2AccentYellowColor();
        }

        UIColor *currentColor = self.playButton.backgroundColor;
        if (currentColor == nil || !CGColorEqualToColor(currentColor.CGColor, targetColor.CGColor)) {
            [UIView animateWithDuration:0.22
                                  delay:0.0
                                options:(UIViewAnimationOptionAllowUserInteraction |
                                         UIViewAnimationOptionBeginFromCurrentState)
                             animations:^{
                self.playButton.backgroundColor = targetColor;
            }
                             completion:nil];
        }
    }

    [self updatePlayButtonState];
}

- (BOOL)isCurrentQueueMatchingPlaylist {
    if (self.tracks.count == 0) {
        return NO;
    }

    M2PlaybackManager *playback = M2PlaybackManager.sharedManager;
    return M2TrackQueuesMatchByIdentifier(playback.currentQueue, self.tracks);
}

- (void)updatePlayButtonState {
    if (self.playButton == nil) {
        return;
    }

    M2PlaybackManager *playback = M2PlaybackManager.sharedManager;
    BOOL isPlaylistPlaying = [self isCurrentQueueMatchingPlaylist] &&
    playback.isPlaying &&
    (playback.currentTrack != nil);
    NSString *symbol = isPlaylistPlaying ? @"pause.fill" : @"play.fill";
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:29.0
                                                                                          weight:UIImageSymbolWeightSemibold];
    [self.playButton setImage:[UIImage systemImageNamed:symbol withConfiguration:config] forState:UIControlStateNormal];
    self.playButton.accessibilityLabel = isPlaylistPlaying ? @"Pause playlist" : @"Play playlist";
}

- (void)updateNavigationTitleVisibility {
    if (self.playlist == nil) {
        self.navigationItem.title = nil;
        self.navigationItem.titleView = nil;
        self.compactTitleVisible = NO;
        return;
    }

    BOOL shouldShowCompact = self.tableView.contentOffset.y > 175.0;
    if (shouldShowCompact == self.compactTitleVisible) {
        return;
    }

    self.compactTitleVisible = shouldShowCompact;
    if (shouldShowCompact) {
        self.navigationItem.titleView = nil;
        self.navigationItem.title = self.playlist.name;
    } else {
        self.navigationItem.title = nil;
        self.navigationItem.titleView = nil;
    }
}

- (void)openPlayer {
    M2PlayerViewController *player = [[M2PlayerViewController alloc] init];
    player.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:player animated:YES];
}

- (void)playTapped {
    if (self.tracks.count == 0) {
        M2PresentAlert(self, @"No Tracks", @"This playlist has no available tracks.");
        return;
    }

    M2PlaybackManager *playback = M2PlaybackManager.sharedManager;
    if ([self isCurrentQueueMatchingPlaylist] && playback.currentTrack != nil) {
        [playback togglePlayPause];
        [self updatePlayButtonState];
        [self.tableView reloadData];
        return;
    }

    [playback setShuffleEnabled:NO];
    [playback playTracks:self.tracks startIndex:0];
    [self updatePlayButtonState];
    [self.tableView reloadData];
    [self openPlayer];
}

- (void)shuffleTapped {
    if (self.tracks.count == 0) {
        M2PresentAlert(self, @"No Tracks", @"This playlist has no available tracks.");
        return;
    }

    NSInteger randomStart = (NSInteger)arc4random_uniform((u_int32_t)self.tracks.count);
    [M2PlaybackManager.sharedManager playTracks:self.tracks startIndex:randomStart];
    [M2PlaybackManager.sharedManager setShuffleEnabled:YES];
    [self updatePlayButtonState];
    [self.tableView reloadData];
    [self openPlayer];
}

- (void)sleepTimerTapped {
    __weak typeof(self) weakSelf = self;
    M2PresentSleepTimerActionSheet(self, self.sleepButton, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf updateSleepButton];
    });
}

- (void)updateSleepButton {
    if (self.sleepButton == nil) {
        return;
    }

    M2SleepTimerManager *sleepTimer = M2SleepTimerManager.sharedManager;
    BOOL isActive = sleepTimer.isActive;
    NSString *symbol = isActive ? @"moon.zzz.fill" : @"moon.zzz";
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:22.0
                                                                                          weight:UIImageSymbolWeightSemibold];
    [self.sleepButton setImage:[UIImage systemImageNamed:symbol withConfiguration:config] forState:UIControlStateNormal];
    UIColor *inactiveColor = [UIColor labelColor];
    self.sleepButton.tintColor = isActive ? M2AccentYellowColor() : inactiveColor;
    if (self.shuffleButton != nil) {
        self.shuffleButton.tintColor = inactiveColor;
    }
    self.sleepButton.accessibilityLabel = isActive
    ? [NSString stringWithFormat:@"Sleep timer active, %@ remaining", M2SleepTimerRemainingString(sleepTimer.remainingTime)]
    : @"Sleep timer";
}

- (void)optionsTapped {
    if (self.playlist == nil) {
        return;
    }
    if ([self isLovelyPlaylist]) {
        return;
    }

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:self.playlist.name
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    [sheet addAction:[UIAlertAction actionWithTitle:@"Rename Playlist"
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction * _Nonnull action) {
        [self renamePlaylistTapped];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:@"Change Cover"
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction * _Nonnull action) {
        [self changeCoverTapped];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:@"Add Music"
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction * _Nonnull action) {
        [self addMusicTapped];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:@"Delete Playlist"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(__unused UIAlertAction * _Nonnull action) {
        [self deletePlaylistTapped];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    UIPopoverPresentationController *popover = sheet.popoverPresentationController;
    if (popover != nil) {
        popover.barButtonItem = self.navigationItem.rightBarButtonItem;
    }

    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)renamePlaylistTapped {
    if (self.playlist == nil) {
        return;
    }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Rename Playlist"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"Playlist Name";
        textField.text = self.playlist.name;
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];

    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Save"
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction * _Nonnull action) {
        NSString *name = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (name.length == 0) {
            M2PresentAlert(self, @"Name Required", @"Enter playlist name.");
            return;
        }

        BOOL renamed = [M2PlaylistStore.sharedStore renamePlaylistWithID:self.playlistID newName:name];
        if (!renamed) {
            M2PresentAlert(self, @"Error", @"Could not rename playlist.");
            return;
        }

        [self reloadData];
    }]];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)changeCoverTapped {
    M2PlaylistCoverPickerViewController *coverPicker = [[M2PlaylistCoverPickerViewController alloc] initWithPlaylistID:self.playlistID];
    coverPicker.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:coverPicker animated:YES];
}

- (void)addMusicTapped {
    M2PlaylistAddTracksViewController *addTracks = [[M2PlaylistAddTracksViewController alloc] initWithPlaylistID:self.playlistID];
    addTracks.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:addTracks animated:YES];
}

- (void)deletePlaylistTapped {
    if (self.playlist == nil) {
        return;
    }

    UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"Delete Playlist?"
                                                                      message:self.playlist.name
                                                               preferredStyle:UIAlertControllerStyleAlert];
    [confirm addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                                style:UIAlertActionStyleCancel
                                              handler:nil]];
    [confirm addAction:[UIAlertAction actionWithTitle:@"Delete"
                                                style:UIAlertActionStyleDestructive
                                              handler:^(__unused UIAlertAction * _Nonnull action) {
        BOOL deleted = [M2PlaylistStore.sharedStore deletePlaylistWithID:self.playlistID];
        if (!deleted) {
            M2PresentAlert(self, @"Error", @"Could not delete playlist.");
            return;
        }
        [self.navigationController popViewControllerAnimated:YES];
    }]];

    [self presentViewController:confirm animated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView;
    (void)section;
    return self.filteredTracks.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    M2TrackCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PlaylistTrackCell" forIndexPath:indexPath];

    M2PlaybackManager *playback = M2PlaybackManager.sharedManager;
    M2Track *track = self.filteredTracks[indexPath.row];
    M2Track *currentTrack = playback.currentTrack;
    BOOL isCurrent = (currentTrack != nil && [currentTrack.identifier isEqualToString:track.identifier]);
    BOOL sameQueue = [self isCurrentQueueMatchingPlaylist];
    BOOL showsPlaybackIndicator = (sameQueue && isCurrent && playback.isPlaying);

    [cell configureWithTrack:track isCurrent:isCurrent showsPlaybackIndicator:showsPlaybackIndicator];
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.row >= self.filteredTracks.count) {
        return;
    }

    M2Track *selectedTrack = self.filteredTracks[indexPath.row];
    M2Track *currentTrack = M2PlaybackManager.sharedManager.currentTrack;
    if (currentTrack != nil && [currentTrack.identifier isEqualToString:selectedTrack.identifier]) {
        [self openPlayer];
        return;
    }

    [M2PlaybackManager.sharedManager setShuffleEnabled:NO];
    [M2PlaybackManager.sharedManager playTracks:self.filteredTracks startIndex:indexPath.row];
    [self openPlayer];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView == self.tableView) {
        [self updateNavigationTitleVisibility];
        [self updateSearchControllerAttachment];
    }
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView;
    if (indexPath.row >= self.filteredTracks.count) {
        return [UISwipeActionsConfiguration configurationWithActions:@[]];
    }

    M2Track *track = self.filteredTracks[indexPath.row];

    UIContextualAction *removeAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                                title:@"Remove"
                                                                              handler:^(__unused UIContextualAction * _Nonnull action,
                                                                                        __unused UIView * _Nonnull sourceView,
                                                                                        void (^ _Nonnull completionHandler)(BOOL)) {
        BOOL removed = [M2PlaylistStore.sharedStore removeTrackID:track.identifier fromPlaylistID:self.playlistID];
        if (!removed) {
            M2PresentAlert(self, @"Could Not Remove", @"Track could not be removed from playlist.");
            completionHandler(NO);
            return;
        }
        [self reloadData];
        completionHandler(YES);
    }];
    removeAction.image = [UIImage systemImageNamed:@"trash.fill"];

    UIContextualAction *addAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                            title:@"Add"
                                                                          handler:^(__unused UIContextualAction * _Nonnull action,
                                                                                    __unused UIView * _Nonnull sourceView,
                                                                                    void (^ _Nonnull completionHandler)(BOOL)) {
        M2PresentQuickAddTrackToPlaylist(self, track.identifier, nil);
        completionHandler(YES);
    }];
    addAction.image = [UIImage systemImageNamed:@"text.badge.plus"];
    addAction.backgroundColor = [UIColor colorWithRed:0.16 green:0.47 blue:0.95 alpha:1.0];

    UISwipeActionsConfiguration *configuration = [UISwipeActionsConfiguration configurationWithActions:@[removeAction, addAction]];
    configuration.performsFirstActionWithFullSwipe = NO;
    return configuration;
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
leadingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView;
    if (indexPath.row >= self.filteredTracks.count) {
        return [UISwipeActionsConfiguration configurationWithActions:@[]];
    }

    M2Track *track = self.filteredTracks[indexPath.row];
    BOOL isFavorite = [M2FavoritesStore.sharedStore isTrackFavoriteByID:track.identifier];
    NSString *iconName = isFavorite ? @"heart.slash.fill" : @"heart.fill";

    UIContextualAction *favoriteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                                  title:nil
                                                                                handler:^(__unused UIContextualAction * _Nonnull action,
                                                                                          __unused UIView * _Nonnull sourceView,
                                                                                          void (^ _Nonnull completionHandler)(BOOL)) {
        [M2FavoritesStore.sharedStore setTrackID:track.identifier favorite:!isFavorite];
        completionHandler(YES);
    }];
    favoriteAction.image = [UIImage systemImageNamed:iconName];
    favoriteAction.backgroundColor = isFavorite
    ? [UIColor colorWithWhite:0.40 alpha:1.0]
    : [UIColor colorWithRed:1.0 green:0.35 blue:0.42 alpha:1.0];

    UISwipeActionsConfiguration *configuration = [UISwipeActionsConfiguration configurationWithActions:@[favoriteAction]];
    configuration.performsFirstActionWithFullSwipe = YES;
    return configuration;
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    self.searchQuery = searchController.searchBar.text ?: @"";
    [self applySearchFilterAndReload];
}

@end

#pragma mark - Player

@interface M2PlayerViewController ()

@property (nonatomic, strong) UIImageView *artworkView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UISlider *progressSlider;
@property (nonatomic, strong) UILabel *elapsedLabel;
@property (nonatomic, strong) UILabel *durationLabel;
@property (nonatomic, strong) UILabel *nextPreviewLabel;
@property (nonatomic, strong) UIButton *shuffleButton;
@property (nonatomic, strong) UIButton *repeatButton;
@property (nonatomic, strong) UIButton *previousButton;
@property (nonatomic, strong) UIButton *playPauseButton;
@property (nonatomic, strong) UIButton *nextButton;
@property (nonatomic, strong) UIButton *favoriteButton;
@property (nonatomic, strong) UIButton *sleepTimerButton;
@property (nonatomic, assign) BOOL scrubbing;

@end

@implementation M2PlayerViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = M2PlayerBackgroundColor();

    [self setupUI];
    [self applyPlayerTheme];

    if (@available(iOS 17.0, *)) {
        __weak typeof(self) weakSelf = self;
        [self registerForTraitChanges:@[UITraitUserInterfaceStyle.class]
                          withHandler:^(__kindof id<UITraitEnvironment>  _Nonnull traitEnvironment,
                                        UITraitCollection * _Nullable previousTraitCollection) {
            (void)traitEnvironment;
            (void)previousTraitCollection;
            __strong typeof(weakSelf) strongSelf = weakSelf;
            [strongSelf applyPlayerTheme];
            [strongSelf updateModeIcons];
        }];
    }

    UISwipeGestureRecognizer *swipeDown = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleDismissSwipe)];
    swipeDown.direction = UISwipeGestureRecognizerDirectionDown;
    [self.view addGestureRecognizer:swipeDown];

    UISwipeGestureRecognizer *swipeRight = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleDismissSwipe)];
    swipeRight.direction = UISwipeGestureRecognizerDirectionRight;
    [self.view addGestureRecognizer:swipeRight];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(refreshUI)
                                               name:M2PlaybackStateDidChangeNotification
                                             object:nil];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(handleProgressChanged)
                                               name:M2PlaybackProgressDidChangeNotification
                                             object:nil];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(updateFavoriteButton)
                                               name:M2FavoritesDidChangeNotification
                                             object:nil];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(updateSleepTimerButton)
                                               name:M2SleepTimerDidChangeNotification
                                             object:nil];

    [self refreshUI];
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.navigationController.interactivePopGestureRecognizer.enabled = YES;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
}

- (void)setupUI {
    UIView *content = [[UIView alloc] init];
    content.translatesAutoresizingMaskIntoConstraints = NO;

    UIImageView *artworkView = [[UIImageView alloc] init];
    artworkView.translatesAutoresizingMaskIntoConstraints = NO;
    artworkView.contentMode = UIViewContentModeScaleAspectFill;
    artworkView.layer.cornerRadius = 0.0;
    artworkView.layer.masksToBounds = YES;
    self.artworkView = artworkView;

    UILabel *artistLabel = [[UILabel alloc] init];
    artistLabel.translatesAutoresizingMaskIntoConstraints = NO;
    artistLabel.textAlignment = NSTextAlignmentCenter;
    artistLabel.font = [UIFont systemFontOfSize:24.0 weight:UIFontWeightSemibold];
    artistLabel.numberOfLines = 1;
    self.subtitleLabel = artistLabel;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.font = [UIFont systemFontOfSize:24.0 weight:UIFontWeightSemibold];
    titleLabel.numberOfLines = 1;
    self.titleLabel = titleLabel;

    UISlider *slider = [[UISlider alloc] init];
    slider.translatesAutoresizingMaskIntoConstraints = NO;
    slider.minimumValue = 0.0;
    slider.maximumValue = 1.0;
    slider.transform = CGAffineTransformMakeScale(1.0, 0.92);
    [slider addTarget:self action:@selector(sliderTouchDown) forControlEvents:UIControlEventTouchDown];
    [slider addTarget:self action:@selector(sliderChanged) forControlEvents:UIControlEventValueChanged];
    [slider addTarget:self action:@selector(sliderTouchUp) forControlEvents:UIControlEventTouchUpInside];
    [slider addTarget:self action:@selector(sliderTouchUp) forControlEvents:UIControlEventTouchUpOutside];
    [slider addTarget:self action:@selector(sliderTouchUp) forControlEvents:UIControlEventTouchCancel];
    self.progressSlider = slider;

    UILabel *elapsedLabel = [[UILabel alloc] init];
    elapsedLabel.translatesAutoresizingMaskIntoConstraints = NO;
    elapsedLabel.font = [UIFont monospacedDigitSystemFontOfSize:12.0 weight:UIFontWeightMedium];
    self.elapsedLabel = elapsedLabel;

    UILabel *durationLabel = [[UILabel alloc] init];
    durationLabel.translatesAutoresizingMaskIntoConstraints = NO;
    durationLabel.textAlignment = NSTextAlignmentRight;
    durationLabel.font = [UIFont monospacedDigitSystemFontOfSize:12.0 weight:UIFontWeightMedium];
    self.durationLabel = durationLabel;

    UILabel *nextPreviewLabel = [[UILabel alloc] init];
    nextPreviewLabel.translatesAutoresizingMaskIntoConstraints = NO;
    nextPreviewLabel.textAlignment = NSTextAlignmentLeft;
    nextPreviewLabel.font = [UIFont systemFontOfSize:18.0 weight:UIFontWeightSemibold];
    nextPreviewLabel.numberOfLines = 2;
    self.nextPreviewLabel = nextPreviewLabel;

    self.repeatButton = M2PlainIconButton(@"repeat", 24.0, 600.0);
    [self.repeatButton addTarget:self action:@selector(toggleRepeatTapped) forControlEvents:UIControlEventTouchUpInside];
    [NSLayoutConstraint activateConstraints:@[
        [self.repeatButton.widthAnchor constraintEqualToConstant:42.0],
        [self.repeatButton.heightAnchor constraintEqualToConstant:42.0]
    ]];

    self.shuffleButton = M2PlainIconButton(@"shuffle", 24.0, 600.0);
    [self.shuffleButton addTarget:self action:@selector(toggleShuffleTapped) forControlEvents:UIControlEventTouchUpInside];
    [NSLayoutConstraint activateConstraints:@[
        [self.shuffleButton.widthAnchor constraintEqualToConstant:42.0],
        [self.shuffleButton.heightAnchor constraintEqualToConstant:42.0]
    ]];

    self.previousButton = M2PlainIconButton(@"backward.fill", 44.0, 700.0);
    [self.previousButton addTarget:self action:@selector(previousTapped) forControlEvents:UIControlEventTouchUpInside];
    [NSLayoutConstraint activateConstraints:@[
        [self.previousButton.widthAnchor constraintEqualToConstant:64.0],
        [self.previousButton.heightAnchor constraintEqualToConstant:64.0]
    ]];

    self.playPauseButton = M2PlainIconButton(@"play.fill", 56.0, 700.0);
    [self.playPauseButton addTarget:self action:@selector(playPauseTapped) forControlEvents:UIControlEventTouchUpInside];
    [NSLayoutConstraint activateConstraints:@[
        [self.playPauseButton.widthAnchor constraintEqualToConstant:76.0],
        [self.playPauseButton.heightAnchor constraintEqualToConstant:76.0]
    ]];

    self.nextButton = M2PlainIconButton(@"forward.fill", 44.0, 700.0);
    [self.nextButton addTarget:self action:@selector(nextTapped) forControlEvents:UIControlEventTouchUpInside];
    [NSLayoutConstraint activateConstraints:@[
        [self.nextButton.widthAnchor constraintEqualToConstant:64.0],
        [self.nextButton.heightAnchor constraintEqualToConstant:64.0]
    ]];

    self.favoriteButton = M2PlainIconButton(@"heart", 24.0, 600.0);
    [self.favoriteButton addTarget:self action:@selector(toggleFavoriteTapped) forControlEvents:UIControlEventTouchUpInside];
    [NSLayoutConstraint activateConstraints:@[
        [self.favoriteButton.widthAnchor constraintEqualToConstant:40.0],
        [self.favoriteButton.heightAnchor constraintEqualToConstant:40.0]
    ]];

    self.sleepTimerButton = M2PlainIconButton(@"moon.zzz", 23.0, 600.0);
    [self.sleepTimerButton addTarget:self action:@selector(sleepTimerTapped) forControlEvents:UIControlEventTouchUpInside];
    [NSLayoutConstraint activateConstraints:@[
        [self.sleepTimerButton.widthAnchor constraintEqualToConstant:40.0],
        [self.sleepTimerButton.heightAnchor constraintEqualToConstant:40.0]
    ]];

    UIStackView *modeStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.repeatButton, self.shuffleButton]];
    modeStack.translatesAutoresizingMaskIntoConstraints = NO;
    modeStack.axis = UILayoutConstraintAxisVertical;
    modeStack.alignment = UIStackViewAlignmentCenter;
    modeStack.distribution = UIStackViewDistributionEqualSpacing;
    modeStack.spacing = 10.0;

    UIStackView *rightStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.sleepTimerButton, self.favoriteButton]];
    rightStack.translatesAutoresizingMaskIntoConstraints = NO;
    rightStack.axis = UILayoutConstraintAxisVertical;
    rightStack.alignment = UIStackViewAlignmentCenter;
    rightStack.distribution = UIStackViewDistributionEqualSpacing;
    rightStack.spacing = 10.0;

    UIStackView *transportStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.previousButton, self.playPauseButton, self.nextButton
    ]];
    transportStack.translatesAutoresizingMaskIntoConstraints = NO;
    transportStack.axis = UILayoutConstraintAxisHorizontal;
    transportStack.alignment = UIStackViewAlignmentCenter;
    transportStack.distribution = UIStackViewDistributionEqualCentering;
    transportStack.spacing = 16.0;

    UIView *controlsRow = [[UIView alloc] init];
    controlsRow.translatesAutoresizingMaskIntoConstraints = NO;

    [content addSubview:artworkView];
    [content addSubview:slider];
    [content addSubview:elapsedLabel];
    [content addSubview:durationLabel];
    [content addSubview:artistLabel];
    [content addSubview:titleLabel];
    [content addSubview:nextPreviewLabel];
    [content addSubview:controlsRow];

    [controlsRow addSubview:modeStack];
    [controlsRow addSubview:transportStack];
    [controlsRow addSubview:rightStack];

    [self.view addSubview:content];

    NSLayoutConstraint *artworkSquare = [artworkView.heightAnchor constraintEqualToAnchor:artworkView.widthAnchor];
    artworkSquare.priority = UILayoutPriorityDefaultHigh;

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [content.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [content.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [content.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [artworkView.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [artworkView.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
        [artworkView.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
        artworkSquare,
        [artworkView.heightAnchor constraintLessThanOrEqualToAnchor:content.heightAnchor multiplier:0.56],

        [slider.topAnchor constraintEqualToAnchor:artworkView.bottomAnchor constant:16.0],
        [slider.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:16.0],
        [slider.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-16.0],

        [elapsedLabel.topAnchor constraintEqualToAnchor:slider.bottomAnchor constant:3.0],
        [elapsedLabel.leadingAnchor constraintEqualToAnchor:slider.leadingAnchor],

        [durationLabel.topAnchor constraintEqualToAnchor:elapsedLabel.topAnchor],
        [durationLabel.trailingAnchor constraintEqualToAnchor:slider.trailingAnchor],

        [artistLabel.topAnchor constraintEqualToAnchor:elapsedLabel.bottomAnchor constant:18.0],
        [artistLabel.leadingAnchor constraintEqualToAnchor:slider.leadingAnchor],
        [artistLabel.trailingAnchor constraintEqualToAnchor:slider.trailingAnchor],

        [titleLabel.topAnchor constraintEqualToAnchor:artistLabel.bottomAnchor constant:6.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:slider.leadingAnchor],
        [titleLabel.trailingAnchor constraintEqualToAnchor:slider.trailingAnchor],

        [controlsRow.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:14.0],
        [controlsRow.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-14.0],
        [controlsRow.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-6.0],
        [controlsRow.heightAnchor constraintEqualToConstant:88.0],

        [modeStack.leadingAnchor constraintEqualToAnchor:controlsRow.leadingAnchor],
        [modeStack.centerYAnchor constraintEqualToAnchor:controlsRow.centerYAnchor],

        [transportStack.centerXAnchor constraintEqualToAnchor:controlsRow.centerXAnchor],
        [transportStack.centerYAnchor constraintEqualToAnchor:controlsRow.centerYAnchor],

        [rightStack.trailingAnchor constraintEqualToAnchor:controlsRow.trailingAnchor],
        [rightStack.centerYAnchor constraintEqualToAnchor:controlsRow.centerYAnchor],

        [nextPreviewLabel.leadingAnchor constraintEqualToAnchor:slider.leadingAnchor],
        [nextPreviewLabel.trailingAnchor constraintEqualToAnchor:slider.trailingAnchor],
        [nextPreviewLabel.topAnchor constraintGreaterThanOrEqualToAnchor:titleLabel.bottomAnchor constant:16.0],
        [nextPreviewLabel.bottomAnchor constraintEqualToAnchor:controlsRow.topAnchor constant:-14.0]
    ]];
}

- (void)handleDismissSwipe {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)applyPlayerTheme {
    UIColor *primary = M2PlayerPrimaryColor();
    UIColor *secondary = M2PlayerSecondaryColor();

    self.view.backgroundColor = M2PlayerBackgroundColor();
    self.titleLabel.textColor = primary;
    self.subtitleLabel.textColor = secondary;
    self.elapsedLabel.textColor = secondary;
    self.durationLabel.textColor = secondary;
    self.nextPreviewLabel.textColor = secondary;

    self.progressSlider.minimumTrackTintColor = primary;
    self.progressSlider.maximumTrackTintColor = M2PlayerTimelineMaxColor();
    UIImage *thumbImage = M2SliderThumbImage(14.5, primary);
    [self.progressSlider setThumbImage:thumbImage forState:UIControlStateNormal];
    [self.progressSlider setThumbImage:thumbImage forState:UIControlStateHighlighted];

    BOOL controlsEnabled = self.playPauseButton.enabled;
    UIColor *controlColor = controlsEnabled ? primary : [secondary colorWithAlphaComponent:0.65];
    self.previousButton.tintColor = controlColor;
    self.playPauseButton.tintColor = controlColor;
    self.nextButton.tintColor = controlColor;
    [self updateFavoriteButton];
    [self updateSleepTimerButton];
}

- (void)previousTapped {
    [M2PlaybackManager.sharedManager playPrevious];
}

- (void)playPauseTapped {
    [M2PlaybackManager.sharedManager togglePlayPause];
}

- (void)nextTapped {
    [M2PlaybackManager.sharedManager playNext];
}

- (void)toggleShuffleTapped {
    [M2PlaybackManager.sharedManager toggleShuffleEnabled];
}

- (void)toggleRepeatTapped {
    [M2PlaybackManager.sharedManager cycleRepeatMode];
}

- (void)toggleFavoriteTapped {
    M2Track *track = M2PlaybackManager.sharedManager.currentTrack;
    if (track.identifier.length == 0) {
        return;
    }
    [M2FavoritesStore.sharedStore toggleFavoriteForTrackID:track.identifier];
    [self updateFavoriteButton];
}

- (void)sleepTimerTapped {
    __weak typeof(self) weakSelf = self;
    M2PresentSleepTimerActionSheet(self, self.sleepTimerButton, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf updateSleepTimerButton];
    });
}

- (void)updateFavoriteButton {
    M2Track *track = M2PlaybackManager.sharedManager.currentTrack;
    if (track == nil || track.identifier.length == 0) {
        self.favoriteButton.hidden = YES;
        self.favoriteButton.enabled = NO;
        return;
    }

    self.favoriteButton.hidden = NO;
    self.favoriteButton.enabled = YES;

    BOOL isFavorite = [M2FavoritesStore.sharedStore isTrackFavoriteByID:track.identifier];
    NSString *symbolName = isFavorite ? @"heart.fill" : @"heart";
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:24.0
                                                                                          weight:UIImageSymbolWeightSemibold];
    UIImage *image = [UIImage systemImageNamed:symbolName withConfiguration:config];
    [self.favoriteButton setImage:image forState:UIControlStateNormal];
    self.favoriteButton.tintColor = isFavorite ? [UIColor colorWithRed:1.0 green:0.35 blue:0.40 alpha:1.0]
                                               : [M2PlayerPrimaryColor() colorWithAlphaComponent:0.92];
}

- (void)updateSleepTimerButton {
    BOOL isActive = M2SleepTimerManager.sharedManager.isActive;
    NSString *symbol = isActive ? @"moon.zzz.fill" : @"moon.zzz";
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:23.0
                                                                                          weight:UIImageSymbolWeightSemibold];
    [self.sleepTimerButton setImage:[UIImage systemImageNamed:symbol withConfiguration:config] forState:UIControlStateNormal];
    self.sleepTimerButton.tintColor = isActive ? M2AccentYellowColor()
                                               : [M2PlayerPrimaryColor() colorWithAlphaComponent:0.92];
    self.sleepTimerButton.accessibilityLabel = isActive
    ? [NSString stringWithFormat:@"Sleep timer active, %@ remaining", M2SleepTimerRemainingString(M2SleepTimerManager.sharedManager.remainingTime)]
    : @"Sleep timer";
}

- (void)sliderTouchDown {
    self.scrubbing = YES;
}

- (void)sliderChanged {
    self.elapsedLabel.text = M2FormatDuration(self.progressSlider.value);
}

- (void)sliderTouchUp {
    self.scrubbing = NO;
    [M2PlaybackManager.sharedManager seekToTime:self.progressSlider.value];
}

- (void)handleProgressChanged {
    if (!self.scrubbing) {
        [self refreshTimelineOnly];
    }
}

- (void)refreshTimelineOnly {
    M2PlaybackManager *playback = M2PlaybackManager.sharedManager;
    NSTimeInterval duration = playback.duration;
    NSTimeInterval current = playback.currentTime;

    self.progressSlider.maximumValue = MAX(duration, 1.0);
    self.progressSlider.value = MIN(current, self.progressSlider.maximumValue);

    self.elapsedLabel.text = M2FormatDuration(current);
    self.durationLabel.text = M2FormatDuration(duration);
}

- (void)refreshUI {
    M2PlaybackManager *playback = M2PlaybackManager.sharedManager;
    M2Track *track = playback.currentTrack;

    if (track == nil) {
        self.artworkView.image = [UIImage systemImageNamed:@"music.note.list"];
        self.artworkView.contentMode = UIViewContentModeCenter;
        self.artworkView.tintColor = M2PlayerPrimaryColor();

        self.subtitleLabel.text = @"";
        self.titleLabel.text = @"No track selected";
        self.nextPreviewLabel.text = @"Next: -";

        self.playPauseButton.enabled = NO;
        self.previousButton.enabled = NO;
        self.nextButton.enabled = NO;

        self.progressSlider.maximumValue = 1.0;
        self.progressSlider.value = 0.0;
        self.elapsedLabel.text = @"0:00";
        self.durationLabel.text = @"0:00";

        [self applyPlayerTheme];
        [self updatePlayPauseIcon];
        [self updateModeIcons];
        [self updateFavoriteButton];
        [self updateSleepTimerButton];
        return;
    }

    self.artworkView.contentMode = UIViewContentModeScaleAspectFill;
    self.artworkView.image = track.artwork;

    self.subtitleLabel.text = (track.artist.length > 0 ? track.artist : @"");
    self.titleLabel.text = (track.title.length > 0 ? track.title : track.fileName);
    self.nextPreviewLabel.text = [self nextPreviewText];

    self.playPauseButton.enabled = YES;
    self.previousButton.enabled = YES;
    self.nextButton.enabled = YES;

    [self refreshTimelineOnly];
    [self applyPlayerTheme];
    [self updatePlayPauseIcon];
    [self updateModeIcons];
    [self updateFavoriteButton];
    [self updateSleepTimerButton];
}

- (NSString *)nextPreviewText {
    M2Track *nextTrack = [M2PlaybackManager.sharedManager predictedNextTrackForSkip];

    if (nextTrack == nil) {
        return @"Next: -";
    }

    NSString *title = (nextTrack.title.length > 0 ? nextTrack.title : @"Unknown");
    if (nextTrack.artist.length > 0) {
        return [NSString stringWithFormat:@"Next: %@ - %@", nextTrack.artist, title];
    }
    return [NSString stringWithFormat:@"Next: %@", title];
}

- (void)updatePlayPauseIcon {
    NSString *symbol = M2PlaybackManager.sharedManager.isPlaying ? @"pause.fill" : @"play.fill";
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:56.0
                                                                                           weight:UIImageSymbolWeightBold];
    [self.playPauseButton setImage:[UIImage systemImageNamed:symbol withConfiguration:config] forState:UIControlStateNormal];
}

- (void)updateModeIcons {
    M2PlaybackManager *playback = M2PlaybackManager.sharedManager;
    UIColor *inactiveColor = M2PlayerPrimaryColor();

    self.shuffleButton.tintColor = playback.isShuffleEnabled ? M2AccentYellowColor() : inactiveColor;

    NSString *repeatSymbol = @"repeat";
    switch (playback.repeatMode) {
        case M2RepeatModeNone:
            repeatSymbol = @"repeat";
            self.repeatButton.tintColor = inactiveColor;
            break;
        case M2RepeatModeQueue:
            repeatSymbol = @"repeat";
            self.repeatButton.tintColor = M2AccentYellowColor();
            break;
        case M2RepeatModeTrack:
            repeatSymbol = @"repeat.1";
            self.repeatButton.tintColor = M2AccentYellowColor();
            break;
    }

    UIImageSymbolConfiguration *repeatConfig = [UIImageSymbolConfiguration configurationWithPointSize:24.0
                                                                                                 weight:UIImageSymbolWeightSemibold];
    [self.repeatButton setImage:[UIImage systemImageNamed:repeatSymbol withConfiguration:repeatConfig] forState:UIControlStateNormal];
}

@end
