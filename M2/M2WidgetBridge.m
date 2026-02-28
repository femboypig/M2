//
//  M2WidgetBridge.m
//  M2
//

#import "M2WidgetBridge.h"

#import <objc/message.h>

#import "M2Services.h"

static NSString * const M2WidgetAppGroupIdentifier = @"group.ru.hippo.M2.shared";
static NSString * const M2WidgetLovelyTracksDefaultsKey = @"m2_widget_lovely_tracks_v1";
static NSString * const M2WidgetRandomTracksDefaultsKey = @"m2_widget_random_tracks_v1";
static NSString * const M2WidgetArtworkDirectoryName = @"m2_widget_artwork_v1";
static NSString * const M2WidgetArtworkFileNameKey = @"artworkFileName";
static NSString * const M2WidgetArtworkThumbKey = @"artworkThumb";
static NSString * const M2WidgetDeepLinkScheme = @"m2";
static NSString * const M2WidgetDeepLinkHost = @"widget";
static NSString * const M2WidgetDeepLinkPath = @"/play";
static NSString * const M2WidgetDeepLinkTrackIDQueryItem = @"trackID";
static NSString * const M2LovelyPlaylistDefaultsKey = @"m2_lovely_playlist_id_v1";
static NSString * const M2WidgetUpdatedAtDefaultsKey = @"m2_widget_lovely_tracks_updated_at_v1";
static const NSTimeInterval M2WidgetRefreshThrottleInterval = 300.0;

static UIImage *M2WidgetPreparedArtworkImage(UIImage *image, CGSize targetSize) {
    if (image == nil) {
        return nil;
    }

    if (targetSize.width <= 1.0 || targetSize.height <= 1.0) {
        return image;
    }

    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.opaque = YES;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:targetSize format:format];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull context) {
        [[UIColor blackColor] setFill];
        UIRectFill((CGRect){ .origin = CGPointZero, .size = targetSize });

        CGSize imageSize = image.size;
        if (imageSize.width <= 1.0 || imageSize.height <= 1.0) {
            [image drawInRect:(CGRect){ .origin = CGPointZero, .size = targetSize }];
            return;
        }

        CGFloat scale = MAX(targetSize.width / imageSize.width, targetSize.height / imageSize.height);
        CGSize drawSize = CGSizeMake(imageSize.width * scale, imageSize.height * scale);
        CGRect drawRect = CGRectMake((targetSize.width - drawSize.width) * 0.5,
                                     (targetSize.height - drawSize.height) * 0.5,
                                     drawSize.width,
                                     drawSize.height);
        [image drawInRect:drawRect];
    }];
}

static NSData *M2WidgetThumbnailData(UIImage *image, CGSize targetSize) {
    UIImage *prepared = M2WidgetPreparedArtworkImage(image, targetSize);
    if (prepared == nil) {
        return nil;
    }

    NSData *jpeg = UIImageJPEGRepresentation(prepared, 0.78);
    if (jpeg.length > 0) {
        return jpeg;
    }

    return UIImagePNGRepresentation(prepared);
}

@implementation M2WidgetBridge

+ (NSArray<M2Track *> *)lovelyTracksFromLibrary {
    M2LibraryManager *library = M2LibraryManager.sharedManager;
    if (library.tracks.count == 0) {
        [library reloadTracks];
    }

    NSArray<M2Track *> *tracks = library.tracks;
    if (tracks.count == 0) {
        return @[];
    }

    M2TrackAnalyticsStore *analytics = M2TrackAnalyticsStore.sharedStore;
    NSArray<M2Track *> *sorted = [tracks sortedArrayUsingComparator:^NSComparisonResult(M2Track *first, M2Track *second) {
        double firstScore = [analytics scoreForTrackID:first.identifier ?: @""];
        double secondScore = [analytics scoreForTrackID:second.identifier ?: @""];
        if (firstScore > secondScore) {
            return NSOrderedAscending;
        }
        if (firstScore < secondScore) {
            return NSOrderedDescending;
        }
        return [first.title ?: @"" compare:second.title ?: @"" options:NSCaseInsensitiveSearch];
    }];

    NSUInteger limit = MIN(sorted.count, 120);
    return [sorted subarrayWithRange:NSMakeRange(0, limit)];
}

+ (NSArray<M2Track *> *)randomTracksFromLibrary {
    M2LibraryManager *library = M2LibraryManager.sharedManager;
    NSArray<M2Track *> *tracks = library.tracks;
    if (tracks.count == 0) {
        tracks = [library reloadTracks];
    }
    return tracks ?: @[];
}

