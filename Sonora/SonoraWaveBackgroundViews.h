//
//  SonoraWaveBackgroundViews.h
//  Sonora
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXTERN NSArray<UIColor *> *SonoraResolvedWavePalette(UIImage * _Nullable image);

@interface SonoraWaveAnimatedBackgroundView : UIView

- (void)applyPalette:(NSArray<UIColor *> *)palette animated:(BOOL)animated;
- (void)setPlaying:(BOOL)playing;
- (void)setPulseSeedWithTrackIdentifier:(NSString * _Nullable)identifier;
- (void)ensureAnimationsRunning;

@end

@interface SonoraWaveNebulaBackgroundView : UIView

- (void)applyPalette:(NSArray<UIColor *> *)palette animated:(BOOL)animated;
- (void)setPlaying:(BOOL)playing;
- (void)setPulseSeedWithTrackIdentifier:(NSString * _Nullable)identifier;

@end

NS_ASSUME_NONNULL_END
