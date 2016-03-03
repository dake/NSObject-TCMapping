//
//  NSObject+TCMapping.h
//  TCKit
//
//  Created by dake on 13-12-29.
//  Copyright (c) 2013年 dake. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol TCMappingIgnore
@end

@class NSManagedObjectContext;
@interface NSObject (TCMapping)


/**
 @brief	property type support CGPoint, CGSize, etc...
 while, the mapping json string format as below:
 
 CGPoint <-- "{x,y}"
 CGVector <-- "{dx, dy}"
 CGSize <-- "{w, h}"
 CGRect <-- "{{x,y},{w, h}}"
 CGAffineTransform <-- "{a, b, c, d, tx, ty}"
 UIEdgeInsets <-- "{top, left, bottom, right}"
 UIOffset <-- "{horizontal, vertical}"
 
 */


/**
 @brief	format: @{@"propertyName": @"json'propertyName" or NSNull.null for ignore}
 
 @return the mapping dictionary
 */
+ (NSDictionary<__kindof NSString *, __kindof NSString *> *)tc_propertyNameMapping;

/**
 @brief	format: @{@"propertyName": @"object'class name or Class, or yyyy-MM-dd...(-> NSDate)"}
 
 @return the mapping dictionary
 */
+ (NSDictionary<__kindof NSString *, id> *)tc_propertyTypeFormat;

/**
 @brief	format: @{@"primaryKey1": @"value", @"primaryKey2": NSNull.null}
 [NSNull null] will be replace with an exact value while mapping.
 
 @return the primary key dictionary
 */
+ (NSDictionary<__kindof NSString *, __kindof NSObject *> *)tc_propertyForPrimaryKey;

+ (NSTimeZone *)tc_dateTimeZone;
+ (NSTimeInterval)tc_timestampToSecondSince1970:(NSTimeInterval)timestamp ignoreReturn:(BOOL *)ignore;
+ (BOOL)tc_mappingIgnoreNSNull;


+ (NSMutableArray *)tc_mappingWithArray:(NSArray *)arry;
+ (NSMutableArray *)tc_mappingWithArray:(NSArray *)arry managerObjectContext:(NSManagedObjectContext *)context;

+ (instancetype)tc_mappingWithDictionary:(NSDictionary *)dic;
+ (instancetype)tc_mappingWithDictionary:(NSDictionary *)dic managerObjectContext:(NSManagedObjectContext *)context;

- (void)tc_mappingWithDictionary:(NSDictionary *)dic;
- (void)tc_mappingWithDictionary:(NSDictionary *)dic propertyNameMapping:(NSDictionary *)extraNameMappingDic;

- (BOOL)tc_mappingValidate;


#pragma mark - async

+ (void)tc_asyncMappingWithArray:(NSArray *)arry finish:(void(^)(NSMutableArray *dataList))finish;
+ (void)tc_asyncMappingWithDictionary:(NSDictionary *)dic finish:(void(^)(id data))finish;

+ (void)tc_asyncMappingWithArray:(NSArray *)arry inQueue:(dispatch_queue_t)queue finish:(void(^)(NSMutableArray *dataList))finish;
+ (void)tc_asyncMappingWithDictionary:(NSDictionary *)dic inQueue:(dispatch_queue_t)queue finish:(void(^)(id data))finish;

+ (void)tc_asyncMappingWithArray:(NSArray *)arry managerObjectContext:(NSManagedObjectContext *)context inQueue:(dispatch_queue_t)queue finish:(void(^)(NSMutableArray *dataList))finish;
+ (void)tc_asyncMappingWithDictionary:(NSDictionary *)dic managerObjectContext:(NSManagedObjectContext *)context inQueue:(dispatch_queue_t)queue finish:(void(^)(id data))finish;


@end



@interface NSDictionary (TCMapping)

- (id)valueForKeyExceptNull:(NSString *)key;

@end
