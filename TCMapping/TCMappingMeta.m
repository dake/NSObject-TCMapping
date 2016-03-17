//
//  TCMappingMeta.m
//  TCKit
//
//  Created by dake on 16/3/3.
//  Copyright © 2016年 dake. All rights reserved.
//

#import "TCMappingMeta.h"
#import <objc/runtime.h>
#import <objc/message.h>

#import <CoreGraphics/CGGeometry.h>
#import <UIKit/UIGeometry.h>


@protocol TCMappingIgnore
@end

@protocol TCJSONMappingIgnore
@end

@protocol NSCodingIgnore
@end

@protocol NSCopyingIgnore
@end



NS_INLINE Class NSBlockClass(void)
{
    static Class cls;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void (^block)(void) = ^{};
        cls = [block class];
        while (class_getSuperclass(cls) != [NSObject class]) {
            cls = class_getSuperclass(cls);
        }
    });
    return cls;
}

NS_INLINE TCEncodingType typeForStructType(const char *type)
{
    if (strcmp(type, @encode(CGPoint)) == 0) {
        return kTCEncodingTypeCGPoint;
    } else if (strcmp(type, @encode(CGSize)) == 0) {
        return kTCEncodingTypeCGSize;
    } else if (strcmp(type, @encode(CGRect)) == 0) {
        return kTCEncodingTypeCGRect;
    } else if (strcmp(type, @encode(UIEdgeInsets)) == 0) {
        return kTCEncodingTypeUIEdgeInsets;
    } else if (strcmp(type, @encode(CGAffineTransform)) == 0) {
        return kTCEncodingTypeCGAffineTransform;
    } else if (strcmp(type, @encode(UIOffset)) == 0) {
        return kTCEncodingTypeUIOffset;
    } else if (strcmp(type, @encode(NSRange)) == 0) {
        return kTCEncodingTypeNSRange;
    } else if (strcmp(type, @encode(CGVector)) == 0) {
        return kTCEncodingTypeCGVector;
    } else if (strcmp(type, @encode(UIRectEdge)) == 0) {
        return kTCEncodingTypeUIRectEdge;
    } else if (NULL != strstr(type, "b")) {
        return kTCEncodingTypeBitStruct;
    } else {
        return kTCEncodingTypeCustomStruct;
    }
}

NS_INLINE TCEncodingType typeForScalarType(const char *typeStr)
{
    char type = typeStr[0];
    
    if (type == @encode(BOOL)[0]) {
        return kTCEncodingTypeBool;
    } else if (type == @encode(int64_t)[0]) {
        return kTCEncodingTypeInt64;
    } else if (type == @encode(uint64_t)[0]) {
        return kTCEncodingTypeUInt64;
    } else if (type == @encode(int32_t)[0] || type == @encode(long)[0]) {
        return kTCEncodingTypeInt32;
    } else if (type == @encode(uint32_t)[0] || type == @encode(unsigned long)[0]) {
        return kTCEncodingTypeUInt32;
    } else if (type == @encode(float)[0]) {
        return kTCEncodingTypeFloat;
    } else if (type == @encode(double)[0]) {
        return kTCEncodingTypeDouble;
    } else if (type == @encode(long double)[0]) {
        return kTCEncodingTypeLongDouble;
    } else if (type == @encode(char *)[0] || strcmp(typeStr, @encode(const char *)) == 0) {
        return kTCEncodingTypeCString;
    } else if (type == @encode(int8_t)[0]) {
        return kTCEncodingTypeInt8;
    } else if (type == @encode(uint8_t)[0]) {
        return kTCEncodingTypeUInt8;
    } else if (type == @encode(int16_t)[0]) {
        return kTCEncodingTypeInt16;
    } else if (type == @encode(uint16_t)[0]) {
        return kTCEncodingTypeUInt16;
    } else if (type == @encode(void)[0]) {
        return kTCEncodingTypeVoid;
    } else {
        return kTCEncodingTypePrimitiveUnkown;
    }
}