+ (nullable NSURL *)widgetArtworkDirectoryURL {
    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSURL *containerURL = [fileManager containerURLForSecurityApplicationGroupIdentifier:M2WidgetAppGroupIdentifier];
    if (containerURL == nil) {
        return nil;
    }

    NSURL *directoryURL = [containerURL URLByAppendingPathComponent:M2WidgetArtworkDirectoryName isDirectory:YES];
    NSError *directoryError = nil;
    [fileManager createDirectoryAtURL:directoryURL
          withIntermediateDirectories:YES
                           attributes:nil
                                error:&directoryError];
    if (directoryError != nil) {
        return nil;
    }

    return directoryURL;
}

+ (void)clearWidgetArtworkAtDirectoryURL:(nullable NSURL *)directoryURL {
    if (directoryURL == nil) {
        return;
    }

    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSError *listError = nil;
    NSArray<NSURL *> *files = [fileManager contentsOfDirectoryAtURL:directoryURL
                                          includingPropertiesForKeys:nil
                                                             options:NSDirectoryEnumerationSkipsHiddenFiles
                                                               error:&listError];
    if (listError != nil || files.count == 0) {
        return;
    }

    for (NSURL *fileURL in files) {
        [fileManager removeItemAtURL:fileURL error:nil];
    }
}

+ (nullable NSString *)storeWidgetArtworkForTrack:(M2Track *)track directoryURL:(nullable NSURL *)directoryURL {
    if (directoryURL == nil || track.artwork == nil || track.identifier.length == 0) {
        return nil;
    }

    UIImage *prepared = M2WidgetPreparedArtworkImage(track.artwork, CGSizeMake(420.0, 420.0));
    if (prepared == nil) {
        return nil;
    }

    NSData *artworkData = UIImageJPEGRepresentation(prepared, 0.84);
    if (artworkData.length == 0) {
        artworkData = UIImagePNGRepresentation(prepared);
    }
    if (artworkData.length == 0) {
        return nil;
    }

    NSString *fileName = [NSString stringWithFormat:@"%@.jpg", NSUUID.UUID.UUIDString.lowercaseString];
    NSURL *fileURL = [directoryURL URLByAppendingPathComponent:fileName];
    NSError *writeError = nil;
    BOOL success = [artworkData writeToURL:fileURL options:NSDataWritingAtomic error:&writeError];
    if (!success || writeError != nil) {
        return nil;
    }

    return fileName;
}

+ (NSArray<NSDictionary<NSString *, NSString *> *> *)serializedWidgetTracks:(NSArray<M2Track *> *)tracks
                                                          artworkDirectoryURL:(nullable NSURL *)artworkDirectoryURL {
    NSMutableArray<NSDictionary<NSString *, NSString *> *> *payload = [NSMutableArray arrayWithCapacity:tracks.count];

    for (M2Track *track in tracks) {
        if (track.identifier.length == 0) {
            continue;
        }

        NSString *title = track.title.length > 0 ? track.title : track.fileName;
        NSString *artist = track.artist.length > 0 ? track.artist : @"";
        NSMutableDictionary<NSString *, NSString *> *entry = [@{
            @"id": track.identifier,
            @"title": (title.length > 0 ? title : @"Unknown Song"),
            @"artist": artist
        } mutableCopy];

        NSString *artworkFileName = [self storeWidgetArtworkForTrack:track directoryURL:artworkDirectoryURL];
        if (artworkFileName.length > 0) {
            entry[M2WidgetArtworkFileNameKey] = artworkFileName;
        }

        NSData *thumbData = M2WidgetThumbnailData(track.artwork, CGSizeMake(96.0, 96.0));
        if (thumbData.length > 0) {
            entry[M2WidgetArtworkThumbKey] = [thumbData base64EncodedStringWithOptions:0];
        }

        [payload addObject:entry];

        if (payload.count >= 80) {
            break;
        }
    }

    return [payload copy];
}

