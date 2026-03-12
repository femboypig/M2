#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "SonoraServices.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXTERN NSString *SonoraSharedPlaylistSyntheticID(NSString *remoteID);
FOUNDATION_EXTERN NSString *SonoraSharedPlaylistBackendBaseURLString(void);
FOUNDATION_EXTERN NSString *SonoraSharedPlaylistStorageDirectoryPath(void);
FOUNDATION_EXTERN NSString *SonoraSharedPlaylistAudioCacheDirectoryPath(void);
FOUNDATION_EXTERN NSString *SonoraSharedPlaylistNormalizeText(NSString *value);

FOUNDATION_EXTERN NSData * _Nullable SonoraSharedPlaylistDataFromURL(NSURL *url,
                                                                    NSTimeInterval timeout,
                                                                    NSURLResponse * __autoreleasing _Nullable * _Nullable responseOut);
FOUNDATION_EXTERN NSData * _Nullable SonoraSharedPlaylistPerformRequest(NSURLRequest *request,
                                                                       NSTimeInterval timeout,
                                                                       NSHTTPURLResponse * __autoreleasing _Nullable * _Nullable responseOut);
FOUNDATION_EXTERN NSURL * _Nullable SonoraSharedPlaylistDownloadedFileURL(NSString *urlString,
                                                                          NSString *suggestedBaseName);

@interface SonoraSharedPlaylistSnapshot : NSObject

@property (nonatomic, copy) NSString *playlistID;
@property (nonatomic, copy) NSString *remoteID;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *shareURL;
@property (nonatomic, copy) NSString *sourceBaseURL;
@property (nonatomic, copy) NSString *contentSHA256;
@property (nonatomic, copy) NSString *coverURL;
@property (nonatomic, strong, nullable) UIImage *coverImage;
@property (nonatomic, copy) NSArray<SonoraTrack *> *tracks;
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *trackArtworkURLByTrackID;
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *trackRemoteFileURLByTrackID;

@end

FOUNDATION_EXTERN SonoraSharedPlaylistSnapshot * _Nullable SonoraSharedPlaylistSnapshotFromPayload(NSDictionary<NSString *, id> *payload,
                                                                                                   NSString *fallbackBaseURL);
FOUNDATION_EXTERN void SonoraSharedPlaylistPerformWithoutDidChangeNotification(dispatch_block_t block);
FOUNDATION_EXTERN void SonoraSharedPlaylistWarmPersistentCache(SonoraSharedPlaylistSnapshot *snapshot);

@interface SonoraSharedPlaylistStore : NSObject

+ (instancetype)sharedStore;
- (instancetype)initWithUserDefaults:(NSUserDefaults *)userDefaults
                 storageDirectoryURL:(NSURL *)storageDirectoryURL NS_DESIGNATED_INITIALIZER;
- (NSArray<SonoraPlaylist *> *)likedPlaylists;
- (nullable SonoraSharedPlaylistSnapshot *)snapshotForPlaylistID:(NSString *)playlistID;
- (BOOL)isSnapshotLikedForPlaylistID:(NSString *)playlistID;
- (void)saveSnapshot:(SonoraSharedPlaylistSnapshot *)snapshot;
- (void)removeSnapshotForPlaylistID:(NSString *)playlistID;
- (void)refreshAllPersistentCachesIfNeeded;

@end

NS_ASSUME_NONNULL_END
