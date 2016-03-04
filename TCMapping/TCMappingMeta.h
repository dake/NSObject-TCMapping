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
    
    // sys type
    kTCMappingClassTypeNSString,
    kTCMappingClassTypeNSValue,
    kTCMappingClassTypeNSNumber,
    kTCMappingClassTypeNSDate,
    kTCMappingClassTypeNSURL,
    kTCMappingClassTypeNSArray,
    kTCMappingClassTypeNSDictionary,
    kTCMappingClassTypeNSSet,
    kTCMappingClassTypeNSHashTable,
    kTCMappingClassTypeNSData,
    kTCMappingClassTypeNSNull,
    
    // id type
    kTCMappingClassTypeId,
    kTCMappingClassTypeBlock,
        kTCMappingClassTypeClass,
    
    // int, double, etc...
    kTCMappingClassTypeVoid,

    
    kTCMappingClassTypeCPointer,
    kTCMappingClassTypeCString,
    kTCMappingClassTypeCArray,
    kTCMappingClassTypeUnion,
    kTCMappingClassTypeSEL,
    
    kTCMappingClassTypeBool,
    kTCMappingClassTypeInt64,
    kTCMappingClassTypeUInt64,
    kTCMappingClassTypeInt32,
    kTCMappingClassTypeUInt32,
    kTCMappingClassTypeInt16,
    kTCMappingClassTypeUInt16,
    kTCMappingClassTypeInt8,
    kTCMappingClassTypeUInt8,
    
    
    kTCMappingClassTypeFloat,
    kTCMappingClassTypeDouble,
    kTCMappingClassTypeLongDouble,
    
    
    kTCMappingClassTypeBaseScalarUnkown,
    
    // struct
    kTCMappingClassTypeCGPoint,
    kTCMappingClassTypeCGVector,
    kTCMappingClassTypeCGSize,
    kTCMappingClassTypeCGRect,
    kTCMappingClassTypeCGAffineTransform,
    kTCMappingClassTypeUIEdgeInsets,
    kTCMappingClassTypeUIOffset,
    kTCMappingClassTypeNSRange,
    kTCMappingClassTypeUIRectEdge,
    
    kTCMappingClassTypeStructUnkown,
};


@interface TCMappingMeta : NSObject
{
@public
    BOOL _isObj;
    NSString *_typeName;
    NSString *_propertyName;
    Class _typeClass;
    TCMappingClassType _classType;
    
    SEL _getter;
    SEL _setter;
    BOOL _ignoreMapping;
    BOOL _ignoreNSCoding;
    BOOL _ignoreCopying;
}

+ (BOOL)isNSTypeForClass:(Class)klass;

@end

extern NSDictionary<NSString *, TCMappingMeta *> *tc_propertiesUntilRootClass(Class klass);
