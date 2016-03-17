//
//  NSObject+TCMapping.h
//  TCKit
//
//  Created by dake on 13-12-29.
//  Copyright (c) 2013年 dake. All rights reserved.
//

#import <Foundation/Foundation.h>


@protocol TCMappingPersistentContext <NSObject>

@required
- (id)instanceForPrimaryKey:(NSDictionary<NSString *, id> *)primaryKey class:(Class)klass;

@end


@protocol TCMappingIgnore;

@interface NSObject (TCMapping)


/**
 @brief	property type support CGPoint, CGSize, etc...
 while, the mapping json string format as below:
 
 CGPoint <- "{x,y}"
 CGVector <- "{dx, dy}"
 CGSize <- "{w, h}"
 CGRect <- "{{x,y},{w, h}}"
 CGAffineTransform <- "{a, b, c, d, tx, ty}"
 UIEdgeInsets <- "{top, left, bottom, right}"
 UIOffset <- "{horizontal, vertical}"
 
 */


/**
 @brief	format: @{@"propertyName": @"json'propertyName" or NSNull.null for ignore}
 
 @return the mapping dictionary
 */
+ (NSDictionary<NSString *, NSString *> *)tc_propertyNameMapping;

/**
 @brief	format: @{@"propertyName": @"object'class name or Class, or yyyy-MM-dd...(-> NSDate)"}
 
 @return the mapping dictionary
 */
+ (NSDictionary<NSString *, id> *)tc_propertyTypeFormat;

/**
 @brief	format: @{@"primaryKey1": @"value", @"primaryKey2": NSNull.null}
 NSNull.null will be replace with an exact value while mapping.
 
 @return the primary key dictionary
 */
+ (NSDictionary<NSString *, id> *)tc_propertyForPrimaryKey;

+ (BOOL)tc_mappingIgnoreNSNull;

+ (NSTimeZone *)tc_dateTimeZone;
+ (NSTimeInterval)tc_timestampToSecondSince1970:(NSTimeInterval)timestamp ignoreReturn:(BOOL *)ignore;


+ (NSMutableArray *)tc_mappingWithArray:(NSArray *)arry;
+ (NSMutableArray *)tc_mappingWithArray:(NSArray *)arry context:(id<TCMappingPersistentContext>)context;

+ (instancetype)tc_mappingWithDictionary:(NSDictionary *)dic;
+ (instancetype)tc_mappingWithDictionary:(NSDictionary *)dic context:(id<TCMappingPersistentContext>)context;

- (void)tc_mappingWithDictionary:(NSDictionary *)dic;
- (void)tc_mappingWithDictionary:(NSDictionary *)dic propertyNameMapping:(NSDictionary *)extraNameDic;

- (BOOL)tc_mappingValidate;


#pragma mark - async

+ (void)tc_asyncMappingWithArray:(NSArray *)arry finish:(void(^)(NSMutableArray *dataList))finish;
+ (void)tc_asyncMappingWithDictionary:(NSDictionary *)dic finish:(void(^)(id data))finish;

+ (void)tc_asyncMappingWithArray:(NSArray *)arry inQueue:(dispatch_queue_t)queue finish:(void(^)(NSMutableArray *dataList))finish;
+ (void)tc_asyncMappingWithDictionary:(NSDictionary *)dic inQueue:(dispatch_queue_t)queue finish:(void(^)(id data))finish;

+ (void)tc_asyncMappingWithArray:(NSArray *)arry context:(id<TCMappingPersistentContext>)context inQueue:(dispatch_queue_t)queue finish:(void(^)(NSMutableArray *dataList))finish;
+ (void)tc_asyncMappingWithDictionary:(NSDictionary *)dic context:(id<TCMappingPersistentContext>)context inQueue:(dispatch_queue_t)queue finish:(void(^)(id data))finish;


@end



@interface NSDictionary (TCMapping)

- (id)valueForKeyExceptNull:(NSString *)key;

@end
