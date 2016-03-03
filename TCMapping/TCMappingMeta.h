//
//  TCMappingMeta.h
//  TCKit
//
//  Created by dake on 16/3/3.
//  Copyright © 2016年 dake. All rights reserved.
//

#import <Foundation/Foundation.h>


typedef NS_ENUM (NSUInteger, TCMappingClassType) {
    kTCMappingClassTypeUnknown = 0,
    kTCMappingClassTypeNSString,
    kTCMappingClassTypeNSValue,
    kTCMappingClassTypeNSNumber,
    kTCMappingClassTypeNSDate,
    kTCMappingClassTypeNSURL,
    kTCMappingClassTypeNSArray,
    kTCMappingClassTypeNSDictionary,
    
    kTCMappingClassTypeId, // id type
    kTCMappingClassTypeBaseScalar, // int, double, etc...
    
    kTCMappingClassTypeCGPoint,
    kTCMappingClassTypeCGVector,
    kTCMappingClassTypeCGSize,
    kTCMappingClassTypeCGRect,
    kTCMappingClassTypeCGAffineTransform,
    kTCMappingClassTypeUIEdgeInsets,
    kTCMappingClassTypeUIOffset,
};


@interface TCMappingMeta : NSObject
{
@public
    BOOL _isObj;
    NSString *_typeName;
    Class _typeClass;
    TCMappingClassType _classType;
    
    BOOL _ignoreMapping;
    BOOL _ignoreNSCoding;
    BOOL _ignoreCopying;
}

@end


extern NSDictionary<NSString *, TCMappingMeta *> *tc_readwritePropertiesUntilNSObjectFrom(Class klass);
