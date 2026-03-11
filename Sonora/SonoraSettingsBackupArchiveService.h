#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "SonoraModels.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXTERN NSString * const SonoraBackupArchiveErrorDomain;

@protocol SonoraBackupLibraryManaging <NSObject>

- (NSURL *)musicDirectoryURL;
- (NSArray<SonoraTrack *> *)tracks;
- (NSArray<SonoraTrack *> *)reloadTracks;

@end

@protocol SonoraBackupPlaylistStoring <NSObject>

- (NSArray<SonoraPlaylist *> *)playlists;
- (nullable SonoraPlaylist *)addPlaylistWithName:(NSString *)name
                                        trackIDs:(NSArray<NSString *> *)trackIDs
                                      coverImage:(nullable UIImage *)coverImage;
- (BOOL)deletePlaylistWithID:(NSString *)playlistID;

@end

@protocol SonoraBackupFavoritesStoring <NSObject>

- (NSArray<NSString *> *)favoriteTrackIDs;
- (void)setTrackID:(NSString *)trackID favorite:(BOOL)favorite;

@end

@interface SonoraSettingsBackupArchiveService : NSObject

- (instancetype)init;
- (instancetype)initWithLibraryManager:(id<SonoraBackupLibraryManaging>)libraryManager
                         playlistStore:(id<SonoraBackupPlaylistStoring>)playlistStore
                        favoritesStore:(id<SonoraBackupFavoritesStoring>)favoritesStore
                              defaults:(NSUserDefaults *)defaults
                          documentsURL:(NSURL *)documentsURL NS_DESIGNATED_INITIALIZER;

- (NSString *)backupArchiveFileName;
- (nullable NSData *)backupArchiveDataWithSettings:(NSDictionary<NSString *, id> *)settings
                                             error:(NSError * _Nullable * _Nullable)error;
- (BOOL)importBackupArchiveFromURL:(NSURL *)url
                  importedSettings:(NSDictionary<NSString *, id> * _Nullable __autoreleasing * _Nullable)settingsOut
                             error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
