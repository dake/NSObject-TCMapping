//
//  TCMappingMeta.h
//  TCKit
//
//  Created by dake on 16/3/3.
//  Copyright © 2016年 dake. All rights reserved.
//

#import <Foundation/Foundation.h>


typedef NS_ENUM(NSUInteger, TCEncodingInfo) {
    kTCEncodingInfoUnknown = 0,
    
    kTCEncodingTypeMask = 0xff,
    kTCEncodingOptionMask = 0xf00,
    kTCEncodingIgnoreMask = 0xf000,
};

typedef NS_ENUM (uint8_t, TCEncodingType) {
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
    kTCEncodingTypeUIColor,
    kTCEncodingTypeUIImage,
    
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
    kTCEncodingTypeCommonStruct,
    
};

// 4 bit, [0, 15] << 8
typedef NS_OPTIONS (uint16_t, TCEncodingOption) {
    kTCEncodingOptionShift = __builtin_ctzll(kTCEncodingOptionMask),
    kTCEncodingOptionObj = 1 << kTCEncodingOptionShift,
    kTCEncodingOptionStruct = 2 << kTCEncodingOptionShift,
};

// 4 bit, [0, 15] << 12
typedef NS_OPTIONS (uint16_t, TCEncodingIgnore) {
    kTCEncodingIgnoreShift = __builtin_ctzll(kTCEncodingIgnoreMask),
    kTCEncodingIgnoreMapping = (1<<0) << kTCEncodingIgnoreShift,
    kTCEncodingIgnoreCoding = (1<<1) << kTCEncodingIgnoreShift,
    kTCEncodingIgnorePersistent = (1<<2) << kTCEncodingIgnoreShift,
    kTCEncodingIgnoreCopying = (1<<3) << kTCEncodingIgnoreShift,
};


NS_INLINE BOOL tc_ignoreMappingForInfo(TCEncodingInfo info)
{
    return ((info & kTCEncodingIgnoreMask) & kTCEncodingIgnoreMapping) == kTCEncodingIgnoreMapping;
}

NS_INLINE BOOL tc_ignoreCodingForInfo(TCEncodingInfo info)
{
    return ((info & kTCEncodingIgnoreMask) & kTCEncodingIgnoreCoding) == kTCEncodingIgnoreCoding;
}

NS_INLINE BOOL tc_ignorePersistentForInfo(TCEncodingInfo info)
{
    return ((info & kTCEncodingIgnoreMask) & kTCEncodingIgnorePersistent) == kTCEncodingIgnorePersistent;
}

NS_INLINE BOOL tc_ignoreCopyingForInfo(TCEncodingInfo info)
{
    return ((info & kTCEncodingIgnoreMask) & kTCEncodingIgnoreCopying) == kTCEncodingIgnoreCopying;
}


NS_INLINE TCEncodingType tc_typeForInfo(TCEncodingInfo info)
{
    return info & kTCEncodingTypeMask;
}

NS_INLINE BOOL tc_isObjForInfo(TCEncodingInfo info)
{
    return (info & kTCEncodingOptionMask) == kTCEncodingOptionObj;
}

NS_INLINE BOOL tc_isStructForInfo(TCEncodingInfo info)
{
    return (info & kTCEncodingOptionMask) == kTCEncodingOptionStruct;
}

NS_INLINE BOOL tc_isTypeNeedSerialization(TCEncodingType type)
{
    return type == kTCEncodingTypeCPointer ||
    type == kTCEncodingTypeCArray ||
    type == kTCEncodingTypeCommonStruct ||
    type == kTCEncodingTypeBitStruct ||
    type == kTCEncodingTypeUnion;
}

NS_INLINE BOOL tc_isNoClassObj(TCEncodingType type)
{
    return type == kTCEncodingTypeId ||
    type == kTCEncodingTypeBlock ||
    type == kTCEncodingTypeClass;
}


NS_ASSUME_NONNULL_BEGIN

@interface TCMappingMeta : NSObject
{
@public
    NSString *_typeName;
    NSString *_propertyName;
    __unsafe_unretained Class _typeClass;
    TCEncodingInfo _info;
    
    SEL _getter;
    SEL _setter;
}

+ (BOOL)isNSTypeForClass:(Class)klass;
+ (TCEncodingType)typeForNSClass:(Class)klass;
+ (instancetype)metaForNSClass:(Class)klass;
+ (BOOL)isBlock:(id)obj;

@end



extern NSDictionary<NSString *, TCMappingMeta *> *tc_propertiesUntilRootClass(Class klass);


@protocol TCNSValueSerializer <NSObject>

@optional

/**
 property callback for: c pointer (exclude char *, char const *), c array, bit field struct, common struct, union
 
 */
- (nullable NSString *)tc_serializedStringForKey:(NSString *)key meta:(TCMappingMeta *)meta;

/**
 property callback for: c pointer (include char *, char const *), c array, bit field struct, common struct, union
 
 */
- (void)tc_setSerializedString:(nullable NSString *)str forKey:(NSString *)key meta:(TCMappingMeta *)meta;

@end



@protocol TCMappingIgnore
@end

@protocol TCCodingIgnore
@end

@protocol TCPersistentIgnore
@end

@protocol NSCopyingIgnore
@end


@interface NSObject (TCMappingMeta) <TCNSValueSerializer>

/**
 @brief	extend KVC for unsupport type

 http://stackoverflow.com/questions/18542664/assigning-to-a-property-of-type-sel-using-kvc
 KVC unsupport: c pointer (include char *, char const *), c array, bit struct, union, SEL
 
 NSValue unsupport: bit field struct,
 */

- (id)valueForKey:(NSString *)key meta:(TCMappingMeta *)meta ignoreNSNull:(BOOL)ignoreNSNull;
- (void)setValue:(nullable id)value forKey:(NSString *)key meta:(TCMappingMeta *)meta forPersistent:(BOOL)persistent;
- (void)copy:(id)copy forKey:(NSString *)key meta:(TCMappingMeta *)meta;

@end


@interface NSValue (TCNSValueSerializer)

- (nullable NSData *)unsafeDataForCustomStruct;
+ (nullable instancetype)valueWitUnsafeData:(NSData *)data customStructType:(const char *)type;

- (nullable NSString *)unsafeStringValueForCustomStruct;
+ (nullable instancetype)valueWitUnsafeStringValue:(NSString *)str customStructType:(const char *)type;

@end

NS_ASSUME_NONNULL_END


