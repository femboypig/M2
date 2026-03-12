#import "SonoraSharedPlaylists.h"
#import "SonoraSettings.h"

static NSString * const SonoraMiniStreamingDefaultBackendBaseURLString = @"https://api.corebrew.ru";
static NSString * const SonoraSharedPlaylistDefaultsKey = @"sonora.sharedPlaylists.v1";
static NSString * const SonoraSharedPlaylistSyntheticPrefix = @"shared:";
static NSString * const SonoraSharedPlaylistSuppressDidChangeNotificationThreadKey = @"sonora.sharedPlaylists.suppressDidChangeNotification";

static UIImage * _Nullable SonoraSharedPlaylistImageFromData(NSData *data) {
    if (data.length == 0) {
        return nil;
    }
    return [UIImage imageWithData:data scale:UIScreen.mainScreen.scale];
}

NSString *SonoraSharedPlaylistStorageDirectoryPath(void) {
    NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *base = paths.firstObject ?: NSTemporaryDirectory();
    NSString *directory = [base stringByAppendingPathComponent:@"SonoraSharedPlaylists"];
    [NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
    return directory;
}

static NSString * _Nullable SonoraSharedPlaylistWriteImageInDirectory(UIImage *image,
                                                                      NSString *preferredName,
                                                                      NSString *directoryPath) {
    if (image == nil) {
        return nil;
    }
    NSData *data = UIImageJPEGRepresentation(image, 0.84);
    if (data.length == 0) {
        return nil;
    }
    NSString *fileName = preferredName.length > 0 ? preferredName : [NSString stringWithFormat:@"%@.jpg", NSUUID.UUID.UUIDString.lowercaseString];
    if (directoryPath.length == 0) {
        directoryPath = SonoraSharedPlaylistStorageDirectoryPath();
    }
    NSString *path = [directoryPath stringByAppendingPathComponent:fileName];
    if (![data writeToFile:path atomically:YES]) {
        return nil;
    }
    return path.lastPathComponent;
}

static UIImage * _Nullable SonoraSharedPlaylistReadImageNamedInDirectory(NSString *fileName, NSString *directoryPath) {
    if (fileName.length == 0) {
        return nil;
    }
    if (directoryPath.length == 0) {
        directoryPath = SonoraSharedPlaylistStorageDirectoryPath();
    }
    NSString *path = [directoryPath stringByAppendingPathComponent:fileName];
    NSData *data = [NSData dataWithContentsOfFile:path];
    return SonoraSharedPlaylistImageFromData(data);
}

static UIImage * _Nullable SonoraSharedPlaylistFetchImage(NSString *urlString) {
    if (urlString.length == 0) {
        return nil;
    }
    NSURL *url = [NSURL URLWithString:urlString];
    if (url == nil) {
        return nil;
    }
    NSData *data = [NSData dataWithContentsOfURL:url options:NSDataReadingMappedIfSafe error:nil];
    return SonoraSharedPlaylistImageFromData(data);
}

static NSURLSession *SonoraSharedPlaylistURLSession(void) {
    static NSURLSession *session;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        configuration.timeoutIntervalForRequest = 60.0;
        configuration.timeoutIntervalForResource = 600.0;
        configuration.waitsForConnectivity = NO;
        session = [NSURLSession sessionWithConfiguration:configuration];
    });
    return session;
}

static dispatch_time_t SonoraSharedPlaylistDispatchTimeout(NSTimeInterval timeout) {
    NSTimeInterval seconds = MAX(MAX(timeout, 30.0) * 2.0, 60.0);
    return dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * (NSTimeInterval)NSEC_PER_SEC));
}

NSString *SonoraSharedPlaylistSyntheticID(NSString *remoteID) {
    NSString *resolved = [remoteID isKindOfClass:NSString.class] ? remoteID : @"";
    return [NSString stringWithFormat:@"%@%@", SonoraSharedPlaylistSyntheticPrefix, resolved];
}

