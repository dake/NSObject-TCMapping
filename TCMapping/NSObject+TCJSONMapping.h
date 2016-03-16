//
//  NSObject+TCJSONMapping.h
//  TCKit
//
//  Created by dake on 16/3/11.
//  Copyright © 2016年 dake. All rights reserved.
//

#import <Foundation/Foundation.h>


@protocol TCJSONMappingIgnore;

@interface NSObject (TCJSONMapping)

/**
 @brief	format: @{@"propertyName": @"json'propertyName" or NSNull.null for ignore}
 
 @return the mapping dictionary
 */
+ (NSDictionary<NSString *, NSString *> *)tc_propertyNameJSONMapping;
+ (BOOL)tc_JSONMappingIgnoreNSNull;

- (id/*NSArray or NSDictionary*/)tc_JSONObject;
- (NSData *)tc_JSONData;
- (NSString *)tc_JSONString;

@end


@interface NSString (TCJSONMapping)

- (id)tc_JSONObject;

@end
