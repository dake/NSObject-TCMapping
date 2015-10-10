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
 *	propertyNameMapping:
 *  format: @{@"propertyName": @"json'propertyName"}
 
 *	@return	the mapping dictionary
 */
+ (NSDictionary *)propertyNameMapping;

/**
 *	propertyTypeFormat
 *  format: @{@"propertyName": @"object'class name"}
 
 if studentMembers is a NSArray type, you can code the NSArray'member type here , such as  @"studentMembers": @"StudentClass"
 *	@return	the mapping dictionary
 */
+ (NSDictionary *)propertyTypeFormat;

/**
 *	propertyForPrimaryKey:
 *  format: @{@"primaryKey1": @"value", @"primaryKey2": [NSNull null]}
 
 *	@return	the primary key dictionary
 */
+ (NSDictionary *)propertyForPrimaryKey;

+ (NSMutableArray *)mappingWithArray:(NSArray *)arry;
+ (NSMutableArray *)mappingWithArray:(NSArray *)arry managerObjectContext:(NSManagedObjectContext *)context;

+ (instancetype)mappingWithDictionary:(NSDictionary *)dic;
+ (instancetype)mappingWithDictionary:(NSDictionary *)dic managerObjectContext:(NSManagedObjectContext *)context;

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
