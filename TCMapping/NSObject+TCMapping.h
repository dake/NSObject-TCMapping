//
//  NSObject+TCMapping.h
//  TCKit
//
//  Created by dake on 13-12-29.
//  Copyright (c) 2013年 dake. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TCMappingOption.h"


@protocol TCMappingPersistentContext <NSObject>

@required
- (id)instanceForPrimaryKey:(NSDictionary<NSString *, id> *)primaryKey class:(Class)klass;

@end


@protocol TCMappingIgnore; // unavailable for `Class`

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
 NSRange <- "{location, length}"
 
 UIColor <- {r:0~1, g:0~1, b:0~1, a:0~1}, {rgb:0x123456}, {rgba:0x12345678}, {argb:0x12345678}
 UIColor RGB <- "#0x123456" or "#123456" or "0x123456" or 0x123456
 UIColor ARGB <- "#0x12345678" or "#123456" or "0x12345678" or 0x12345678
 
 */

+ (TCMappingOption *)tc_mappingOption;


+ (NSMutableArray *)tc_mappingWithArray:(NSArray *)arry;
+ (NSMutableArray *)tc_mappingWithArray:(NSArray *)arry context:(id<TCMappingPersistentContext>)context;

+ (instancetype)tc_mappingWithDictionary:(NSDictionary<NSString *, id> *)dic;
+ (instancetype)tc_mappingWithDictionary:(NSDictionary<NSString *, id> *)dic option:(TCMappingOption *)option;
+ (instancetype)tc_mappingWithDictionary:(NSDictionary<NSString *, id> *)dic context:(id<TCMappingPersistentContext>)context;

- (void)tc_mappingWithDictionary:(NSDictionary<NSString *, id> *)dic;
- (void)tc_mappingWithDictionary:(NSDictionary<NSString *, id> *)dic option:(TCMappingOption *)option;


#pragma mark - JSON file

+ (instancetype)tc_mappingWithDictionaryOfJSONFile:(NSString *)path error:(NSError **)error;
+ (NSMutableArray *)tc_mappingWithArrayOfJSONFile:(NSString *)path error:(NSError **)error;


#pragma mark - async

+ (void)tc_asyncMappingWithArray:(NSArray *)arry finish:(void(^)(NSMutableArray *dataList))finish;
+ (void)tc_asyncMappingWithDictionary:(NSDictionary<NSString *, id> *)dic finish:(void(^)(id data))finish;

+ (void)tc_asyncMappingWithArray:(NSArray *)arry inQueue:(dispatch_queue_t)queue finish:(void(^)(NSMutableArray *dataList))finish;
+ (void)tc_asyncMappingWithDictionary:(NSDictionary<NSString *, id> *)dic inQueue:(dispatch_queue_t)queue finish:(void(^)(id data))finish;

+ (void)tc_asyncMappingWithArray:(NSArray *)arry context:(id<TCMappingPersistentContext>)context inQueue:(dispatch_queue_t)queue finish:(void(^)(NSMutableArray *dataList))finish;
+ (void)tc_asyncMappingWithDictionary:(NSDictionary<NSString *, id> *)dic context:(id<TCMappingPersistentContext>)context inQueue:(dispatch_queue_t)queue finish:(void(^)(id data))finish;


@end



@interface NSDictionary (TCMapping)

- (id)valueForKeyExceptNull:(NSString *)key;

@end
