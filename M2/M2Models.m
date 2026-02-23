//
//  M2Models.m
//  M2
//

#import "M2Models.h"
#import <math.h>

@implementation M2Track
@end

@implementation M2Playlist

+ (nullable instancetype)playlistFromDictionary:(NSDictionary<NSString *,id> *)dictionary {
    NSString *playlistID = dictionary[@"id"];
    NSString *name = dictionary[@"name"];
    NSArray<NSString *> *trackIDs = dictionary[@"trackIDs"];

    if (![playlistID isKindOfClass:NSString.class] || playlistID.length == 0) {
        return nil;
    }
    if (![name isKindOfClass:NSString.class] || name.length == 0) {
        return nil;
    }
    if (![trackIDs isKindOfClass:NSArray.class]) {
        return nil;
    }

    NSMutableArray<NSString *> *normalizedIDs = [NSMutableArray arrayWithCapacity:trackIDs.count];
    for (id item in trackIDs) {
        if ([item isKindOfClass:NSString.class] && ((NSString *)item).length > 0) {
            [normalizedIDs addObject:item];
        }
    }

    M2Playlist *playlist = [[M2Playlist alloc] init];
    playlist.playlistID = playlistID;
    playlist.name = name;
    playlist.trackIDs = [normalizedIDs copy];

    id coverValue = dictionary[@"coverFile"];
    if ([coverValue isKindOfClass:NSString.class] && ((NSString *)coverValue).length > 0) {
        playlist.customCoverFileName = coverValue;
    }

    return playlist;
}

- (NSDictionary<NSString *,id> *)dictionaryRepresentation {
    NSMutableDictionary<NSString *, id> *dictionary = [NSMutableDictionary dictionary];
    dictionary[@"id"] = self.playlistID ?: @"";
    dictionary[@"name"] = self.name ?: @"";
    dictionary[@"trackIDs"] = self.trackIDs ?: @[];
    if (self.customCoverFileName.length > 0) {
        dictionary[@"coverFile"] = self.customCoverFileName;
    }
    return [dictionary copy];
}

@end

NSString *M2FormatDuration(NSTimeInterval duration) {
    if (!isfinite(duration) || duration <= 0) {
        return @"0:00";
    }

    NSInteger total = (NSInteger)llround(duration);
    NSInteger minutes = total / 60;
    NSInteger seconds = total % 60;
    return [NSString stringWithFormat:@"%ld:%02ld", (long)minutes, (long)seconds];
}