+ (void)reloadWidgetTimelinesIfAvailable {
    if (@available(iOS 14.0, *)) {
        void (^reloadBlock)(void) = ^{
            Class widgetCenterClass = NSClassFromString(@"WidgetCenter");
            SEL sharedCenterSelector = NSSelectorFromString(@"sharedCenter");
            SEL reloadAllTimelinesSelector = NSSelectorFromString(@"reloadAllTimelines");
            if (widgetCenterClass == Nil || ![widgetCenterClass respondsToSelector:sharedCenterSelector]) {
                return;
            }

            id center = ((id (*)(id, SEL))objc_msgSend)(widgetCenterClass, sharedCenterSelector);
            if (center == nil || ![center respondsToSelector:reloadAllTimelinesSelector]) {
                return;
            }

            ((void (*)(id, SEL))objc_msgSend)(center, reloadAllTimelinesSelector);
        };

        if (NSThread.isMainThread) {
            reloadBlock();
        } else {
            dispatch_async(dispatch_get_main_queue(), reloadBlock);
        }
    }
}

+ (void)refreshSharedLovelyTracks {
    NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:M2WidgetAppGroupIdentifier];
    if (sharedDefaults == nil) {
        return;
    }

    NSDate *lastUpdatedAt = [sharedDefaults objectForKey:M2WidgetUpdatedAtDefaultsKey];
    if ([lastUpdatedAt isKindOfClass:NSDate.class]) {
        NSTimeInterval age = fabs(lastUpdatedAt.timeIntervalSinceNow);
        if (age < M2WidgetRefreshThrottleInterval) {
            return;
        }
    }

    NSURL *artworkDirectoryURL = [self widgetArtworkDirectoryURL];
    [self clearWidgetArtworkAtDirectoryURL:artworkDirectoryURL];

    NSArray<M2Track *> *lovelyTracks = [self lovelyTracksFromLibrary];
    NSArray<M2Track *> *randomTracks = [self randomTracksFromLibrary];
    NSArray<NSDictionary<NSString *, NSString *> *> *lovelyPayload = [self serializedWidgetTracks:lovelyTracks
                                                                                artworkDirectoryURL:artworkDirectoryURL];
    NSArray<NSDictionary<NSString *, NSString *> *> *randomPayload = [self serializedWidgetTracks:randomTracks
                                                                                artworkDirectoryURL:artworkDirectoryURL];
    [sharedDefaults setObject:lovelyPayload forKey:M2WidgetLovelyTracksDefaultsKey];
    [sharedDefaults setObject:randomPayload forKey:M2WidgetRandomTracksDefaultsKey];
    [sharedDefaults setObject:NSDate.date forKey:M2WidgetUpdatedAtDefaultsKey];
    [self reloadWidgetTimelinesIfAvailable];
}

+ (nullable NSString *)trackIDFromDeepLinkURL:(NSURL *)url {
    if (![url isKindOfClass:NSURL.class]) {
        return nil;
    }

    NSString *scheme = url.scheme.lowercaseString;
    if (![scheme isEqualToString:M2WidgetDeepLinkScheme]) {
        return nil;
    }

    NSString *host = url.host.lowercaseString;
    if (![host isEqualToString:M2WidgetDeepLinkHost]) {
        return nil;
    }

    NSString *path = url.path ?: @"";
    if (path.length > 0 && ![path isEqualToString:M2WidgetDeepLinkPath]) {
        return nil;
    }

    NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    for (NSURLQueryItem *item in components.queryItems) {
        if (![item.name isEqualToString:M2WidgetDeepLinkTrackIDQueryItem]) {
            continue;
        }
        if (item.value.length > 0) {
            return item.value;
        }
        break;
    }

    return @"";
}

+ (void)playTrackWithIdentifier:(NSString *)trackID {
    M2LibraryManager *library = M2LibraryManager.sharedManager;
    if (library.tracks.count == 0) {
        [library reloadTracks];
    }

    M2Track *track = nil;
    if (trackID.length > 0) {
        track = [library trackForIdentifier:trackID];
    }

    if (track == nil) {
        NSArray<M2Track *> *lovelyTracks = [self lovelyTracksFromLibrary];
        if (lovelyTracks.count > 0) {
            NSUInteger index = arc4random_uniform((uint32_t)lovelyTracks.count);
            track = lovelyTracks[index];
        }
    }

    if (track == nil) {
        return;
    }

    [M2PlaybackManager.sharedManager playTrack:track];
}

+ (BOOL)handleWidgetDeepLinkURL:(NSURL *)url {
    NSString *trackID = [self trackIDFromDeepLinkURL:url];
    if (trackID == nil) {
        return NO;
    }

    if (NSThread.isMainThread) {
        [self playTrackWithIdentifier:trackID];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self playTrackWithIdentifier:trackID];
        });
    }

    return YES;
}

@end
