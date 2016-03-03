//
//  NSObject+TCNSCoding.h
//  TCKit
//
//  Created by dake on 16/3/2.
//  Copyright © 2016年 dake. All rights reserved.
//

#import <Foundation/Foundation.h>


@protocol NSCodingIgnore <NSObject>
@end


@interface NSObject (TCNSCoding)

/**
 @brief	format: @{@"propertyName": @"coding key" or NSNull.null for ignore"}
 
 */
+ (NSDictionary<NSString *, NSString *> *)tc_propertyNSCodingMapping;
- (void)tc_encodeWithCoder:(NSCoder *)coder;
- (instancetype)tc_initWithCoder:(NSCoder *)coder;


@end
