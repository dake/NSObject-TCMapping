//
//  NSManagedObjectContext+TCMapping.m
//  TCKit
//
//  Created by dake on 16/3/7.
//  Copyright © 2016年 dake. All rights reserved.
//

#import "NSManagedObjectContext+TCMapping.h"

@implementation NSManagedObjectContext (TCMapping)

- (id)instanceForPrimaryKey:(NSDictionary<NSString *, id> *)primaryKey class:(Class)klass
{
    __block NSManagedObject *tempObj = nil;
    [self performBlockAndWait:^{
        if (primaryKey.count > 0) {
            tempObj = [self fetchDataFromDBWithPrimaryKey:primaryKey class:klass];
        }
        
        if (nil == tempObj) {
            tempObj = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass(klass) inManagedObjectContext:self];
        }
    }];
    
    return tempObj;
}


- (NSManagedObject *)fetchDataFromDBWithPrimaryKey:(NSDictionary *)primaryKey class:(Class)klass
{
    NSMutableString *fmt = [NSMutableString string];
    NSArray *allKeys = primaryKey.allKeys;
    NSUInteger count = allKeys.count;
    for (NSInteger i = 0; i < count; ++i) {
        NSString *key = allKeys[i];
        if (i < count - 1) {
            [fmt appendFormat:@"%@==%%@&&", key];
        } else {
            [fmt appendFormat:@"%@==%%@", key];
        }
    }
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:fmt argumentArray:primaryKey.allValues];
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass(klass)];
    fetchRequest.predicate = predicate;
    fetchRequest.fetchLimit = 1;
    //    fetchRequest.returnsObjectsAsFaults
    
    NSError *error = nil;
    NSArray *array = [self executeFetchRequest:fetchRequest error:&error];
    NSAssert(nil == error, @"%@", error.localizedDescription);
    
    return array.lastObject;
}

@end
