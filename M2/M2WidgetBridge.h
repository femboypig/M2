//
//  M2WidgetBridge.h
//  M2
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface M2WidgetBridge : NSObject

+ (void)refreshSharedLovelyTracks;
+ (BOOL)handleWidgetDeepLinkURL:(NSURL *)url;

@end

NS_ASSUME_NONNULL_END