NS_INLINE TCEncodingType typeForNSType(Class typeClass)
{
    if ([typeClass isSubclassOfClass:NSString.class]) {
        return kTCEncodingTypeNSString;
    } else if ([typeClass isSubclassOfClass:NSNumber.class]) {
        if ([typeClass isSubclassOfClass:NSDecimalNumber.class]) {
            return kTCEncodingTypeNSDecimalNumber;
        }
        return kTCEncodingTypeNSNumber;
    } else if ([typeClass isSubclassOfClass:NSDictionary.class]) {
        return kTCEncodingTypeNSDictionary;
    } else if ([typeClass isSubclassOfClass:NSArray.class]) {
        return kTCEncodingTypeNSArray;
    } else if ([typeClass isSubclassOfClass:NSURL.class]) {
        return kTCEncodingTypeNSURL;
    } else if ([typeClass isSubclassOfClass:NSDate.class]) {
        return kTCEncodingTypeNSDate;
    } else if ([typeClass isSubclassOfClass:NSValue.class]) {
        return kTCEncodingTypeNSValue;
    } else if ([typeClass isSubclassOfClass:NSSet.class]) {
        return kTCEncodingTypeNSSet;
    } else if ([typeClass isSubclassOfClass:NSHashTable.class]) {
        return kTCEncodingTypeNSHashTable;
    } else if ([typeClass isSubclassOfClass:NSData.class]) {
        return kTCEncodingTypeNSData;
    } else if ([typeClass isSubclassOfClass:NSNull.class]) {
        return kTCEncodingTypeNSNull;
    } else if ([typeClass isSubclassOfClass:NSAttributedString.class]) {
        return kTCEncodingTypeNSAttributedString;
    }
    
    return kTCEncodingTypeUnknown;
}

