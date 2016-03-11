//
//  TCMappingMeta.h
//  TCKit
//
//  Created by dake on 16/3/3.
//  Copyright © 2016年 dake. All rights reserved.
//

#import <Foundation/Foundation.h>


typedef NS_ENUM (NSUInteger, TCMappingType) {
    kTCMappingTypeUnknown = 0,
    
    // sys type
    kTCMappingTypeNSString,
    kTCMappingTypeNSValue,
    kTCMappingTypeNSNumber,
    kTCMappingTypeNSDate,
    kTCMappingTypeNSURL,
    kTCMappingTypeNSArray,
    kTCMappingTypeNSDictionary,
    kTCMappingTypeNSSet,
    kTCMappingTypeNSHashTable,
    kTCMappingTypeNSData,
    kTCMappingTypeNSNull,
    kTCMappingTypeNSAttributedString,
    
    // id type
    kTCMappingTypeId,
    kTCMappingTypeBlock,
    kTCMappingTypeClass,
    kTCMappingTypeVoid,
    
    // int, double, etc...
    kTCMappingTypeBool,
    kTCMappingTypeInt64,
    kTCMappingTypeUInt64,
    kTCMappingTypeInt32,
    kTCMappingTypeUInt32,
    kTCMappingTypeInt16,
    kTCMappingTypeUInt16,
    kTCMappingTypeInt8,
    kTCMappingTypeUInt8,
    
    kTCMappingTypeFloat,
    kTCMappingTypeDouble,
    kTCMappingTypeLongDouble,
    
    kTCMappingTypeCPointer,
    kTCMappingTypeCString, // char * or char const *
    kTCMappingTypeCArray,
    kTCMappingTypeUnion,
    kTCMappingTypeSEL,
    
    kTCMappingTypeBaseScalarUnkown,
    
    // struct
    kTCMappingTypeCGPoint,
    kTCMappingTypeCGVector,
    kTCMappingTypeCGSize,
    kTCMappingTypeCGRect,
    kTCMappingTypeCGAffineTransform,
    kTCMappingTypeUIEdgeInsets,
    kTCMappingTypeUIOffset,
    kTCMappingTypeNSRange,
    kTCMappingTypeUIRectEdge,
    
    kTCMappingTypeStructUnkown,
};


@interface TCMappingMeta : NSObject
{
@public
    BOOL _isObj;
    NSString *_typeName;
    NSString *_propertyName;
    Class _typeClass;
    TCMappingType _classType;
    
    SEL _getter;
    SEL _setter;
    BOOL _ignoreMapping;
    BOOL _ignoreJSONMapping;
    BOOL _ignoreNSCoding;
    BOOL _ignoreCopying;
}

+ (BOOL)isNSTypeForClass:(Class)klass;

@end

extern NSDictionary<NSString *, TCMappingMeta *> *tc_propertiesUntilRootClass(Class klass);
