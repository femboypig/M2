#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXTERN NSString *SonoraSleepTimerRemainingString(NSTimeInterval interval);
FOUNDATION_EXTERN NSTimeInterval SonoraSleepTimerDurationFromInput(NSString *input);
FOUNDATION_EXTERN void SonoraPresentCustomSleepTimerAlert(UIViewController *controller,
                                                          dispatch_block_t _Nullable updateHandler);
FOUNDATION_EXTERN void SonoraPresentSleepTimerActionSheet(UIViewController *controller,
                                                          UIView * _Nullable sourceView,
                                                          dispatch_block_t _Nullable updateHandler);

NS_ASSUME_NONNULL_END