NS_INLINE TCMappingMeta *metaForProperty(objc_property_t property, Class klass)
{
    static NSString *kMappingIgnorePtl;
    static NSString *kJSONIgnorePtl;
    static NSString *kNSCodingIgnorePtl;
    static NSString *kNSCopyingIgnorePtl;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        kMappingIgnorePtl = NSStringFromProtocol(@protocol(TCMappingIgnore));
        kJSONIgnorePtl = NSStringFromProtocol(@protocol(TCJSONMappingIgnore));
        kNSCodingIgnorePtl = NSStringFromProtocol(@protocol(NSCodingIgnore));
        kNSCopyingIgnorePtl = NSStringFromProtocol(@protocol(NSCopyingIgnore));
    });
    
    
    unsigned int attrCount = 0;
    objc_property_attribute_t *attrs = property_copyAttributeList(property, &attrCount);
    
    BOOL isObj = NO;
    BOOL isStruct = NO;
    BOOL ignoreMapping = NO;
    BOOL ignoreJSON = NO;
    BOOL ignoreNSCoding = NO;
    BOOL ignoreCopying = NO;
    SEL getter = NULL;
    SEL setter = NULL;
    NSString *typeName = nil;
    TCEncodingType encodingType = kTCEncodingTypeUnknown;
    __unsafe_unretained Class typeClass = Nil;
    
    for (unsigned int i = 0; i < attrCount; ++i) {
        switch (attrs[i].name[0]) {
            case 'T': {
                const char *value = attrs[i].value;
                size_t len = NULL != value ? strlen(value) : 0;
                if (len >= 1 && value[0] == @encode(id)[0]) {
                    isObj = YES;
                    
                    if (len == 1) {
                        typeName = @"id";
                        encodingType = kTCEncodingTypeId;
                    } else if (len == 2 && value[1] == '?') {
                        typeClass = NSBlockClass();
                        typeName = NSStringFromClass(typeClass);
                        encodingType = kTCEncodingTypeBlock;
                    } else {
                        char mutableValue[len - 2];
                        strcpy(mutableValue, value + 2);
                        mutableValue[strlen(mutableValue) - 1] = '\0';
                        typeName = @(mutableValue);
                        // "@\"TestModel2<TCMappingIgnore><TCNSCodingIgnore>\"
                        if (value[len - 2] == '>') {
                            NSRange range = [typeName rangeOfString:@"<"];
                            if (range.location != NSNotFound) {
                                
                                NSString *ignoreProtocol = [typeName substringWithRange:NSMakeRange(range.location + 1, typeName.length - range.location - 2)];
                                if ([ignoreProtocol rangeOfString:kMappingIgnorePtl].location != NSNotFound) {
                                    ignoreMapping = YES;
                                }
                                if ([ignoreProtocol rangeOfString:kJSONIgnorePtl].location != NSNotFound) {
                                    ignoreJSON = YES;
                                }
                                if ([ignoreProtocol rangeOfString:kNSCodingIgnorePtl].location != NSNotFound) {
                                    ignoreNSCoding = YES;
                                }
                                if ([ignoreProtocol rangeOfString:kNSCopyingIgnorePtl].location != NSNotFound) {
                                    ignoreCopying = YES;
                                }
                                
                                if (range.location != 0) {
                                    typeName = [typeName substringToIndex:range.location];
                                } else {
                                    typeName = @"id";
                                    encodingType = kTCEncodingTypeId;
                                }
                            }
                        }
                        
                        if (kTCEncodingTypeId != encodingType && kTCEncodingTypeBlock != encodingType) {
                            typeClass = NSClassFromString(typeName);
                        }
                    }
                } else {
                    isObj = NO;
                    if (len > 0) {
                        typeName = @(value);
                        switch (value[0]) {
                            case '#':
                                isObj = YES;
                                typeName = @"Class";
                                encodingType = kTCEncodingTypeClass;
                                break;
                                
                            case '{':
                                isStruct = YES;
                                encodingType = typeForStructType(value);
                                break;
                                
                            case '^':
                                encodingType = kTCEncodingTypeCPointer;
                                break;
                                
                            case ':':
                                typeName = @"SEL";
                                encodingType = kTCEncodingTypeSEL;
                                break;
                                
                            case '[':
                                encodingType = kTCEncodingTypeCArray;
                                break;
                                
                            case '(':
                                encodingType = kTCEncodingTypeUnion;
                                break;
                                
                            default:
                                encodingType = typeForScalarType(value);
                                break;
                        }
                    }
                }
                
                break;
            }
                
            case 'G': {
                if (NULL != attrs[i].value) {
                    getter = NSSelectorFromString(@(attrs[i].value));
                }
                break;
            }
                
            case 'S': {
                if (NULL != attrs[i].value) {
                    setter = NSSelectorFromString(@(attrs[i].value));
                }
                break;
            }
                
            default:
                break;
        }
    }
    
    if (NULL != attrs) {
        free(attrs), attrs = NULL;
    }
    
    if (isObj && !isNoClassObj(encodingType) && Nil == typeClass) {
        return nil;
    }
    
    NSString *propertyName = @(property_getName(property));
    if (nil == propertyName) {
        return nil;
    }
    
    TCMappingMeta *meta = [[TCMappingMeta alloc] init];
    meta->_propertyName = propertyName;
    meta->_typeName = typeName;
    meta->_isObj = isObj;
    meta->_typeClass = typeClass;
    meta->_encodingType = encodingType;
    meta->_isStruct = isStruct;
    meta->_ignoreCopying = ignoreCopying;
    meta->_ignoreMapping = ignoreMapping;
    meta->_ignoreNSCoding = ignoreNSCoding;
    meta->_ignoreJSONMapping = ignoreJSON;
    
    if (NULL == getter) {
        getter = NSSelectorFromString(propertyName);
    }
    if ([klass instancesRespondToSelector:getter]) {
        meta->_getter = getter;
    }
    
    if (NULL == setter) {
        setter = NSSelectorFromString([NSString stringWithFormat:@"set%@%@:", [propertyName substringToIndex:1].uppercaseString, [propertyName substringFromIndex:1]]);
    }
    if ([klass instancesRespondToSelector:setter]) {
        meta->_setter = setter;
    }
    
    if (kTCEncodingTypeUnknown == meta->_encodingType && Nil != typeClass) {
        meta->_encodingType = typeForNSType(typeClass);
    }
    
    return meta;
}


