//
//  TrackAnalytics+CoreDataProperties.m
//  
//
//  Created by loser on 23.02.2026.
//
//  This file was automatically generated and should not be edited.
//

#import "TrackAnalytics+CoreDataProperties.h"

@implementation TrackAnalytics (CoreDataProperties)

+ (NSFetchRequest<TrackAnalytics *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"TrackAnalytics"];
}

@dynamic playCount;
@dynamic skipCount;
@dynamic trackID;
@dynamic updatedAt;

@end
