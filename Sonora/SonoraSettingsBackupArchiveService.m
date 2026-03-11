#import "SonoraSettingsBackupArchiveService.h"

#import <CoreFoundation/CoreFoundation.h>

#import "SonoraServices.h"

NSString * const SonoraBackupArchiveErrorDomain = @"SonoraBackupArchive";

static NSString * const SonoraBackupArchiveMagicString = @"SONORAAR";
static NSString * const SonoraBackupManifestEntryName = @"meta/manifest.v1";
static NSInteger const SonoraBackupArchiveVersion = 1;

static NSString *SonoraSettingsBackupStableHashString(NSString *value) {
    if (value.length == 0) {
        return @"0";
    }

    NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding];
    if (data.length == 0) {
        return @"0";
    }

    const uint8_t *bytes = data.bytes;
    uint64_t hash = 1469598103934665603ULL;
    for (NSUInteger index = 0; index < data.length; index += 1) {
        hash ^= bytes[index];
        hash *= 1099511628211ULL;
    }

    return [NSString stringWithFormat:@"%016llx", hash];
}

@interface SonoraSettingsBackupArchiveService ()

@property (nonatomic, strong) id<SonoraBackupLibraryManaging> libraryManager;
@property (nonatomic, strong) id<SonoraBackupPlaylistStoring> playlistStore;
@property (nonatomic, strong) id<SonoraBackupFavoritesStoring> favoritesStore;
@property (nonatomic, strong) NSUserDefaults *defaults;
@property (nonatomic, strong) NSURL *documentsURL;

@end

@implementation SonoraSettingsBackupArchiveService