NSString *SonoraSharedPlaylistBackendBaseURLString(void) {
    NSString *configured = [NSBundle.mainBundle objectForInfoDictionaryKey:@"BACKEND_BASE_URL"];
    if ([configured isKindOfClass:NSString.class] && configured.length > 0) {
        return [configured stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    }
    return SonoraMiniStreamingDefaultBackendBaseURLString;
}

NSString *SonoraSharedPlaylistNormalizeText(NSString *value) {
    NSString *trimmed = [[value ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] lowercaseString];
    return trimmed ?: @"";
}

NSString *SonoraSharedPlaylistAudioCacheDirectoryPath(void) {
    NSString *directory = [SonoraSharedPlaylistStorageDirectoryPath() stringByAppendingPathComponent:@"audio"];
    [NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
    return directory;
}

static NSString *SonoraSharedPlaylistAudioCacheDirectoryPathForStorageDirectory(NSString *storageDirectoryPath) {
    NSString *directory = [storageDirectoryPath stringByAppendingPathComponent:@"audio"];
    [NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
    return directory;
}

NSData * _Nullable SonoraSharedPlaylistDataFromURL(NSURL *url,
                                                   NSTimeInterval timeout,
                                                   NSURLResponse * __autoreleasing _Nullable *responseOut) {
    if (url == nil) {
        return nil;
    }

    __block NSData *result = nil;
    __block NSURLResponse *capturedResponse = nil;
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.timeoutInterval = MAX(timeout, 30.0);
    NSURLSessionDataTask *task = [SonoraSharedPlaylistURLSession() dataTaskWithRequest:request
                                                                     completionHandler:^(NSData * _Nullable data,
                                                                                         NSURLResponse * _Nullable response,
                                                                                         NSError * _Nullable error) {
        capturedResponse = response;
        NSHTTPURLResponse *http = [response isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse *)response : nil;
        if (error == nil && data.length > 0 && (http == nil || (http.statusCode >= 200 && http.statusCode < 300))) {
            result = data;
        }
        dispatch_group_leave(group);
    }];
    [task resume];

    if (dispatch_group_wait(group, SonoraSharedPlaylistDispatchTimeout(timeout)) != 0) {
        [task cancel];
    }

    if (responseOut != NULL) {
        *responseOut = capturedResponse;
    }
    return result;
}

NSData * _Nullable SonoraSharedPlaylistPerformRequest(NSURLRequest *request,
                                                      NSTimeInterval timeout,
                                                      NSHTTPURLResponse * __autoreleasing _Nullable *responseOut) {
    if (request == nil) {
        return nil;
    }

    NSMutableURLRequest *mutableRequest = [request mutableCopy];
    mutableRequest.timeoutInterval = MAX(timeout, 30.0);

    __block NSData *result = nil;
    __block NSHTTPURLResponse *capturedResponse = nil;
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);

    NSURLSessionDataTask *task = [SonoraSharedPlaylistURLSession() dataTaskWithRequest:mutableRequest
                                                                     completionHandler:^(NSData * _Nullable data,
                                                                                         NSURLResponse * _Nullable response,
                                                                                         NSError * _Nullable error) {
        if ([response isKindOfClass:NSHTTPURLResponse.class]) {
            capturedResponse = (NSHTTPURLResponse *)response;
        }
        if (error == nil && capturedResponse != nil && capturedResponse.statusCode >= 200 && capturedResponse.statusCode < 300) {
            result = data ?: NSData.data;
        }
        dispatch_group_leave(group);
    }];
    [task resume];

    if (dispatch_group_wait(group, SonoraSharedPlaylistDispatchTimeout(timeout)) != 0) {
        [task cancel];
    }

    if (responseOut != NULL) {
        *responseOut = capturedResponse;
    }
    return result;
}

void SonoraSharedPlaylistAppendMultipartText(NSMutableData *body, NSString *boundary, NSString *name, NSString *value) {
    if (body == nil || boundary.length == 0 || name.length == 0 || value == nil) {
        return;
    }
    [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", name] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[value dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
}

void SonoraSharedPlaylistAppendMultipartFile(NSMutableData *body,
                                             NSString *boundary,
                                             NSString *name,
                                             NSString *filename,
                                             NSString *mimeType,
                                             NSData *data) {
    if (body == nil || boundary.length == 0 || name.length == 0 || data.length == 0) {
        return;
    }
    NSString *safeFilename = filename.length > 0 ? filename : @"file.bin";
    NSString *safeMime = mimeType.length > 0 ? mimeType : @"application/octet-stream";
    [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\n", name, safeFilename] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Type: %@\r\n\r\n", safeMime] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:data];
    [body appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
}

static NSString *SonoraSharedPlaylistSafeFileComponent(NSString *value) {
    NSString *trimmed = [[value ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] copy];
    if (trimmed.length == 0) {
        return @"track";
    }
    NSCharacterSet *invalid = [[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_ ."] invertedSet];
    NSString *safe = [[trimmed componentsSeparatedByCharactersInSet:invalid] componentsJoinedByString:@"_"];
    while ([safe containsString:@"__"]) {
        safe = [safe stringByReplacingOccurrencesOfString:@"__" withString:@"_"];
    }
    return safe.length > 0 ? safe : @"track";
}

NSURL * _Nullable SonoraSharedPlaylistDownloadedFileURL(NSString *urlString, NSString *suggestedBaseName) {
    NSURL *remoteURL = [NSURL URLWithString:urlString];
    if (remoteURL == nil) {
        return nil;
    }
    NSURLResponse *response = nil;
    NSData *data = SonoraSharedPlaylistDataFromURL(remoteURL, 600.0, &response);
    if (data.length == 0) {
        return nil;
    }
    NSURL *musicDirectoryURL = [SonoraLibraryManager.sharedManager musicDirectoryURL];
    NSString *extension = response.suggestedFilename.pathExtension.lowercaseString;
    if (extension.length == 0) {
        extension = remoteURL.pathExtension.length > 0 ? remoteURL.pathExtension.lowercaseString : @"";
    }
    if (extension.length == 0) {
        NSString *mimeType = response.MIMEType.lowercaseString;
        if ([mimeType containsString:@"mp4"]) {
            extension = @"m4a";
        } else if ([mimeType containsString:@"aac"]) {
            extension = @"aac";
        } else if ([mimeType containsString:@"wav"]) {
            extension = @"wav";
        } else if ([mimeType containsString:@"ogg"]) {
            extension = @"ogg";
        } else if ([mimeType containsString:@"flac"]) {
            extension = @"flac";
        } else {
            extension = @"mp3";
        }
    }
    NSString *baseName = SonoraSharedPlaylistSafeFileComponent(suggestedBaseName);
    NSURL *destinationURL = [musicDirectoryURL URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@", baseName, extension]];
    NSUInteger suffix = 1;
    while ([NSFileManager.defaultManager fileExistsAtPath:destinationURL.path]) {
        destinationURL = [musicDirectoryURL URLByAppendingPathComponent:[NSString stringWithFormat:@"%@ %lu.%@", baseName, (unsigned long)suffix, extension]];
        suffix += 1;
    }
    if (![data writeToURL:destinationURL atomically:YES]) {
        return nil;
    }
    return destinationURL;
}

SonoraSharedPlaylistSnapshot * _Nullable SonoraSharedPlaylistSnapshotFromPayload(NSDictionary<NSString *, id> *payload,
                                                                                 NSString *fallbackBaseURL) {
    if (![payload isKindOfClass:NSDictionary.class]) {
        return nil;
    }
    NSString *remoteID = [payload[@"id"] isKindOfClass:NSString.class] ? payload[@"id"] : @"";
    NSString *name = [payload[@"name"] isKindOfClass:NSString.class] ? payload[@"name"] : @"Shared Playlist";
    if (remoteID.length == 0 || name.length == 0) {
        return nil;
    }

    SonoraSharedPlaylistSnapshot *snapshot = [[SonoraSharedPlaylistSnapshot alloc] init];
    snapshot.remoteID = remoteID;
    snapshot.playlistID = SonoraSharedPlaylistSyntheticID(remoteID);
    snapshot.name = name;
    snapshot.shareURL = [payload[@"shareUrl"] isKindOfClass:NSString.class] ? payload[@"shareUrl"] : ([payload[@"url"] isKindOfClass:NSString.class] ? payload[@"url"] : @"");
    snapshot.sourceBaseURL = [payload[@"sourceBaseURL"] isKindOfClass:NSString.class] ? payload[@"sourceBaseURL"] : fallbackBaseURL;
    snapshot.contentSHA256 = [payload[@"contentSha256"] isKindOfClass:NSString.class] ? payload[@"contentSha256"] : @"";

    NSString *coverURL = [payload[@"coverUrl"] isKindOfClass:NSString.class] ? payload[@"coverUrl"] : @"";
    snapshot.coverURL = coverURL;
    snapshot.coverImage = nil;

    NSArray *trackItems = [payload[@"tracks"] isKindOfClass:NSArray.class] ? payload[@"tracks"] : @[];
    NSMutableArray<SonoraTrack *> *tracks = [NSMutableArray arrayWithCapacity:trackItems.count];
    NSMutableDictionary<NSString *, NSString *> *trackArtworkURLByTrackID = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSString *, NSString *> *trackRemoteFileURLByTrackID = [NSMutableDictionary dictionary];
    [trackItems enumerateObjectsUsingBlock:^(NSDictionary * _Nonnull item, NSUInteger idx, __unused BOOL * _Nonnull stop) {
        if (![item isKindOfClass:NSDictionary.class]) {
            return;
        }
        SonoraTrack *track = [[SonoraTrack alloc] init];
        track.identifier = [NSString stringWithFormat:@"%@:%lu", snapshot.playlistID, (unsigned long)idx];
        track.title = [item[@"title"] isKindOfClass:NSString.class] ? item[@"title"] : [NSString stringWithFormat:@"Track %lu", (unsigned long)(idx + 1)];
        track.artist = [item[@"artist"] isKindOfClass:NSString.class] ? item[@"artist"] : @"";
        track.duration = [item[@"durationMs"] respondsToSelector:@selector(doubleValue)] ? [item[@"durationMs"] doubleValue] / 1000.0 : 0.0;
        NSString *fileURLString = [item[@"fileUrl"] isKindOfClass:NSString.class] ? item[@"fileUrl"] : @"";
        track.url = [NSURL URLWithString:fileURLString] ?: [NSURL fileURLWithPath:@"/dev/null"];
        if (fileURLString.length > 0) {
            trackRemoteFileURLByTrackID[track.identifier] = fileURLString;
        }
        track.artwork = nil;
        NSString *artworkURLString = [item[@"artworkUrl"] isKindOfClass:NSString.class] ? item[@"artworkUrl"] : @"";
        if (artworkURLString.length > 0) {
            trackArtworkURLByTrackID[track.identifier] = artworkURLString;
        }
        [tracks addObject:track];
    }];
    snapshot.tracks = tracks.copy;
    snapshot.trackArtworkURLByTrackID = trackArtworkURLByTrackID.copy;
    snapshot.trackRemoteFileURLByTrackID = trackRemoteFileURLByTrackID.copy;
    return snapshot;
}

static BOOL SonoraSharedPlaylistShouldSuppressDidChangeNotification(void) {
    return [NSThread.currentThread.threadDictionary[SonoraSharedPlaylistSuppressDidChangeNotificationThreadKey] boolValue];
}

void SonoraSharedPlaylistPerformWithoutDidChangeNotification(dispatch_block_t block) {
    if (block == nil) {
        return;
    }
    NSMutableDictionary<NSString *, id> *threadDictionary = NSThread.currentThread.threadDictionary;
    id previousValue = threadDictionary[SonoraSharedPlaylistSuppressDidChangeNotificationThreadKey];
    threadDictionary[SonoraSharedPlaylistSuppressDidChangeNotificationThreadKey] = @YES;
    @try {
        block();
    } @finally {
        if (previousValue != nil) {
            threadDictionary[SonoraSharedPlaylistSuppressDidChangeNotificationThreadKey] = previousValue;
        } else {
            [threadDictionary removeObjectForKey:SonoraSharedPlaylistSuppressDidChangeNotificationThreadKey];
        }
    }
}

static void SonoraSharedPlaylistPostDidChangeNotification(void) {
    void (^postNotification)(void) = ^{
        [NSNotificationCenter.defaultCenter postNotificationName:SonoraPlaylistsDidChangeNotification object:nil];
    };
    if (NSThread.isMainThread) {
        postNotification();
    } else {
        dispatch_async(dispatch_get_main_queue(), postNotification);
    }
}

void SonoraSharedPlaylistWarmPersistentCache(SonoraSharedPlaylistSnapshot *snapshot) {
    if (snapshot == nil) {
        return;
    }

    void (^persistSnapshotIfNeeded)(void) = ^{
        SonoraSharedPlaylistPerformWithoutDidChangeNotification(^{
            [SonoraSharedPlaylistStore.sharedStore saveSnapshot:snapshot];
        });
    };

    if (snapshot.coverImage == nil && snapshot.coverURL.length > 0) {
        snapshot.coverImage = SonoraSharedPlaylistFetchImage(snapshot.coverURL);
        persistSnapshotIfNeeded();
    }
    for (SonoraTrack *track in snapshot.tracks) {
        if (track.artwork != nil || track.identifier.length == 0) {
            continue;
        }
        NSString *artworkURL = snapshot.trackArtworkURLByTrackID[track.identifier];
        if (artworkURL.length == 0) {
            continue;
        }
        track.artwork = SonoraSharedPlaylistFetchImage(artworkURL);
        persistSnapshotIfNeeded();
    }
    if (SonoraSettingsCacheOnlinePlaylistTracksEnabled()) {
        unsigned long long limitBytes = ULLONG_MAX;
        NSInteger maxMB = SonoraSettingsOnlinePlaylistCacheMaxMB();
        if (maxMB > 0) {
            limitBytes = ((unsigned long long)maxMB) * 1024ULL * 1024ULL;
        } else {
            limitBytes = 1024ULL * 1024ULL * 1024ULL;
        }
        NSString *audioDirectory = SonoraSharedPlaylistAudioCacheDirectoryPath();
        [NSFileManager.defaultManager createDirectoryAtPath:audioDirectory withIntermediateDirectories:YES attributes:nil error:nil];
        [snapshot.tracks enumerateObjectsUsingBlock:^(SonoraTrack * _Nonnull track, NSUInteger idx, __unused BOOL * _Nonnull stop) {
            NSString *remoteFileURL = snapshot.trackRemoteFileURLByTrackID[track.identifier ?: @""];
            if (remoteFileURL.length == 0 && !track.url.isFileURL) {
                remoteFileURL = track.url.absoluteString ?: @"";
            }
            if (remoteFileURL.length == 0) {
                return;
            }

            NSString *existingLocalPath = track.url.isFileURL ? track.url.path : @"";
            if (existingLocalPath.length > 0 && [NSFileManager.defaultManager fileExistsAtPath:existingLocalPath]) {
                [NSFileManager.defaultManager setAttributes:@{ NSFileModificationDate : NSDate.date }
                                               ofItemAtPath:existingLocalPath
                                                      error:nil];
                return;
            }

            NSURL *remoteURL = [NSURL URLWithString:remoteFileURL];
            if (remoteURL == nil) {
                return;
            }
            NSURLResponse *response = nil;
            NSData *audioData = SonoraSharedPlaylistDataFromURL(remoteURL, 600.0, &response);
            if (audioData.length == 0) {
                return;
            }
            if (limitBytes != ULLONG_MAX && (unsigned long long)audioData.length > limitBytes) {
                return;
            }

            NSString *extension = remoteURL.pathExtension.lowercaseString;
            if (extension.length == 0 && [response isKindOfClass:NSHTTPURLResponse.class]) {
                NSString *mimeType = ((NSHTTPURLResponse *)response).MIMEType.lowercaseString ?: @"";
                if ([mimeType containsString:@"mpeg"]) {
                    extension = @"mp3";
                } else if ([mimeType containsString:@"mp4"] || [mimeType containsString:@"aac"]) {
                    extension = @"m4a";
                } else if ([mimeType containsString:@"wav"]) {
                    extension = @"wav";
                } else if ([mimeType containsString:@"flac"]) {
                    extension = @"flac";
                }
            }
            if (extension.length == 0) {
                extension = @"audio";
            }

            NSString *fileName = [NSString stringWithFormat:@"%@_%lu.%@", snapshot.remoteID.length > 0 ? snapshot.remoteID : @"shared",
                                  (unsigned long)idx,
                                  extension];
            NSString *path = [audioDirectory stringByAppendingPathComponent:fileName];
            NSUInteger suffix = 1;
            while ([NSFileManager.defaultManager fileExistsAtPath:path]) {
                fileName = [NSString stringWithFormat:@"%@_%lu_%lu.%@",
                            snapshot.remoteID.length > 0 ? snapshot.remoteID : @"shared",
                            (unsigned long)idx,
                            (unsigned long)suffix,
                            extension];
                path = [audioDirectory stringByAppendingPathComponent:fileName];
                suffix += 1;
            }
            if (![audioData writeToFile:path atomically:YES]) {
                return;
            }
            track.url = [NSURL fileURLWithPath:path];
            persistSnapshotIfNeeded();
        }];
    }
}

@implementation SonoraSharedPlaylistSnapshot
@end

@interface SonoraSharedPlaylistStore ()

@property (nonatomic, strong) NSUserDefaults *userDefaults;
@property (nonatomic, strong) NSURL *storageDirectoryURL;

@end

@implementation SonoraSharedPlaylistStore

+ (instancetype)sharedStore {
    static SonoraSharedPlaylistStore *store;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        store = [[SonoraSharedPlaylistStore alloc] init];
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            [store refreshAllPersistentCachesIfNeeded];
        });
    });
    return store;
}

- (instancetype)init {
    NSURL *storageDirectoryURL = [NSURL fileURLWithPath:SonoraSharedPlaylistStorageDirectoryPath() isDirectory:YES];
    return [self initWithUserDefaults:NSUserDefaults.standardUserDefaults
                  storageDirectoryURL:storageDirectoryURL];
}

- (instancetype)initWithUserDefaults:(NSUserDefaults *)userDefaults
                 storageDirectoryURL:(NSURL *)storageDirectoryURL {
    self = [super init];
    if (self == nil) {
        return nil;
    }

    _userDefaults = userDefaults ?: NSUserDefaults.standardUserDefaults;
    _storageDirectoryURL = storageDirectoryURL ?: [NSURL fileURLWithPath:SonoraSharedPlaylistStorageDirectoryPath() isDirectory:YES];
    [NSFileManager.defaultManager createDirectoryAtURL:_storageDirectoryURL
                           withIntermediateDirectories:YES
                                            attributes:nil
                                                 error:nil];
    return self;
}

- (NSArray<NSDictionary<NSString *, id> *> *)storedDictionaries {
    NSArray *items = [self.userDefaults arrayForKey:SonoraSharedPlaylistDefaultsKey];
    if (![items isKindOfClass:NSArray.class]) {
        return @[];
    }
    return items;
}

- (NSArray<SonoraPlaylist *> *)likedPlaylists {
    NSMutableArray<SonoraPlaylist *> *playlists = [NSMutableArray array];
    for (NSDictionary<NSString *, id> *item in [self storedDictionaries]) {
        NSString *playlistID = [item[@"playlistID"] isKindOfClass:NSString.class] ? item[@"playlistID"] : @"";
        NSString *name = [item[@"name"] isKindOfClass:NSString.class] ? item[@"name"] : @"";
        NSArray *tracks = [item[@"tracks"] isKindOfClass:NSArray.class] ? item[@"tracks"] : @[];
        if (playlistID.length == 0 || name.length == 0) {
            continue;
        }
        NSMutableArray<NSString *> *trackIDs = [NSMutableArray arrayWithCapacity:tracks.count];
        for (NSUInteger index = 0; index < tracks.count; index += 1) {
            [trackIDs addObject:[NSString stringWithFormat:@"%@:%lu", playlistID, (unsigned long)index]];
        }
        SonoraPlaylist *playlist = [[SonoraPlaylist alloc] init];
        playlist.playlistID = playlistID;
        playlist.name = name;
        playlist.trackIDs = trackIDs.copy;
        [playlists addObject:playlist];
    }
    return playlists.copy;
}

- (void)refreshAllPersistentCachesIfNeeded {
    for (NSDictionary<NSString *, id> *item in [self storedDictionaries]) {
        NSString *playlistID = [item[@"playlistID"] isKindOfClass:NSString.class] ? item[@"playlistID"] : @"";
        if (playlistID.length == 0) {
            continue;
        }
        SonoraSharedPlaylistSnapshot *snapshot = [self snapshotForPlaylistID:playlistID];
        if (snapshot != nil) {
            SonoraSharedPlaylistWarmPersistentCache(snapshot);
        }
    }
}

- (nullable SonoraSharedPlaylistSnapshot *)snapshotForPlaylistID:(NSString *)playlistID {
    if (playlistID.length == 0) {
        return nil;
    }
    for (NSDictionary<NSString *, id> *item in [self storedDictionaries]) {
        if (![item[@"playlistID"] isKindOfClass:NSString.class] || ![item[@"playlistID"] isEqualToString:playlistID]) {
            continue;
        }
        SonoraSharedPlaylistSnapshot *snapshot = [[SonoraSharedPlaylistSnapshot alloc] init];
        snapshot.playlistID = item[@"playlistID"];
        snapshot.remoteID = [item[@"remoteID"] isKindOfClass:NSString.class] ? item[@"remoteID"] : @"";
        snapshot.name = [item[@"name"] isKindOfClass:NSString.class] ? item[@"name"] : @"Shared Playlist";
        snapshot.shareURL = [item[@"shareURL"] isKindOfClass:NSString.class] ? item[@"shareURL"] : @"";
        snapshot.sourceBaseURL = [item[@"sourceBaseURL"] isKindOfClass:NSString.class] ? item[@"sourceBaseURL"] : SonoraSharedPlaylistBackendBaseURLString();
        snapshot.contentSHA256 = [item[@"contentSHA256"] isKindOfClass:NSString.class] ? item[@"contentSHA256"] : @"";
        snapshot.coverURL = [item[@"coverURL"] isKindOfClass:NSString.class] ? item[@"coverURL"] : @"";
        snapshot.coverImage = SonoraSharedPlaylistReadImageNamedInDirectory([item[@"coverFileName"] isKindOfClass:NSString.class] ? item[@"coverFileName"] : @"",
                                                                            self.storageDirectoryURL.path);

        NSArray *trackItems = [item[@"tracks"] isKindOfClass:NSArray.class] ? item[@"tracks"] : @[];
        NSMutableArray<SonoraTrack *> *tracks = [NSMutableArray arrayWithCapacity:trackItems.count];
        NSMutableDictionary<NSString *, NSString *> *trackArtworkURLByTrackID = [NSMutableDictionary dictionary];
        NSMutableDictionary<NSString *, NSString *> *trackRemoteFileURLByTrackID = [NSMutableDictionary dictionary];
        [trackItems enumerateObjectsUsingBlock:^(NSDictionary * _Nonnull trackDict, NSUInteger idx, __unused BOOL * _Nonnull stop) {
            if (![trackDict isKindOfClass:NSDictionary.class]) {
                return;
            }
            SonoraTrack *track = [[SonoraTrack alloc] init];
            track.identifier = [NSString stringWithFormat:@"%@:%lu", playlistID, (unsigned long)idx];
            track.title = [trackDict[@"title"] isKindOfClass:NSString.class] ? trackDict[@"title"] : [NSString stringWithFormat:@"Track %lu", (unsigned long)(idx + 1)];
            track.artist = [trackDict[@"artist"] isKindOfClass:NSString.class] ? trackDict[@"artist"] : @"";
            track.duration = [trackDict[@"durationMs"] respondsToSelector:@selector(doubleValue)] ? [trackDict[@"durationMs"] doubleValue] / 1000.0 : 0.0;
            NSString *fileURLString = [trackDict[@"fileURL"] isKindOfClass:NSString.class] ? trackDict[@"fileURL"] : @"";
            NSString *remoteFileURLString = [trackDict[@"remoteFileURL"] isKindOfClass:NSString.class] ? trackDict[@"remoteFileURL"] : @"";
            NSURL *resolvedURL = [NSURL URLWithString:fileURLString];
            if (resolvedURL.isFileURL && resolvedURL.path.length > 0 && ![NSFileManager.defaultManager fileExistsAtPath:resolvedURL.path]) {
                resolvedURL = nil;
            }
            if (resolvedURL == nil && remoteFileURLString.length > 0) {
                resolvedURL = [NSURL URLWithString:remoteFileURLString];
            }
            track.url = resolvedURL ?: [NSURL fileURLWithPath:@"/dev/null"];
            if (remoteFileURLString.length > 0) {
                trackRemoteFileURLByTrackID[track.identifier] = remoteFileURLString;
            } else if (fileURLString.length > 0 && !track.url.isFileURL) {
                trackRemoteFileURLByTrackID[track.identifier] = fileURLString;
            }
            track.artwork = SonoraSharedPlaylistReadImageNamedInDirectory([trackDict[@"artworkFileName"] isKindOfClass:NSString.class] ? trackDict[@"artworkFileName"] : @"",
                                                                          self.storageDirectoryURL.path);
            NSString *artworkURLString = [trackDict[@"artworkURL"] isKindOfClass:NSString.class] ? trackDict[@"artworkURL"] : @"";
            if (artworkURLString.length > 0) {
                trackArtworkURLByTrackID[track.identifier] = artworkURLString;
            }
            [tracks addObject:track];
        }];
        snapshot.tracks = tracks.copy;
        snapshot.trackArtworkURLByTrackID = trackArtworkURLByTrackID.copy;
        snapshot.trackRemoteFileURLByTrackID = trackRemoteFileURLByTrackID.copy;
        return snapshot;
    }
    return nil;
}

- (BOOL)isSnapshotLikedForPlaylistID:(NSString *)playlistID {
    return ([self snapshotForPlaylistID:playlistID] != nil);
}

- (void)saveSnapshot:(SonoraSharedPlaylistSnapshot *)snapshot {
    if (snapshot.playlistID.length == 0) {
        return;
    }
    NSMutableArray<NSDictionary<NSString *, id> *> *stored = [[self storedDictionaries] mutableCopy];
    NSIndexSet *matches = [stored indexesOfObjectsPassingTest:^BOOL(NSDictionary<NSString *,id> * _Nonnull item, __unused NSUInteger idx, __unused BOOL * _Nonnull stop) {
        return [item[@"playlistID"] isEqualToString:snapshot.playlistID];
    }];
    if (matches.count > 0) {
        [stored removeObjectsAtIndexes:matches];
    }

    NSMutableDictionary<NSString *, id> *dictionary = [NSMutableDictionary dictionary];
    dictionary[@"playlistID"] = snapshot.playlistID;
    dictionary[@"remoteID"] = snapshot.remoteID ?: @"";
    dictionary[@"name"] = snapshot.name ?: @"Shared Playlist";
    dictionary[@"shareURL"] = snapshot.shareURL ?: @"";
    dictionary[@"sourceBaseURL"] = snapshot.sourceBaseURL ?: SonoraSharedPlaylistBackendBaseURLString();
    dictionary[@"contentSHA256"] = snapshot.contentSHA256 ?: @"";
    dictionary[@"coverURL"] = snapshot.coverURL ?: @"";

    NSString *coverFileName = SonoraSharedPlaylistWriteImageInDirectory(snapshot.coverImage,
                                                                        [NSString stringWithFormat:@"%@_cover.jpg", snapshot.remoteID.length > 0 ? snapshot.remoteID : NSUUID.UUID.UUIDString.lowercaseString],
                                                                        self.storageDirectoryURL.path);
    if (coverFileName.length > 0) {
        dictionary[@"coverFileName"] = coverFileName;
    }

    NSMutableArray<NSDictionary<NSString *, id> *> *trackItems = [NSMutableArray arrayWithCapacity:snapshot.tracks.count];
    [snapshot.tracks enumerateObjectsUsingBlock:^(SonoraTrack * _Nonnull track, NSUInteger idx, __unused BOOL * _Nonnull stop) {
        NSMutableDictionary<NSString *, id> *trackDict = [NSMutableDictionary dictionary];
        trackDict[@"title"] = track.title ?: @"";
        trackDict[@"artist"] = track.artist ?: @"";
        trackDict[@"durationMs"] = @((NSInteger)llround(MAX(track.duration, 0.0) * 1000.0));
        trackDict[@"fileURL"] = track.url.absoluteString ?: @"";
        NSString *remoteFileURL = snapshot.trackRemoteFileURLByTrackID[track.identifier ?: @""];
        if (remoteFileURL.length == 0 && !track.url.isFileURL) {
            remoteFileURL = track.url.absoluteString ?: @"";
        }
        if (remoteFileURL.length > 0) {
            trackDict[@"remoteFileURL"] = remoteFileURL;
        }
        NSString *artworkURL = snapshot.trackArtworkURLByTrackID[track.identifier ?: @""];
        if (artworkURL.length > 0) {
            trackDict[@"artworkURL"] = artworkURL;
        }
        NSString *artworkName = SonoraSharedPlaylistWriteImageInDirectory(track.artwork,
                                                                          [NSString stringWithFormat:@"%@_%lu.jpg", snapshot.remoteID.length > 0 ? snapshot.remoteID : @"shared", (unsigned long)idx],
                                                                          self.storageDirectoryURL.path);
        if (artworkName.length > 0) {
            trackDict[@"artworkFileName"] = artworkName;
        }
        [trackItems addObject:trackDict];
    }];
    dictionary[@"tracks"] = trackItems.copy;

    [stored insertObject:dictionary.copy atIndex:0];
    [self.userDefaults setObject:stored.copy forKey:SonoraSharedPlaylistDefaultsKey];
    [self.userDefaults synchronize];
    if (!SonoraSharedPlaylistShouldSuppressDidChangeNotification()) {
        SonoraSharedPlaylistPostDidChangeNotification();
    }
}

- (void)removeSnapshotForPlaylistID:(NSString *)playlistID {
    if (playlistID.length == 0) {
        return;
    }
    NSMutableArray<NSDictionary<NSString *, id> *> *stored = [[self storedDictionaries] mutableCopy];
    NSIndexSet *matches = [stored indexesOfObjectsPassingTest:^BOOL(NSDictionary<NSString *,id> * _Nonnull item, __unused NSUInteger idx, __unused BOOL * _Nonnull stop) {
        return [item[@"playlistID"] isEqualToString:playlistID];
    }];
    if (matches.count == 0) {
        return;
    }
    NSArray<NSDictionary<NSString *, id> *> *itemsToRemove = [stored objectsAtIndexes:matches];
    NSString *audioCacheDirectory = SonoraSharedPlaylistAudioCacheDirectoryPathForStorageDirectory(self.storageDirectoryURL.path);
    for (NSDictionary<NSString *, id> *item in itemsToRemove) {
        NSString *coverFileName = [item[@"coverFileName"] isKindOfClass:NSString.class] ? item[@"coverFileName"] : @"";
        if (coverFileName.length > 0) {
            NSString *coverPath = [self.storageDirectoryURL.path stringByAppendingPathComponent:coverFileName];
            [NSFileManager.defaultManager removeItemAtPath:coverPath error:nil];
        }
        NSArray *trackItems = [item[@"tracks"] isKindOfClass:NSArray.class] ? item[@"tracks"] : @[];
        for (NSDictionary<NSString *, id> *trackItem in trackItems) {
            NSString *artworkFileName = [trackItem[@"artworkFileName"] isKindOfClass:NSString.class] ? trackItem[@"artworkFileName"] : @"";
            if (artworkFileName.length > 0) {
                NSString *artworkPath = [self.storageDirectoryURL.path stringByAppendingPathComponent:artworkFileName];
                [NSFileManager.defaultManager removeItemAtPath:artworkPath error:nil];
            }
            NSString *fileURLString = [trackItem[@"fileURL"] isKindOfClass:NSString.class] ? trackItem[@"fileURL"] : @"";
            NSURL *fileURL = [NSURL URLWithString:fileURLString];
            if (fileURL.isFileURL &&
                fileURL.path.length > 0 &&
                [fileURL.path hasPrefix:audioCacheDirectory]) {
                [NSFileManager.defaultManager removeItemAtPath:fileURL.path error:nil];
            }
        }
    }
    [stored removeObjectsAtIndexes:matches];
    [self.userDefaults setObject:stored.copy forKey:SonoraSharedPlaylistDefaultsKey];
    [self.userDefaults synchronize];
    if (!SonoraSharedPlaylistShouldSuppressDidChangeNotification()) {
        SonoraSharedPlaylistPostDidChangeNotification();
    }
}

@end
