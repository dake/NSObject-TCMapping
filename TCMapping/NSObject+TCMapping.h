//
//  NSObject+TCMapping.h
//  TCKit
//
//  Created by ChenQi on 13-12-29.
//  Copyright (c) 2013年 Dake. All rights reserved.
//

#import <Foundation/Foundation.h>

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
 @brief	format: @{@"propertyName": @"json'propertyName"}
 
 @return the mapping dictionary
 */
+ (NSDictionary<__kindof NSString *, __kindof NSString *> *)propertyNameMapping;

/**
 @brief	format: @{@"propertyName": @"object'class name or Class, or yyyy-MM-dd...(-> NSDate)"}
 
 @return the mapping dictionary
 */
+ (NSDictionary<__kindof NSString *, __kindof NSString *> *)propertyTypeFormat;

/**
 @brief	format: @{@"primaryKey1": @"value", @"primaryKey2": NSNull.null}
 [NSNull null] will be replace with an exact value while mapping.
 
 @return the primary key dictionary
 */
+ (NSDictionary<__kindof NSString *, __kindof NSObject *> *)propertyForPrimaryKey;


+ (NSMutableArray *)mappingWithArray:(NSArray *)arry;
+ (NSMutableArray *)mappingWithArray:(NSArray *)arry managerObjectContext:(NSManagedObjectContext *)context;

+ (instancetype)mappingWithDictionary:(NSDictionary *)dic;
+ (instancetype)mappingWithDictionary:(NSDictionary *)dic managerObjectContext:(NSManagedObjectContext *)context;

+ (NSTimeZone *)tc_dateTimeZone;
+ (NSTimeInterval)tc_timestampToSecondSince1970:(NSTimeInterval)timestamp ignoreReturn:(BOOL *)ignore;

- (void)mappingWithDictionary:(NSDictionary *)dic;
- (void)mappingWithDictionary:(NSDictionary *)dic propertyNameMapping:(NSDictionary *)extraNameMappingDic;

- (BOOL)tc_validate;


#pragma mark - async

+ (void)asyncMappingWithArray:(NSArray *)arry finish:(void(^)(NSMutableArray *dataList))finish;
+ (void)asyncMappingWithDictionary:(NSDictionary *)dic finish:(void(^)(id data))finish;

+ (void)asyncMappingWithArray:(NSArray *)arry inQueue:(dispatch_queue_t)queue finish:(void(^)(NSMutableArray *dataList))finish;
+ (void)asyncMappingWithDictionary:(NSDictionary *)dic inQueue:(dispatch_queue_t)queue finish:(void(^)(id data))finish;

+ (void)asyncMappingWithArray:(NSArray *)arry managerObjectContext:(NSManagedObjectContext *)context inQueue:(dispatch_queue_t)queue finish:(void(^)(NSMutableArray *dataList))finish;
+ (void)asyncMappingWithDictionary:(NSDictionary *)dic managerObjectContext:(NSManagedObjectContext *)context inQueue:(dispatch_queue_t)queue finish:(void(^)(id data))finish;


@end


@interface NSDictionary (TCMapping)

- (id)valueForKeyExceptNull:(NSString *)key;

@end
