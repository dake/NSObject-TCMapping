//
//  TCMappingOption.h
//  TCKit
//
//  Created by dake on 16/3/29.
//  Copyright © 2016年 dake. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TCMappingOption : NSObject

#pragma mark - TCMapping

/**
 @brief	format: @{@"propertyName": @"json'propertyName" or NSNull.null for ignore}
 */
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *propertyNameMapping;

/**
 @brief	format: @{@"propertyName": @"object'class name or Class, or yyyy-MM-dd...(-> NSDate)"}
 */
@property (nonatomic, strong) NSDictionary<NSString *, id> *propertyMappingType;

/**
 @brief	format: @{@"primaryKey1": @"value", @"primaryKey2": NSNull.null}
 NSNull.null will be replace with an exact value while mapping.
 */
@property (nonatomic, strong) NSDictionary<NSString *, id> *propertyForPrimaryKey;

@property (nonatomic, assign) BOOL shouldMappingNSNull; // ignore NSNull or not

@property (nonatomic, strong) NSTimeZone *dateTimeZone; // for time string -> NSDate

@property (nonatomic, copy) NSTimeInterval (^timestampToSecondSince1970)(NSTimeInterval timestamp, BOOL *ignoreReturn);


#pragma mark - TCNSCoding

/**
 @brief	format: @{@"propertyName": @"coding key" or NSNull.null for ignore"}
 */
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *propertyNSCodingMapping;


#pragma mark - TCNSCopying

@property (nonatomic, strong) NSArray<NSString *> *propertyCopyIgnore;


#pragma mark - TCJSONMapping

/**
 @brief	format: @{@"propertyName": @"json'propertyName" or NSNull.null for ignore}
 */
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *propertyNameJSONMapping;
@property (nonatomic, assign) BOOL shouldJSONMappingNSNull; // ignore output NSNull or not

@end


