//
//  TCMappingMeta.m
//  TCKit
//
//  Created by dake on 16/3/3.
//  Copyright © 2016年 dake. All rights reserved.
//

#import "TCMappingMeta.h"
#import <objc/runtime.h>
#import <CoreGraphics/CGGeometry.h>
#import <UIKit/UIGeometry.h>


@protocol TCMappingIgnore
@end

@protocol NSCodingIgnore
@end

@protocol NSCopyingIgnore
@end



NS_INLINE TCMappingClassType classTypeForStructType(const char *type)
{
    if (strcmp(type, @encode(CGPoint)) == 0) {
        return kTCMappingClassTypeCGPoint;
    } else if (strcmp(type, @encode(CGSize)) == 0) {
        return kTCMappingClassTypeCGSize;
    } else if (strcmp(type, @encode(CGRect)) == 0) {
        return kTCMappingClassTypeCGRect;
    } else if (strcmp(type, @encode(CGVector)) == 0) {
        return kTCMappingClassTypeCGVector;
    } else if (strcmp(type, @encode(UIEdgeInsets)) == 0) {
        return kTCMappingClassTypeUIEdgeInsets;
    } else if (strcmp(type, @encode(CGAffineTransform)) == 0) {
        return kTCMappingClassTypeCGAffineTransform;
    } else if (strcmp(type, @encode(UIOffset)) == 0) {
        return kTCMappingClassTypeUIOffset;
    } else if (strcmp(type, @encode(NSRange)) == 0) {
        return kTCMappingClassTypeNSRange;
    } else if (strcmp(type, @encode(UIRectEdge)) == 0) {
        return kTCMappingClassTypeUIRectEdge;
    }  else {
        return kTCMappingClassTypeStructUnkown;
    }
}

NS_INLINE TCMappingClassType classTypeForScalarType(const char *typeStr)
{
    char type = typeStr[0];
    
    if (type == @encode(BOOL)[0]) {
        return kTCMappingClassTypeBool;
    } else if (type == @encode(int64_t)[0]) {
        return kTCMappingClassTypeInt64;
    } else if (type == @encode(uint64_t)[0]) {
        return kTCMappingClassTypeUInt64;
    } else if (type == @encode(int32_t)[0] || type == @encode(long)[0]) {
        return kTCMappingClassTypeInt32;
    } else if (type == @encode(uint32_t)[0] || type == @encode(unsigned long)[0]) {
        return kTCMappingClassTypeUInt32;
    } else if (type == @encode(float)[0]) {
        return kTCMappingClassTypeFloat;
    } else if (type == @encode(double)[0]) {
        return kTCMappingClassTypeDouble;
    } else if (type == @encode(long double)[0]) {
        return kTCMappingClassTypeLongDouble;
    } else if (type == @encode(Class)[0]) {
        return kTCMappingClassTypeClass;
    } else if (type == @encode(char *)[0] || strcmp(typeStr, @encode(const char *)) == 0) {
        return kTCMappingClassTypeCString;
    } else if (type == @encode(int8_t)[0]) {
        return kTCMappingClassTypeInt8;
    } else if (type == @encode(uint8_t)[0]) {
        return kTCMappingClassTypeUInt8;
    } else if (type == @encode(int16_t)[0]) {
        return kTCMappingClassTypeInt16;
    } else if (type == @encode(uint16_t)[0]) {
        return kTCMappingClassTypeUInt16;
    } else if (type == @encode(SEL)[0]) {
        return kTCMappingClassTypeSEL;
    } else if (type == @encode(void)[0]) {
        return kTCMappingClassTypeVoid;
    } else {
        return kTCMappingClassTypeBaseScalarUnkown;
    }
}

