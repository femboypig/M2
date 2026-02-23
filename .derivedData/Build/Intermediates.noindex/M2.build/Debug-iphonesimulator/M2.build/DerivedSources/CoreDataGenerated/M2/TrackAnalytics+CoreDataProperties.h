//
//  TrackAnalytics+CoreDataProperties.h
//  
//
//  Created by loser on 23.02.2026.
//
//  This file was automatically generated and should not be edited.
//

#import "TrackAnalytics+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface TrackAnalytics (CoreDataProperties)

+ (NSFetchRequest<TrackAnalytics *> *)fetchRequest NS_SWIFT_NAME(fetchRequest());

@property (nonatomic) int64_t playCount;
@property (nonatomic) int64_t skipCount;
@property (nullable, nonatomic, copy) NSString *trackID;
@property (nullable, nonatomic, copy) NSDate *updatedAt;

@end

NS_ASSUME_NONNULL_END
