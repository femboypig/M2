//
//  M2Cells.h
//  M2
//

#import <UIKit/UIKit.h>

#import "M2Models.h"

NS_ASSUME_NONNULL_BEGIN

@interface M2TrackCell : UITableViewCell

- (void)configureWithTrack:(M2Track *)track isCurrent:(BOOL)isCurrent;
- (void)configureWithTrack:(M2Track *)track
                 isCurrent:(BOOL)isCurrent
    showsPlaybackIndicator:(BOOL)showsPlaybackIndicator;

@end

@interface M2PlaylistCell : UITableViewCell

- (void)configureWithName:(NSString *)name
                 subtitle:(NSString *)subtitle
                  artwork:(UIImage *)artwork;

@end

@interface M2TrackGridCell : UICollectionViewCell

- (void)configureWithTrack:(M2Track *)track isCurrent:(BOOL)isCurrent;

@end

@interface M2PlaylistGridCell : UICollectionViewCell

- (void)configureWithName:(NSString *)name
                 subtitle:(NSString *)subtitle
                  artwork:(UIImage *)artwork;

@end

NS_ASSUME_NONNULL_END
