//
//  SonoraMusicSearchViews.h
//  Sonora
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXTERN NSString * const SonoraMusicSearchCardCellReuseID;
FOUNDATION_EXTERN NSString * const SonoraMiniStreamingListCellReuseID;
FOUNDATION_EXTERN NSString * const SonoraMusicSearchHeaderReuseID;

@interface SonoraMusicSearchCardCell : UICollectionViewCell

- (void)configureWithTitle:(NSString *)title subtitle:(NSString *)subtitle image:(UIImage * _Nullable)image;

@end

@interface SonoraMiniStreamingListCell : UICollectionViewCell

- (void)configureWithTitle:(NSString *)title
                  subtitle:(NSString *)subtitle
               durationText:(NSString *)durationText
                     image:(UIImage * _Nullable)image
                  isCurrent:(BOOL)isCurrent
     showsPlaybackIndicator:(BOOL)showsPlaybackIndicator
             showsSeparator:(BOOL)showsSeparator;

@end

@interface SonoraMusicSearchHeaderView : UICollectionReusableView

- (void)configureWithTitle:(NSString *)title;

@end

NS_ASSUME_NONNULL_END
