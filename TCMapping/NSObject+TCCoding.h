//
//  NSObject+TCCoding.h
//  TCKit
//
//  Created by dake on 16/3/11.
//  Copyright © 2016年 dake. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TCMappingOption.h"


@protocol TCCodingIgnore; // unavailable for `Class`


NS_ASSUME_NONNULL_BEGIN

@interface NSObject (TCCoding) <TCMappingOption>

/**
 @brief JSONMapping
 
 UIImage -> base64 string
 UIColor -> "#1234FEA8" ARGB
 NSData -> base64 string
 NSDate -> "yyyy-MM-dd'T'HH:mm:ssZ"
 NSURL -> string
 NSAttributedString -> string
 SEL -> string
 
 */
- (id/*NSArray or NSDictionary*/)tc_JSONObject;
- (NSData *)tc_JSONData;
- (NSString *)tc_JSONString;


#pragma mark - TCPlistMapping

/**
 @brief PlistMapping

 NSPropertyListSerialization, NSCoding: NSData, NSString, NSArray, NSDictionary, NSDate, NSNumber.
 key for NSDictionary must be NSString
 
 UIImage -> data
 UIColor -> "#1234FEA8" ARGB
 NSURL -> string
 NSAttributedString -> string
 SEL -> string
 
 return NSData, NSString, NSArray, NSDictionary, NSDate, NSNumber

 */
- (id)tc_plistObject;

@end


@interface NSString (TCJSONMapping)

- (id)tc_JSONObject;

@end


@interface NSData (TCJSONMapping)

- (id)tc_JSONObject;

@end

NS_ASSUME_NONNULL_END