NSDictionary<NSString *, TCMappingMeta *> *tc_propertiesUntilRootClass(Class klass)
{
    if (Nil == klass || Nil == class_getSuperclass(klass)) {
        return nil;
    }
    
    static NSRecursiveLock *s_recursiveLock;
    static NSMutableDictionary<NSString *, NSMutableDictionary *> *s_propertyByClass;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_propertyByClass = [NSMutableDictionary dictionary];
        s_recursiveLock = [[NSRecursiveLock alloc] init];
    });
    
    
    NSString *key = NSStringFromClass(klass);
    
    [s_recursiveLock lock];
    NSMutableDictionary<NSString *, TCMappingMeta *> *propertyNames = s_propertyByClass[key];
    if (nil != propertyNames) {
        [s_recursiveLock unlock];
        return propertyNames;
    }
    
    propertyNames = [NSMutableDictionary dictionary];
    unsigned int num = 0;
    objc_property_t *properties = class_copyPropertyList(klass, &num);
    
    for (unsigned int i = 0; i < num; ++i) {
        TCMappingMeta *meta = metaForProperty(properties[i], klass);
        if (nil != meta) {
            propertyNames[meta->_propertyName] = meta;
        }
    }
    free(properties);
    
    [propertyNames addEntriesFromDictionary:tc_propertiesUntilRootClass(class_getSuperclass(klass))];
    s_propertyByClass[key] = propertyNames;
    
    [s_recursiveLock unlock];
    return propertyNames;
}


@implementation TCMappingMeta

+ (BOOL)isNSTypeForClass:(Class)klass
{
    return typeForNSType(klass) != kTCEncodingTypeUnknown;
}

@end


#pragma mark -

@implementation NSObject (TCMappingMeta)

- (id)valueForKey:(NSString *)key meta:(TCMappingMeta *)meta ignoreNSNull:(BOOL)ignoreNSNull
{
    // valueForKey unsupport: c pointer (include char *, char const *), bit struct, union, SEL
    NSParameterAssert(meta);
    NSParameterAssert(key);
    
    TCEncodingType type = meta->_encodingType;
    
    if (isTypeNeedSerialization(type)) {
        if ([self.class instancesRespondToSelector:@selector(tc_serializedStringForKey:meta:)]) {
            id value = [self tc_serializedStringForKey:key meta:meta];
            if (nil == value && type == kTCEncodingTypeCustomStruct) {
                value = [self valueForKey:key];
            }
            return value;
        } else {
            NSString *msg = [NSString stringWithFormat:@"not response to -[%@], or you can ignore property %@", NSStringFromSelector(@selector(tc_serializedStringForKey:meta:)), key];
            NSLog(@"%@", msg);
            NSAssert(false, msg);
        }
        return nil;
    }
    
    id value = nil;
    if (type == kTCEncodingTypeSEL) {
        SEL selector = ((SEL (*)(id, SEL))(void *) objc_msgSend)(self, meta->_getter);
        value = NULL != selector ? NSStringFromSelector(selector) : (id)kCFNull;
        
    } else if (type == kTCEncodingTypeCString) {
        char const *cstr = ((char const * (*)(id, SEL))(void *) objc_msgSend)(self, meta->_getter);
        value = NULL != cstr ? @(cstr) : (id)kCFNull;
        
    } else {
        value = [self valueForKey:NSStringFromSelector(meta->_getter)];
    }
    
    if (ignoreNSNull) {
        if ((id)kCFNull == value) {
            value = nil;
        }
    } else if (value == nil) {
        value = (id)kCFNull;
    }
    
    return value;
}