NS_INLINE TCMappingClassType classTypeForNSType(Class typeClass)
{
    if ([typeClass isSubclassOfClass:NSString.class]) {
        return kTCMappingClassTypeNSString;
    } else if ([typeClass isSubclassOfClass:NSNumber.class]) {
        return kTCMappingClassTypeNSNumber;
    } else if ([typeClass isSubclassOfClass:NSDictionary.class]) {
        return kTCMappingClassTypeNSDictionary;
    } else if ([typeClass isSubclassOfClass:NSArray.class]) {
        return kTCMappingClassTypeNSArray;
    } else if ([typeClass isSubclassOfClass:NSURL.class]) {
        return kTCMappingClassTypeNSURL;
    } else if ([typeClass isSubclassOfClass:NSDate.class]) {
        return kTCMappingClassTypeNSDate;
    } else if ([typeClass isSubclassOfClass:NSValue.class]) {
        return kTCMappingClassTypeNSValue;
    } else if ([typeClass isSubclassOfClass:NSSet.class]) {
        return kTCMappingClassTypeNSSet;
    } else if ([typeClass isSubclassOfClass:NSHashTable.class]) {
        return kTCMappingClassTypeNSHashTable;
    } else if ([typeClass isSubclassOfClass:NSData.class]) {
        return kTCMappingClassTypeNSData;
    } else if ([typeClass isSubclassOfClass:NSNull.class]) {
        return kTCMappingClassTypeNSNull;
    }
    
    return kTCMappingClassTypeUnknown;
}

NS_INLINE TCMappingMeta *metaForProperty(objc_property_t property, Class klass)
{
    static NSString *kMappingIgnorePtl;
    static NSString *kNSCodingIgnorePtl;
    static NSString *kNSCopyingIgnorePtl;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        kMappingIgnorePtl = NSStringFromProtocol(@protocol(TCMappingIgnore));
        kNSCodingIgnorePtl = NSStringFromProtocol(@protocol(NSCodingIgnore));
        kNSCopyingIgnorePtl = NSStringFromProtocol(@protocol(NSCopyingIgnore));
    });
    
    
    unsigned int attrCount = 0;
    objc_property_attribute_t *attrs = property_copyAttributeList(property, &attrCount);
    
    BOOL isObj = NO;
    BOOL ignoreMapping = NO;
    BOOL ignoreNSCoding = NO;
    BOOL ignoreCopying = NO;
    SEL getter = NULL;
    SEL setter = NULL;
    NSString *typeName = nil;
    TCMappingClassType classType = kTCMappingClassTypeUnknown;
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
                        classType = kTCMappingClassTypeId;
                    } else if (len == 2 && value[1] == '?') {
                        typeName = @"?";
                        classType = kTCMappingClassTypeBlock;
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
                                    classType = kTCMappingClassTypeId;
                                }
                            }
                        }
                        
                        if (kTCMappingClassTypeId != classType) {
                            typeClass = NSClassFromString(typeName);
                        }
                    }
                } else {
                    isObj = NO;
                    if (len > 0) {
                        typeName = @(value);
                        switch (value[0]) {
                            case '{':
                                classType = classTypeForStructType(value);
                                break;
                                
                            case '(':
                                classType = kTCMappingClassTypeUnion;
                                break;
                                
                            case '[':
                                classType = kTCMappingClassTypeCArray;
                                break;
                                
                            case '^':
                                classType = kTCMappingClassTypeCPointer;
                                break;
                                
                            default:
                                classType = classTypeForScalarType(value);
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
    
    if (isObj && classType != kTCMappingClassTypeId && Nil == typeClass) {
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
    meta->_classType = classType;
    meta->_ignoreCopying = ignoreCopying;
    meta->_ignoreMapping = ignoreMapping;
    meta->_ignoreNSCoding = ignoreNSCoding;
    
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
    
    if (kTCMappingClassTypeUnknown == meta->_classType && Nil != typeClass) {
        meta->_classType = classTypeForNSType(typeClass);
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
    return classTypeForNSType(klass) != kTCMappingClassTypeUnknown;
}

@end
