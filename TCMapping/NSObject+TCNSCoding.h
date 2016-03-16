//
//  NSObject+TCNSCoding.h
//  TCKit
//
//  Created by dake on 16/3/2.
//  Copyright © 2016年 dake. All rights reserved.
//

#import <Foundation/Foundation.h>


@protocol NSCodingIgnore;

@interface NSObject (TCNSCoding)

/**
 @brief	format: @{@"propertyName": @"coding key" or NSNull.null for ignore"}
 
 */
+ (NSDictionary<NSString *, NSString *> *)tc_propertyNSCodingMapping;

// - (void)encodeWithCoder:(NSCoder *)aCoder { [self tc_encodeWithCoder:aCoder]; }
- (void)tc_encodeWithCoder:(NSCoder *)coder;

// - (instancetype)initWithCoder:(NSCoder *)aDecoder { return [self tc_initWithCoder:aDecoder]; }
- (instancetype)tc_initWithCoder:(NSCoder *)coder;


@end


#pragma mark - TCNSCopying

@protocol NSCopyingIgnore;

@interface NSObject (TCNSCopying)

+ (NSArray<NSString *> *)tc_propertyCopyIgnore;

// - (instancetype)copyWithZone:(NSZone *)zone { return self.tc_copy; }
- (instancetype)tc_copy;

@end


#pragma mark - TCEqual

@interface NSObject (TCEqual)

// - (NSUInteger)hash { return self.tc_hash; }
- (NSUInteger)tc_hash;

// - (BOOL)isEqual:(id)object { return [self tc_isEqual:object]; }
- (BOOL)tc_isEqual:(id)object;

@end