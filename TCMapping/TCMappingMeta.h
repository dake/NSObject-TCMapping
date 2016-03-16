//
//  TCMappingMeta.h
//  TCKit
//
//  Created by dake on 16/3/3.
//  Copyright © 2016年 dake. All rights reserved.
//

#import <Foundation/Foundation.h>


typedef NS_ENUM (NSUInteger, TCEncodingType) {
    kTCEncodingTypeUnknown = 0,
    
    // sys type
    kTCEncodingTypeNSString,
    kTCEncodingTypeNSValue,
    kTCEncodingTypeNSNumber,
    kTCEncodingTypeNSDecimalNumber,
    kTCEncodingTypeNSDate,
    kTCEncodingTypeNSURL,
    kTCEncodingTypeNSArray,
    kTCEncodingTypeNSDictionary,
    kTCEncodingTypeNSSet,
    kTCEncodingTypeNSHashTable,
    kTCEncodingTypeNSData,
    kTCEncodingTypeNSNull,
    kTCEncodingTypeNSAttributedString,
    
    // no class obj type
    kTCEncodingTypeId,
    kTCEncodingTypeBlock,
    kTCEncodingTypeClass,

    // int, double, etc...
    kTCEncodingTypeBool,
    kTCEncodingTypeInt64,
    kTCEncodingTypeUInt64,
    kTCEncodingTypeInt32,
    kTCEncodingTypeUInt32,
    kTCEncodingTypeInt16,
    kTCEncodingTypeUInt16,
    kTCEncodingTypeInt8,
    kTCEncodingTypeUInt8,
    
    kTCEncodingTypeFloat,
    kTCEncodingTypeDouble,
    kTCEncodingTypeLongDouble,
    
    kTCEncodingTypeVoid,
    kTCEncodingTypeCPointer,
    kTCEncodingTypeCString, // char * or char const *, TODO: immutale
    kTCEncodingTypeCArray,
    kTCEncodingTypeUnion,
    kTCEncodingTypeSEL,
    
    kTCEncodingTypePrimitiveUnkown,
    
    // struct
    kTCEncodingTypeCGPoint,
    kTCEncodingTypeCGVector,
    kTCEncodingTypeCGSize,
    kTCEncodingTypeCGRect,
    kTCEncodingTypeCGAffineTransform,
    kTCEncodingTypeUIEdgeInsets,
    kTCEncodingTypeUIOffset,
    kTCEncodingTypeNSRange,
    kTCEncodingTypeUIRectEdge,
    
    kTCEncodingTypeBitStruct, // bit field struct
    kTCEncodingTypeCustomStruct,
};

NS_INLINE BOOL isTypeNeedSerialization(TCEncodingType type)
{
    return type == kTCEncodingTypeCPointer ||
    type == kTCEncodingTypeCArray ||
    type == kTCEncodingTypeCustomStruct ||
    type == kTCEncodingTypeBitStruct ||
    type == kTCEncodingTypeUnion;
}

NS_INLINE BOOL isNoClassObj(TCEncodingType type)
{
    return type == kTCEncodingTypeId ||
    type == kTCEncodingTypeBlock ||
    type == kTCEncodingTypeClass;
}

NS_ASSUME_NONNULL_BEGIN

@interface TCMappingMeta : NSObject
{
@public
    BOOL _isObj;
    NSString *_typeName;
    NSString *_propertyName;
    Class _typeClass;
    TCEncodingType _encodingType;
    
    SEL _getter;
    SEL _setter;
    BOOL _ignoreMapping;
    BOOL _ignoreJSONMapping;
    BOOL _ignoreNSCoding;
    BOOL _ignoreCopying;
    BOOL _isStruct;
}

+ (BOOL)isNSTypeForClass:(Class)klass;

@end

extern NSDictionary<NSString *, TCMappingMeta *> *tc_propertiesUntilRootClass(Class klass);


@protocol TCNSValueSerializer <NSObject>

@optional
- (nullable NSString *)tc_stringValueForKey:(NSString *)key meta:(TCMappingMeta *)meta;
- (void)tc_setStringValue:(nullable NSString *)str forKey:(NSString *)key meta:(TCMappingMeta *)meta;

@end


@interface NSObject (TCMappingMeta) <TCNSValueSerializer>

/**
 @brief	kvc expand

 http://stackoverflow.com/questions/18542664/assigning-to-a-property-of-type-sel-using-kvc
 kvc unsupport: c pointer (include char *, char const *), bit struct, union, SEL
 
 NSValue unsupport: bit struct,
 */

- (id)valueForKey:(NSString *)key meta:(TCMappingMeta *)meta ignoreNSNull:(BOOL)ignoreNSNull;
- (void)setValue:(nullable id)value forKey:(NSString *)key meta:(TCMappingMeta *)meta;
- (void)copy:(id)copy forKey:(NSString *)key meta:(TCMappingMeta *)meta;

@end


@interface NSValue (TCNSValueSerializer)

- (nullable NSData *)unsafeDataForCustomStruct;
+ (nullable instancetype)valueWitUnsafeData:(NSData *)data customStructType:(const char *)type;

- (nullable NSString *)unsafeStringValueForCustomStruct;
+ (nullable instancetype)valueWitUnsafeStringValue:(NSString *)str customStructType:(const char *)type;

@end

NS_ASSUME_NONNULL_END


