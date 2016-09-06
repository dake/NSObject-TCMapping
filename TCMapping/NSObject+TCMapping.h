//
//  NSObject+TCMapping.h
//  TCKit
//
//  Created by dake on 13-12-29.
//  Copyright (c) 2013年 dake. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TCMappingOption.h"


NS_ASSUME_NONNULL_BEGIN

@protocol TCMappingPersistentContext <NSObject>

@required
- (id __nullable)instanceForPrimaryKey:(NSDictionary<NSString *, id> *)primaryKey class:(Class)klass;

@end


@protocol TCMappingIgnore; // unavailable for `Class`


@interface NSObject (TCMapping) <TCMappingOption>


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
 
 SEL <- string
 
 UIColor <- {r:0~1, g:0~1, b:0~1, a:0~1}, {rgb:0x123456}, {rgba:0x12345678}, {argb:0x12345678}
 UIColor RGB <- "#0x123456" or "#123456" or "0x123456" or 0x123456
 UIColor ARGB <- "#0x12345678" or "#123456" or "0x12345678" or 0x12345678
 
 */


+ (NSMutableArray * __nullable)tc_mappingWithArray:(NSArray *)arry;
+ (NSMutableArray * __nullable)tc_mappingWithArray:(NSArray *)arry context:(id<TCMappingPersistentContext> __nullable)context;

+ (instancetype __nullable)tc_mappingWithDictionary:(NSDictionary<NSString *, id> *)dic;
+ (instancetype __nullable)tc_mappingWithDictionary:(NSDictionary<NSString *, id> *)dic option:(TCMappingOption *)option;
+ (instancetype __nullable)tc_mappingWithDictionary:(NSDictionary<NSString *, id> *)dic context:(id<TCMappingPersistentContext>)context;

- (void)tc_mappingWithDictionary:(NSDictionary<NSString *, id> *)dic;
- (void)tc_mappingWithDictionary:(NSDictionary<NSString *, id> *)dic option:(TCMappingOption *)option;

- (void)tc_merge:(__kindof NSObject *)obj map:(id (^)(SEL prop, id left, id right))map;


#pragma mark - JSON file

+ (instancetype __nullable)tc_mappingWithDictionaryOfJSONFile:(NSString *)path error:(NSError ** __nullable)error;
+ (NSMutableArray * __nullable)tc_mappingWithArrayOfJSONFile:(NSString *)path error:(NSError ** __nullable)error;


#pragma mark - async

+ (void)tc_asyncMappingWithArray:(NSArray *)arry finish:(void(^)(NSMutableArray * __nullable dataList))finish;
+ (void)tc_asyncMappingWithDictionary:(NSDictionary<NSString *, id> *)dic finish:(void(^)(__kindof NSObject * __nullable data))finish;

+ (void)tc_asyncMappingWithArray:(NSArray *)arry inQueue:(dispatch_queue_t __nullable)queue finish:(void(^)(NSMutableArray * __nullable dataList))finish;
+ (void)tc_asyncMappingWithDictionary:(NSDictionary<NSString *, id> *)dic inQueue:(dispatch_queue_t)queue finish:(void(^)(__kindof NSObject * __nullable data))finish;

+ (void)tc_asyncMappingWithArray:(NSArray *)arry context:(id<TCMappingPersistentContext> __nullable)context inQueue:(dispatch_queue_t __nullable)queue finish:(void(^)(NSMutableArray *dataList))finish;
+ (void)tc_asyncMappingWithDictionary:(NSDictionary<NSString *, id> *)dic context:(id<TCMappingPersistentContext> __nullable)context inQueue:(dispatch_queue_t __nullable)queue finish:(void(^)(__kindof NSObject * __nullable data))finish;


@end


@interface NSDictionary (TCMapping)

- (id __nullable)valueForKeyExceptNull:(NSString *)key;

@end

NS_ASSUME_NONNULL_END
