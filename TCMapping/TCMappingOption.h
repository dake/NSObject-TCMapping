//
//  TCMappingOption.h
//  TCKit
//
//  Created by dake on 16/3/29.
//  Copyright © 2016年 dake. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef Class (^TCTypeMappingBlock)(id value);

@interface TCMappingOption : NSObject <NSCopying>

#pragma mark - TCMapping

/**
 @brief	format: @{@"propertyName": @"json'propertyName" or NSNull.null for ignore}
 */
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *nameMapping;

/**
 @brief	format: @{@"propertyName": @"object'class name or Class or `TCTypeMappingBlock`, or yyyy-MM-dd...(-> NSDate)"}
 */
@property (nonatomic, strong) NSDictionary<NSString *, Class> *typeMapping;

/**
 @brief	format: @{@"primaryKey1": @"value", @"primaryKey2": NSNull.null}
 NSNull.null will be replace with an exact value while mapping.
 */
@property (nonatomic, strong) NSDictionary<NSString *, id> *primaryKey;


@property (nonatomic, assign) BOOL shouldMappingNSNull; // mapping NSNull -> nil or not
@property (nonatomic, assign) BOOL emptyDictionaryToNSNull; // mapping {} -> NSNull


@property (nonatomic, copy) void (^setUpDateFormatter)(SEL property, NSDateFormatter *fmter); // for time string -> NSDate
@property (nonatomic, copy) NSTimeInterval (^secondSince1970)(SEL property, NSTimeInterval timestamp, BOOL *ignoreReturn);

@property (nonatomic, copy) BOOL (^mappingValidate)(id obj);

@property (nonatomic, assign) BOOL ignoreTypeConsistency;


+ (instancetype)optionWithNameMapping:(NSDictionary<NSString *, NSString *> *)nameMapping;
+ (instancetype)optionWithTypeMapping:(NSDictionary<NSString *, Class> *)typeMapping;
+ (instancetype)optionWithMappingValidate:(BOOL (^)(id obj))validate;


#pragma mark - TCNSCoding

/**
 @brief	format: @{@"propertyName": @"coding key" or NSNull.null for ignore"}
 */
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *nameNSCodingMapping;


#pragma mark - TCNSCopying

@property (nonatomic, strong) NSArray<NSString *> *nameCopyIgnore;


#pragma mark - TCJSONMapping

/**
 @brief	format: @{@"propertyName": @"json'propertyName" or NSNull.null for ignore}
 */
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *nameJSONMapping;
@property (nonatomic, assign) BOOL shouldJSONMappingNSNull; // ignore output NSNull or not


// TODO: hash, equal  ignore


#pragma mark - TCDictionaryMapping
/**
 @brief	format: @{@"propertyName": @"json'propertyName" or NSNull.null for ignore}
 */
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *nameDictionaryMapping;


@end


