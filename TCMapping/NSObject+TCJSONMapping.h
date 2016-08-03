//
//  NSObject+TCJSONMapping.h
//  TCKit
//
//  Created by dake on 16/3/11.
//  Copyright © 2016年 dake. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TCMappingOption.h"


@protocol TCJSONMappingIgnore; // unavailable for `Class`

/**
 @brief	
 
 UIColor -> "#1234FEA8" ARGB
 NSData -> base64 string
 NSDate -> "yyyy-MM-dd'T'HH:mm:ssZ"
 NSURL -> string
 NSAttributedString -> string
 SEL -> string
 
 */
@interface NSObject (TCJSONMapping)

+ (TCMappingOption *)tc_mappingOption;

- (id/*NSArray or NSDictionary*/)tc_JSONObject;
- (NSData *)tc_JSONData;
- (NSString *)tc_JSONString;

@end


@interface NSString (TCJSONMapping)

- (id)tc_JSONObject;

@end


@interface NSData (TCJSONMapping)

- (id)tc_JSONObject;

@end