- (void)setValue:(nullable id)value forKey:(NSString *)key meta:(TCMappingMeta *)meta
{
    NSParameterAssert(meta);
    NSParameterAssert(key);
    
    TCEncodingType type = meta->_encodingType;
    
    if (type == kTCEncodingTypeCString || isTypeNeedSerialization(type)) {
        
        if ((id)kCFNull == value || [value isKindOfClass:NSString.class]) {
            NSString *str = (id)kCFNull == value ? nil : value;
            
            if ([self.class instancesRespondToSelector:@selector(tc_setSerializedString:forKey:meta:)]) {
                [self tc_setSerializedString:str forKey:key meta:meta];
            } else {
                NSString *msg = [NSString stringWithFormat:@"not response to -[%@], or you can ignore property %@", NSStringFromSelector(@selector(tc_setSerializedString:forKey:meta:)), key];
                NSLog(@"%@", msg);
                NSAssert(false, msg);
            }
            return;
        } else if ([value isKindOfClass:NSValue.class]) {
            [self setValue:value forKey:key];
        }
    } else if (kTCEncodingTypeSEL == type) {
        if ((id)kCFNull == value) {
            ((void (*)(id, SEL, SEL))(void *) objc_msgSend)(self, meta->_setter, NULL);
        } else if ([value isKindOfClass:NSString.class]) {
            SEL sel = NSSelectorFromString((NSString *)value);
            if (NULL != sel) {
                ((void (*)(id, SEL, SEL))(void *) objc_msgSend)(self, meta->_setter, sel);
            }
        } else {
            NSCAssert(false, @"property %@ type %@ doesn't match value type %@", key, meta->_typeName, NSStringFromClass([value class]));
        }
        
    } else if (kTCEncodingTypeClass == type) {
        if (class_isMetaClass(object_getClass(value))) {
            [self setValue:value forKey:key];
        } else if ([value isKindOfClass:NSString.class]) {
            [self setValue:NSClassFromString(value) forKey:key];
        } else if ((id)kCFNull == value) {
            [self setValue:Nil forKey:key];
        } else {
            NSCAssert(false, @"property %@ type %@ doesn't match value type %@", key, meta->_typeName, NSStringFromClass([value class]));
        }
       
    } else if (nil != value || meta->_isObj) {
        [self setValue:(id)kCFNull == value ? nil : value forKey:key];
    }
}

- (void)copy:(id)copy forKey:(NSString *)key meta:(TCMappingMeta *)meta
{
    NSParameterAssert(meta);
    NSParameterAssert(key);
    
    TCEncodingType type = meta->_encodingType;
    
    if (kTCEncodingTypeCPointer == type ||
        kTCEncodingTypeCArray == type ||
        kTCEncodingTypeCString == type ||
        kTCEncodingTypeSEL == type) {
        size_t value = ((size_t (*)(id, SEL))(void *) objc_msgSend)(self, meta->_getter);
        ((void (*)(id, SEL, size_t))(void *) objc_msgSend)(copy, meta->_setter, value);
        
    } else if (meta->_isObj || kTCEncodingTypeCustomStruct == type) {
        [copy setValue:[self valueForKey:key] forKey:key];
    } else {
        [copy setValue:[self valueForKey:key meta:meta ignoreNSNull:NO] forKey:key meta:meta];
    }
}

@end


@implementation NSValue (TCNSValueSerializer)

- (nullable NSString *)unsafeStringValueForCustomStruct
{
    return [self.unsafeDataForCustomStruct base64EncodedStringWithOptions:0];
}

+ (nullable instancetype)valueWitUnsafeStringValue:(NSString *)str customStructType:(const char *)type
{
    NSData *data = [[NSData alloc] initWithBase64EncodedString:str options:0];
    return nil != data ? [self valueWitUnsafeData:data customStructType:type] : nil;
}

- (NSData *)unsafeDataForCustomStruct
{
    // http://stackoverflow.com/questions/18485002/why-cant-i-encode-an-nsvalue-in-an-nskeyedarchiver
    // https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/Archiving/Articles/codingctypes.html#//apple_ref/doc/uid/20001294-BBCBDHBI
    
    NSUInteger size = 0;
    NSUInteger align = 0;
    NSGetSizeAndAlignment(self.objCType, &size, &align);
    
    if (size > 0) {
        void *ptr = malloc(size);
        if (NULL != ptr) {
            [self getValue:ptr];
            return [NSData dataWithBytesNoCopy:ptr length:size];
        }
    }
    
    return nil;
}

+ (instancetype)valueWitUnsafeData:(NSData *)data customStructType:(const char *)type
{
    NSParameterAssert(data);
    NSParameterAssert(type);
    
    if (nil == data || NULL == type) {
        return nil;
    }
    
    NSValue *value = nil;
    if (nil != data) {
        @try {
            value = [self valueWithBytes:data.bytes objCType:type];
        }
        @catch (NSException *exception) {
            value = nil;
        }
        @finally {
            return value;
        }
    }
}

@end