- (instancetype)init {
    NSURL *documentsURL = [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    return [self initWithLibraryManager:(id<SonoraBackupLibraryManaging>)SonoraLibraryManager.sharedManager
                          playlistStore:(id<SonoraBackupPlaylistStoring>)SonoraPlaylistStore.sharedStore
                         favoritesStore:(id<SonoraBackupFavoritesStoring>)SonoraFavoritesStore.sharedStore
                               defaults:NSUserDefaults.standardUserDefaults
                           documentsURL:(documentsURL ?: [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES])];
}

- (instancetype)initWithLibraryManager:(id<SonoraBackupLibraryManaging>)libraryManager
                         playlistStore:(id<SonoraBackupPlaylistStoring>)playlistStore
                        favoritesStore:(id<SonoraBackupFavoritesStoring>)favoritesStore
                              defaults:(NSUserDefaults *)defaults
                          documentsURL:(NSURL *)documentsURL {
    self = [super init];
    if (self) {
        _libraryManager = libraryManager;
        _playlistStore = playlistStore;
        _favoritesStore = favoritesStore;
        _defaults = defaults ?: NSUserDefaults.standardUserDefaults;
        _documentsURL = documentsURL ?: [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
    }
    return self;
}

- (NSString *)backupArchiveFileName {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.dateFormat = @"yyyyMMdd_HHmmss";
    NSString *suffix = [formatter stringFromDate:NSDate.date] ?: @"backup";
    return [NSString stringWithFormat:@"sonora_backup_%@.sonoraarc", suffix];
}

- (nullable NSData *)backupArchiveDataWithSettings:(NSDictionary<NSString *, id> *)settings
                                             error:(NSError **)error {
    NSArray<SonoraTrack *> *tracks = [self.libraryManager tracks];
    if (tracks.count == 0) {
        tracks = [self.libraryManager reloadTracks];
    }
    NSArray<SonoraPlaylist *> *playlists = [self.playlistStore playlists] ?: @[];
    NSSet<NSString *> *favoriteSourceIDs = [NSSet setWithArray:[self.favoritesStore favoriteTrackIDs] ?: @[]];

    NSMutableDictionary<NSString *, NSData *> *entryDataByName = [NSMutableDictionary dictionary];
    NSMutableArray<NSDictionary<NSString *, id> *> *manifestTracks = [NSMutableArray array];
    NSMutableArray<NSDictionary<NSString *, id> *> *manifestPlaylists = [NSMutableArray array];
    NSMutableOrderedSet<NSString *> *favoriteBackupIDs = [NSMutableOrderedSet orderedSet];
    NSMutableDictionary<NSString *, NSString *> *backupIDByTrackID = [NSMutableDictionary dictionary];
    NSMutableSet<NSString *> *usedTrackBackupIDs = [NSMutableSet set];

    NSUInteger trackIndex = 0;
    for (SonoraTrack *track in tracks) {
        NSURL *sourceURL = track.url;
        if (sourceURL == nil) {
            continue;
        }
        NSData *audioData = [NSData dataWithContentsOfURL:sourceURL options:NSDataReadingMappedIfSafe error:nil];
        if (audioData.length == 0) {
            continue;
        }

        NSString *seed = track.identifier.length > 0 ? track.identifier : NSUUID.UUID.UUIDString;
        NSString *hash = SonoraSettingsBackupStableHashString(seed);
        if (hash.length > 8) {
            hash = [hash substringToIndex:8];
        }
        NSString *baseBackupID = [self safeTokenFromString:[NSString stringWithFormat:@"t%04lu_%@", (unsigned long)trackIndex, hash]
                                                   fallback:@"track"];
        NSString *backupID = baseBackupID;
        NSUInteger suffix = 1;
        while ([usedTrackBackupIDs containsObject:backupID]) {
            backupID = [NSString stringWithFormat:@"%@_%lu", baseBackupID, (unsigned long)suffix];
            suffix += 1;
        }
        [usedTrackBackupIDs addObject:backupID];

        NSString *extension = [self safeExtensionFromString:sourceURL.pathExtension fallback:@"bin"];
        NSString *songEntry = [NSString stringWithFormat:@"songs/%@.%@", backupID, extension];
        entryDataByName[songEntry] = audioData;

        if (track.identifier.length > 0) {
            backupIDByTrackID[track.identifier] = backupID;
        }

        BOOL isFavorite = (track.identifier.length > 0 && [favoriteSourceIDs containsObject:track.identifier]);
        if (isFavorite) {
            [favoriteBackupIDs addObject:backupID];
        }

        [manifestTracks addObject:@{
            @"id": backupID,
            @"title": (track.title ?: @""),
            @"artist": (track.artist ?: @""),
            @"durationMs": @((long long)llround(MAX(0.0, track.duration) * 1000.0)),
            @"addedAt": @0,
            @"songEntry": songEntry,
            @"isFavorite": @(isFavorite)
        }];
        trackIndex += 1;
    }

    NSMutableSet<NSString *> *usedPlaylistBackupIDs = [NSMutableSet set];
    NSURL *coversDirectoryURL = [self.documentsURL URLByAppendingPathComponent:@"PlaylistCovers" isDirectory:YES];
    for (SonoraPlaylist *playlist in playlists) {
        NSString *basePlaylistID = [self safeTokenFromString:playlist.playlistID fallback:@"playlist"];
        NSString *backupPlaylistID = basePlaylistID;
        NSUInteger suffix = 1;
        while ([usedPlaylistBackupIDs containsObject:backupPlaylistID]) {
            backupPlaylistID = [NSString stringWithFormat:@"%@_%lu", basePlaylistID, (unsigned long)suffix];
            suffix += 1;
        }
        [usedPlaylistBackupIDs addObject:backupPlaylistID];

        NSMutableOrderedSet<NSString *> *mappedTrackIDs = [NSMutableOrderedSet orderedSet];
        for (NSString *sourceTrackID in playlist.trackIDs ?: @[]) {
            NSString *mapped = backupIDByTrackID[sourceTrackID];
            if (mapped.length > 0) {
                [mappedTrackIDs addObject:mapped];
            }
        }

        NSString *coverEntry = nil;
        if (playlist.customCoverFileName.length > 0) {
            NSURL *coverURL = [coversDirectoryURL URLByAppendingPathComponent:playlist.customCoverFileName];
            NSData *coverData = [NSData dataWithContentsOfURL:coverURL options:NSDataReadingMappedIfSafe error:nil];
            if (coverData.length > 0) {
                NSString *coverExtension = [self safeExtensionFromString:coverURL.pathExtension fallback:@"png"];
                coverEntry = [NSString stringWithFormat:@"playlist_covers/%@.%@", backupPlaylistID, coverExtension];
                entryDataByName[coverEntry] = coverData;
            }
        }

        NSMutableDictionary<NSString *, id> *manifestPlaylist = [@{
            @"id": backupPlaylistID,
            @"name": (playlist.name ?: @"Playlist"),
            @"trackIds": mappedTrackIDs.array ?: @[],
            @"createdAt": @0
        } mutableCopy];
        if (coverEntry.length > 0) {
            manifestPlaylist[@"coverEntry"] = coverEntry;
        }
        [manifestPlaylists addObject:[manifestPlaylist copy]];
    }

    NSDictionary<NSString *, id> *manifest = @{
        @"format": @"sonora-archive",
        @"version": @(SonoraBackupArchiveVersion),
        @"exportedAt": @((long long)llround(NSDate.date.timeIntervalSince1970 * 1000.0)),
        @"tracks": manifestTracks,
        @"playlists": manifestPlaylists,
        @"favorites": favoriteBackupIDs.array ?: @[],
        @"settings": settings ?: @{}
    };
    NSError *jsonError = nil;
    NSData *manifestData = [NSJSONSerialization dataWithJSONObject:manifest options:0 error:&jsonError];
    if (jsonError != nil || manifestData.length == 0) {
        if (error != NULL) {
            *error = [self backupErrorWithCode:200 description:(jsonError.localizedDescription ?: @"Could not encode backup manifest.")];
        }
        return nil;
    }

    NSMutableArray<NSDictionary<NSString *, id> *> *orderedEntries = [NSMutableArray array];
    [orderedEntries addObject:@{
        @"name": SonoraBackupManifestEntryName,
        @"data": manifestData
    }];

    NSArray<NSString *> *sortedNames = [[entryDataByName allKeys] sortedArrayUsingSelector:@selector(compare:)];
    for (NSString *entryName in sortedNames) {
        NSData *entryData = entryDataByName[entryName];
        if (entryData.length == 0) {
            continue;
        }
        [orderedEntries addObject:@{
            @"name": entryName,
            @"data": entryData
        }];
    }

    NSData *magicData = [SonoraBackupArchiveMagicString dataUsingEncoding:NSASCIIStringEncoding];
    if (magicData.length != 8) {
        if (error != NULL) {
            *error = [self backupErrorWithCode:201 description:@"Backup archive magic is invalid."];
        }
        return nil;
    }

    NSMutableData *archiveData = [NSMutableData data];
    [archiveData appendData:magicData];
    [self appendUInt32:(uint32_t)SonoraBackupArchiveVersion toData:archiveData];
    [self appendUInt32:(uint32_t)orderedEntries.count toData:archiveData];

    for (NSDictionary<NSString *, id> *entry in orderedEntries) {
        NSString *entryName = [entry[@"name"] isKindOfClass:NSString.class] ? entry[@"name"] : @"";
        NSData *entryPayload = [entry[@"data"] isKindOfClass:NSData.class] ? entry[@"data"] : nil;
        if (entryName.length == 0 || entryPayload.length == 0) {
            continue;
        }
        NSData *entryNameData = [entryName dataUsingEncoding:NSUTF8StringEncoding];
        [self appendUInt32:(uint32_t)entryNameData.length toData:archiveData];
        [archiveData appendData:entryNameData];
        [self appendUInt64:(uint64_t)entryPayload.length toData:archiveData];
        [archiveData appendData:entryPayload];
    }

    return [archiveData copy];
}

- (BOOL)importBackupArchiveFromURL:(NSURL *)url
                  importedSettings:(NSDictionary<NSString *, id> * _Nullable __autoreleasing * _Nullable)settingsOut
                             error:(NSError **)error {
    NSError *readError = nil;
    NSData *archiveData = [NSData dataWithContentsOfURL:url options:NSDataReadingMappedIfSafe error:&readError];
    if (archiveData.length == 0 || readError != nil) {
        if (error != NULL) {
            *error = [self backupErrorWithCode:300 description:(readError.localizedDescription ?: @"Could not read backup archive.")];
        }
        return NO;
    }

    NSDictionary<NSString *, NSData *> *entries = [self parseArchiveEntriesFromData:archiveData error:error];
    if (entries == nil) {
        return NO;
    }

    NSData *manifestData = entries[SonoraBackupManifestEntryName];
    if (manifestData.length == 0) {
        if (error != NULL) {
            *error = [self backupErrorWithCode:301 description:@"Backup archive has no manifest."];
        }
        return NO;
    }

    NSError *jsonError = nil;
    id manifestObject = [NSJSONSerialization JSONObjectWithData:manifestData options:0 error:&jsonError];
    if (![manifestObject isKindOfClass:NSDictionary.class] || jsonError != nil) {
        if (error != NULL) {
            *error = [self backupErrorWithCode:302 description:(jsonError.localizedDescription ?: @"Backup manifest is invalid.")];
        }
        return NO;
    }
    NSDictionary<NSString *, id> *manifest = (NSDictionary<NSString *, id> *)manifestObject;
    NSArray<NSDictionary<NSString *, id> *> *manifestTracks =
        [manifest[@"tracks"] isKindOfClass:NSArray.class] ? manifest[@"tracks"] : @[];
    NSArray<NSDictionary<NSString *, id> *> *manifestPlaylists =
        [manifest[@"playlists"] isKindOfClass:NSArray.class] ? manifest[@"playlists"] : @[];
    NSArray *manifestFavoritesRaw = [manifest[@"favorites"] isKindOfClass:NSArray.class] ? manifest[@"favorites"] : @[];
    NSDictionary<NSString *, id> *settings =
        [manifest[@"settings"] isKindOfClass:NSDictionary.class] ? manifest[@"settings"] : @{};

    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSURL *musicDirectoryURL = [self.libraryManager musicDirectoryURL];
    NSError *stagingError = nil;
    NSURL *stagingDirectoryURL = [self backupTemporaryDirectoryWithPrefix:@"sonora-import-staging" error:&stagingError];
    if (stagingDirectoryURL == nil) {
        if (error != NULL) {
            *error = stagingError;
        }
        return NO;
    }
    NSURL *previousMusicBackupURL = [stagingDirectoryURL URLByAppendingPathComponent:@"previous-music" isDirectory:YES];
    NSURL *preparedMusicDirectoryURL = [stagingDirectoryURL URLByAppendingPathComponent:@"prepared-music" isDirectory:YES];
    NSError *preparedDirectoryError = nil;
    [fileManager createDirectoryAtURL:preparedMusicDirectoryURL
          withIntermediateDirectories:YES
                           attributes:nil
                                error:&preparedDirectoryError];
    if (preparedDirectoryError != nil) {
        if (error != NULL) {
            *error = [self backupErrorWithCode:303 description:(preparedDirectoryError.localizedDescription ?: @"Could not prepare imported music files.")];
        }
        [self cleanupBackupTemporaryDirectoryAtURL:stagingDirectoryURL];
        return NO;
    }

    NSMutableDictionary<NSString *, NSString *> *backupFileNameByTrackID = [NSMutableDictionary dictionary];
    NSMutableOrderedSet<NSString *> *favoriteBackupIDs = [NSMutableOrderedSet orderedSet];

    for (NSDictionary<NSString *, id> *trackDictionary in manifestTracks) {
        if (![trackDictionary isKindOfClass:NSDictionary.class]) {
            continue;
        }
        NSString *backupID = [trackDictionary[@"id"] isKindOfClass:NSString.class] ? trackDictionary[@"id"] : @"";
        NSString *songEntry = [trackDictionary[@"songEntry"] isKindOfClass:NSString.class] ? trackDictionary[@"songEntry"] : @"";
        if (backupID.length == 0 || songEntry.length == 0) {
            continue;
        }
        NSData *songData = entries[songEntry];
        if (songData.length == 0) {
            if (error != NULL) {
                *error = [self backupErrorWithCode:304 description:@"Backup archive is missing an audio file payload."];
            }
            [self cleanupBackupTemporaryDirectoryAtURL:stagingDirectoryURL];
            return NO;
        }
        NSString *preferredFileName = songEntry.lastPathComponent;
        if (preferredFileName.length == 0) {
            preferredFileName = [NSString stringWithFormat:@"%@.bin", [self safeTokenFromString:backupID fallback:@"track"]];
        }
        NSString *uniqueFileName = [self uniqueFileNameInDirectoryURL:preparedMusicDirectoryURL preferredName:preferredFileName];
        NSURL *targetURL = [preparedMusicDirectoryURL URLByAppendingPathComponent:uniqueFileName];
        NSError *writeError = nil;
        [songData writeToURL:targetURL options:NSDataWritingAtomic error:&writeError];
        if (writeError != nil) {
            if (error != NULL) {
                *error = [self backupErrorWithCode:305 description:(writeError.localizedDescription ?: @"Could not stage audio file from backup archive.")];
            }
            [self cleanupBackupTemporaryDirectoryAtURL:stagingDirectoryURL];
            return NO;
        }
        backupFileNameByTrackID[backupID] = uniqueFileName;

        id favoriteFlag = trackDictionary[@"isFavorite"];
        if ([favoriteFlag respondsToSelector:@selector(boolValue)] && [favoriteFlag boolValue]) {
            [favoriteBackupIDs addObject:backupID];
        }
    }

    for (id value in manifestFavoritesRaw) {
        if ([value isKindOfClass:NSString.class] && ((NSString *)value).length > 0) {
            [favoriteBackupIDs addObject:(NSString *)value];
        }
    }

    BOOL hadExistingMusicDirectory = [fileManager fileExistsAtPath:musicDirectoryURL.path];
    if (hadExistingMusicDirectory) {
        NSError *backupMoveError = nil;
        [fileManager moveItemAtURL:musicDirectoryURL toURL:previousMusicBackupURL error:&backupMoveError];
        if (backupMoveError != nil) {
            if (error != NULL) {
                *error = [self backupErrorWithCode:306 description:(backupMoveError.localizedDescription ?: @"Could not prepare the current library for import.")];
            }
            [self cleanupBackupTemporaryDirectoryAtURL:stagingDirectoryURL];
            return NO;
        }
    }

    NSError *activateImportError = nil;
    [fileManager moveItemAtURL:preparedMusicDirectoryURL toURL:musicDirectoryURL error:&activateImportError];
    if (activateImportError != nil) {
        if (hadExistingMusicDirectory) {
            [self restoreMusicDirectoryAtURL:musicDirectoryURL fromBackupURL:previousMusicBackupURL];
        }
        if (error != NULL) {
            *error = [self backupErrorWithCode:307 description:(activateImportError.localizedDescription ?: @"Could not activate imported music files.")];
        }
        [self cleanupBackupTemporaryDirectoryAtURL:stagingDirectoryURL];
        return NO;
    }

    NSArray<SonoraTrack *> *restoredTracks = [self.libraryManager reloadTracks];
    NSMutableDictionary<NSString *, NSString *> *trackIDByFileName = [NSMutableDictionary dictionary];
    for (SonoraTrack *track in restoredTracks) {
        if (track.fileName.length > 0 && track.identifier.length > 0) {
            trackIDByFileName[track.fileName.lowercaseString] = track.identifier;
        }
    }

    NSMutableDictionary<NSString *, NSString *> *localTrackIDByBackupID = [NSMutableDictionary dictionary];
    [backupFileNameByTrackID enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull backupID, NSString * _Nonnull fileName, __unused BOOL * _Nonnull stop) {
        NSString *localTrackID = trackIDByFileName[fileName.lowercaseString];
        if (localTrackID.length > 0) {
            localTrackIDByBackupID[backupID] = localTrackID;
        }
    }];

    if (backupFileNameByTrackID.count > 0 && localTrackIDByBackupID.count < backupFileNameByTrackID.count) {
        if (hadExistingMusicDirectory) {
            [self restoreMusicDirectoryAtURL:musicDirectoryURL fromBackupURL:previousMusicBackupURL];
        }
        [self.libraryManager reloadTracks];
        if (error != NULL) {
            *error = [self backupErrorWithCode:308 description:@"Imported music files could not be indexed after restore."];
        }
        [self cleanupBackupTemporaryDirectoryAtURL:stagingDirectoryURL];
        return NO;
    }

    for (SonoraPlaylist *playlist in [[self.playlistStore playlists] copy]) {
        [self.playlistStore deletePlaylistWithID:playlist.playlistID];
    }
    for (NSString *favoriteID in [[self.favoritesStore favoriteTrackIDs] copy]) {
        [self.favoritesStore setTrackID:favoriteID favorite:NO];
    }

    for (NSString *backupFavoriteID in favoriteBackupIDs) {
        NSString *localTrackID = localTrackIDByBackupID[backupFavoriteID];
        if (localTrackID.length > 0) {
            [self.favoritesStore setTrackID:localTrackID favorite:YES];
        }
    }

    for (NSDictionary<NSString *, id> *playlistDictionary in manifestPlaylists) {
        if (![playlistDictionary isKindOfClass:NSDictionary.class]) {
            continue;
        }
        NSString *playlistName = [playlistDictionary[@"name"] isKindOfClass:NSString.class] ? playlistDictionary[@"name"] : @"";
        playlistName = [playlistName stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (playlistName.length == 0) {
            continue;
        }

        NSArray *backupTrackIDs = [playlistDictionary[@"trackIds"] isKindOfClass:NSArray.class] ? playlistDictionary[@"trackIds"] : @[];
        NSMutableOrderedSet<NSString *> *localTrackIDs = [NSMutableOrderedSet orderedSet];
        for (id value in backupTrackIDs) {
            if (![value isKindOfClass:NSString.class]) {
                continue;
            }
            NSString *localTrackID = localTrackIDByBackupID[(NSString *)value];
            if (localTrackID.length > 0) {
                [localTrackIDs addObject:localTrackID];
            }
        }
        if (localTrackIDs.count == 0) {
            continue;
        }

        UIImage *coverImage = nil;
        NSString *coverEntry = [playlistDictionary[@"coverEntry"] isKindOfClass:NSString.class] ? playlistDictionary[@"coverEntry"] : @"";
        if (coverEntry.length > 0) {
            NSData *coverData = entries[coverEntry];
            if (coverData.length > 0) {
                coverImage = [UIImage imageWithData:coverData];
            }
        }

        [self.playlistStore addPlaylistWithName:playlistName
                                       trackIDs:localTrackIDs.array
                                     coverImage:coverImage];
    }

    if (settingsOut != NULL) {
        *settingsOut = settings;
    }
    [self cleanupBackupTemporaryDirectoryAtURL:stagingDirectoryURL];
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    (void)coder;
    return [self init];
}

- (NSURL *)backupTemporaryDirectoryWithPrefix:(NSString *)prefix error:(NSError **)error {
    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSString *safePrefix = prefix.length > 0 ? prefix : @"backup-temp";
    NSString *directoryName = [NSString stringWithFormat:@".%@-%@", safePrefix, NSUUID.UUID.UUIDString.lowercaseString];
    NSURL *directoryURL = [self.documentsURL URLByAppendingPathComponent:directoryName isDirectory:YES];
    NSError *directoryError = nil;
    [fileManager createDirectoryAtURL:directoryURL
          withIntermediateDirectories:YES
                           attributes:nil
                                error:&directoryError];
    if (directoryError != nil) {
        if (error != NULL) {
            *error = [self backupErrorWithCode:111 description:(directoryError.localizedDescription ?: @"Could not create a temporary backup directory.")];
        }
        return nil;
    }
    return directoryURL;
}

- (void)cleanupBackupTemporaryDirectoryAtURL:(NSURL *)directoryURL {
    if (directoryURL == nil) {
        return;
    }
    [NSFileManager.defaultManager removeItemAtURL:directoryURL error:nil];
}

- (BOOL)restoreMusicDirectoryAtURL:(NSURL *)musicDirectoryURL fromBackupURL:(NSURL *)backupDirectoryURL {
    if (musicDirectoryURL == nil || backupDirectoryURL == nil) {
        return NO;
    }

    NSFileManager *fileManager = NSFileManager.defaultManager;
    if ([fileManager fileExistsAtPath:musicDirectoryURL.path]) {
        [fileManager removeItemAtURL:musicDirectoryURL error:nil];
    }
    if (![fileManager fileExistsAtPath:backupDirectoryURL.path]) {
        return NO;
    }
    return [fileManager moveItemAtURL:backupDirectoryURL toURL:musicDirectoryURL error:nil];
}

- (NSError *)backupErrorWithCode:(NSInteger)code description:(NSString *)description {
    NSString *resolved = description.length > 0 ? description : @"Backup error.";
    return [NSError errorWithDomain:SonoraBackupArchiveErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: resolved}];
}

- (NSString *)safeTokenFromString:(NSString *)raw fallback:(NSString *)fallback {
    NSString *source = [raw isKindOfClass:NSString.class] ? raw : @"";
    if (source.length == 0) {
        source = fallback.length > 0 ? fallback : @"item";
    }
    NSMutableString *result = [NSMutableString stringWithCapacity:source.length];
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"];
    for (NSUInteger idx = 0; idx < source.length; idx += 1) {
        unichar ch = [source characterAtIndex:idx];
        if ([allowed characterIsMember:ch]) {
            [result appendFormat:@"%C", ch];
        } else {
            [result appendString:@"_"];
        }
    }
    NSString *normalized = result.lowercaseString;
    if (normalized.length == 0) {
        return [NSString stringWithFormat:@"%@_%@", fallback ?: @"item", NSUUID.UUID.UUIDString.lowercaseString];
    }
    return normalized;
}

- (NSString *)safeExtensionFromString:(NSString *)raw fallback:(NSString *)fallback {
    NSString *source = [raw isKindOfClass:NSString.class] ? raw.lowercaseString : @"";
    NSMutableString *result = [NSMutableString stringWithCapacity:source.length];
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz0123456789"];
    for (NSUInteger idx = 0; idx < source.length; idx += 1) {
        unichar ch = [source characterAtIndex:idx];
        if ([allowed characterIsMember:ch]) {
            [result appendFormat:@"%C", ch];
        }
    }
    if (result.length == 0) {
        [result appendString:(fallback.length > 0 ? fallback : @"bin")];
    }
    return [result copy];
}

- (NSString *)uniqueFileNameInDirectoryURL:(NSURL *)directoryURL preferredName:(NSString *)preferredName {
    NSString *baseName = [preferredName.stringByDeletingPathExtension stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *extension = [self safeExtensionFromString:preferredName.pathExtension fallback:@"bin"];
    if (baseName.length == 0) {
        baseName = @"track";
    }
    baseName = [self safeTokenFromString:baseName fallback:@"track"];

    NSString *candidate = [NSString stringWithFormat:@"%@.%@", baseName, extension];
    NSUInteger index = 1;
    while ([NSFileManager.defaultManager fileExistsAtPath:[directoryURL URLByAppendingPathComponent:candidate].path]) {
        candidate = [NSString stringWithFormat:@"%@_%lu.%@", baseName, (unsigned long)index, extension];
        index += 1;
    }
    return candidate;
}

- (void)appendUInt32:(uint32_t)value toData:(NSMutableData *)data {
    uint32_t bigEndian = CFSwapInt32HostToBig(value);
    [data appendBytes:&bigEndian length:sizeof(uint32_t)];
}

- (void)appendUInt64:(uint64_t)value toData:(NSMutableData *)data {
    uint64_t bigEndian = CFSwapInt64HostToBig(value);
    [data appendBytes:&bigEndian length:sizeof(uint64_t)];
}

- (BOOL)readUInt32:(uint32_t *)value fromData:(NSData *)data offset:(NSUInteger *)offset {
    if (value == NULL || data == nil || offset == NULL) {
        return NO;
    }
    if ((*offset + sizeof(uint32_t)) > data.length) {
        return NO;
    }
    uint32_t rawValue = 0;
    [data getBytes:&rawValue range:NSMakeRange(*offset, sizeof(uint32_t))];
    *offset += sizeof(uint32_t);
    *value = CFSwapInt32BigToHost(rawValue);
    return YES;
}

- (BOOL)readUInt64:(uint64_t *)value fromData:(NSData *)data offset:(NSUInteger *)offset {
    if (value == NULL || data == nil || offset == NULL) {
        return NO;
    }
    if ((*offset + sizeof(uint64_t)) > data.length) {
        return NO;
    }
    uint64_t rawValue = 0;
    [data getBytes:&rawValue range:NSMakeRange(*offset, sizeof(uint64_t))];
    *offset += sizeof(uint64_t);
    *value = CFSwapInt64BigToHost(rawValue);
    return YES;
}

- (nullable NSDictionary<NSString *, NSData *> *)parseArchiveEntriesFromData:(NSData *)data error:(NSError **)error {
    NSData *magicData = [SonoraBackupArchiveMagicString dataUsingEncoding:NSASCIIStringEncoding];
    if (magicData.length == 0 || data.length < (magicData.length + sizeof(uint32_t) + sizeof(uint32_t))) {
        if (error != NULL) {
            *error = [self backupErrorWithCode:100 description:@"Invalid backup archive file."];
        }
        return nil;
    }

    NSData *receivedMagic = [data subdataWithRange:NSMakeRange(0, magicData.length)];
    if (![receivedMagic isEqualToData:magicData]) {
        if (error != NULL) {
            *error = [self backupErrorWithCode:101 description:@"Backup archive header mismatch."];
        }
        return nil;
    }

    NSUInteger offset = magicData.length;
    uint32_t version = 0;
    uint32_t entryCount = 0;
    if (![self readUInt32:&version fromData:data offset:&offset] ||
        ![self readUInt32:&entryCount fromData:data offset:&offset]) {
        if (error != NULL) {
            *error = [self backupErrorWithCode:102 description:@"Backup archive is corrupted."];
        }
        return nil;
    }
    if ((NSInteger)version != SonoraBackupArchiveVersion) {
        if (error != NULL) {
            *error = [self backupErrorWithCode:103 description:@"Unsupported backup archive version."];
        }
        return nil;
    }
    if (entryCount == 0) {
        if (error != NULL) {
            *error = [self backupErrorWithCode:104 description:@"Backup archive has no entries."];
        }
        return nil;
    }

    NSMutableDictionary<NSString *, NSData *> *entries = [NSMutableDictionary dictionaryWithCapacity:entryCount];
    for (uint32_t idx = 0; idx < entryCount; idx += 1) {
        uint32_t nameLength = 0;
        if (![self readUInt32:&nameLength fromData:data offset:&offset] || nameLength == 0 || nameLength > 2048) {
            if (error != NULL) {
                *error = [self backupErrorWithCode:105 description:@"Backup entry name is invalid."];
            }
            return nil;
        }
        if ((offset + nameLength) > data.length) {
            if (error != NULL) {
                *error = [self backupErrorWithCode:106 description:@"Backup entry exceeds archive bounds."];
            }
            return nil;
        }
        NSData *nameData = [data subdataWithRange:NSMakeRange(offset, nameLength)];
        offset += nameLength;
        NSString *name = [[NSString alloc] initWithData:nameData encoding:NSUTF8StringEncoding];
        if (name.length == 0) {
            if (error != NULL) {
                *error = [self backupErrorWithCode:107 description:@"Backup entry name cannot be decoded."];
            }
            return nil;
        }

        uint64_t payloadLength = 0;
        if (![self readUInt64:&payloadLength fromData:data offset:&offset]) {
            if (error != NULL) {
                *error = [self backupErrorWithCode:108 description:@"Backup entry payload is corrupted."];
            }
            return nil;
        }
        if (payloadLength > (uint64_t)(data.length - offset)) {
            if (error != NULL) {
                *error = [self backupErrorWithCode:109 description:@"Backup entry payload exceeds archive bounds."];
            }
            return nil;
        }
        NSData *payload = [data subdataWithRange:NSMakeRange(offset, (NSUInteger)payloadLength)];
        offset += (NSUInteger)payloadLength;
        entries[name] = payload;
    }

    return [entries copy];
}

@end
