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


@protocol TCMappingIgnore;
@protocol NSCodingIgnore;
@protocol NSCopyingIgnore;


NS_INLINE TCMappingClassType classTypeForStructType(const char *typeNameString)
{
    if (strcmp(typeNameString, @encode(CGPoint)) == 0) {
        return kTCMappingClassTypeCGPoint;
    } else if (strcmp(typeNameString, @encode(CGVector)) == 0) {
        return kTCMappingClassTypeCGVector;
    } else if (strcmp(typeNameString, @encode(CGSize)) == 0) {
        return kTCMappingClassTypeCGSize;
    } else if (strcmp(typeNameString, @encode(CGRect)) == 0) {
        return kTCMappingClassTypeCGRect;
    } else if (strcmp(typeNameString, @encode(CGAffineTransform)) == 0) {
        return kTCMappingClassTypeCGAffineTransform;
    } else if (strcmp(typeNameString, @encode(UIEdgeInsets)) == 0) {
        return kTCMappingClassTypeUIEdgeInsets;
    } else if (strcmp(typeNameString, @encode(UIOffset)) == 0) {
        return kTCMappingClassTypeUIOffset;
    } else {
        return kTCMappingClassTypeBaseScalar;
    }
}


NSDictionary<NSString *, TCMappingMeta *> *tc_readwritePropertiesUntilNSObjectFrom(Class klass)
{
    if (Nil == klass || klass == NSObject.class) {
        return nil;
    }
    
    static NSString *kMappingIgnoreProtocol;
    static NSString *kNSCodingIgnoreProtocol;
    static NSString *kNSCopyingIgnoreProtocol;
    
    static NSRecursiveLock *s_recursiveLock;
    static NSMutableDictionary<NSString *, NSMutableDictionary *> *s_writablePropertyByClass;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        kMappingIgnoreProtocol = NSStringFromProtocol(@protocol(TCMappingIgnore));
        kNSCodingIgnoreProtocol = NSStringFromProtocol(@protocol(NSCodingIgnore));
        kNSCopyingIgnoreProtocol = NSStringFromProtocol(@protocol(NSCopyingIgnore));
        s_writablePropertyByClass = [NSMutableDictionary dictionary];
        s_recursiveLock = [[NSRecursiveLock alloc] init];
    });
    
    NSString *key = NSStringFromClass(klass);
    
    [s_recursiveLock lock];
    NSMutableDictionary<NSString *, TCMappingMeta *> *propertyNames = s_writablePropertyByClass[key];
    if (nil != propertyNames) {
        [s_recursiveLock unlock];
        return propertyNames;
    }
    
    propertyNames = [NSMutableDictionary dictionary];
    unsigned int num = 0;
    objc_property_t *properties = class_copyPropertyList(klass, &num);
    
    for (unsigned int i = 0; i < num; ++i) {
        
        const char *attributes = property_getAttributes(properties[i]);
        char buffer[1 + strlen(attributes)];
        strcpy(buffer, attributes);
        char *state = buffer;
        char *attribute = NULL;
        
        BOOL isObj = NO;
        BOOL ignoreMapping = NO;
        BOOL ignoreNSCoding = NO;
        BOOL ignoreCopying = NO;
        BOOL writable = NULL != attributes;
        NSString *typeName = nil;
        TCMappingClassType classType = kTCMappingClassTypeUnknown;
        __unsafe_unretained Class typeClass = Nil;
        
        NSInteger j = 0;
        while (writable && j++ < 2 && (attribute = strsep(&state, ",")) != NULL) {
            switch (attribute[0]) {
                case 'T': { // type encoding
                    size_t len = strlen(attribute);
                    if (len >= 2 && attribute[0] == 'T' && attribute[1] == '@') { // [@(attribute) hasPrefix:@"T@"]
                        isObj = YES;
                        if (len == 2) {
                            typeName = @"@";
                            classType = kTCMappingClassTypeId;
                        } else {
                            attribute[len - 1] = '\0';
                            typeName = @((attribute + 3));
                            // "T@\"TestModel2<TCMappingIgnore><TCNSCodingIgnore>"
                            if (attribute[len - 2] == '>') {
                                NSRange range = [typeName rangeOfString:@"<"];
                                if (range.location != NSNotFound) {
            
                                    NSString *ignoreProtocol = [typeName substringFromIndex:range.location];
                                    if ([ignoreProtocol rangeOfString:kMappingIgnoreProtocol].location != NSNotFound) {
                                        ignoreMapping = YES;
                                    }
                                    if ([ignoreProtocol rangeOfString:kNSCodingIgnoreProtocol].location != NSNotFound) {
                                        ignoreNSCoding = YES;
                                    }
                                    if ([ignoreProtocol rangeOfString:kNSCopyingIgnoreProtocol].location != NSNotFound) {
                                        ignoreCopying = YES;
                                    }
                                    
                                    if (range.location != 0) {
                                        typeName = [typeName substringToIndex:range.location];
                                    } else {
                                        typeName = @"@";
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
                        if (len > 5 && attribute[1] == '{') { // CGRect. etc contains '{', filer out other scalar type
                            typeName = @((attribute + 1));
                            classType = classTypeForStructType(attribute + 1);
                            
                        } else {
                            classType = kTCMappingClassTypeBaseScalar;
                        }
                    }
                    
                    break;
                }
                    
                case 'R': { // readonly
                    writable = NO;
                    break;
                }
                    
                default:
                    break;
            }
        }
        
        if (!writable || (isObj && classType != kTCMappingClassTypeId && Nil == typeClass)) {
            continue;
        }
        
        NSString *propertyName = [NSString stringWithUTF8String:property_getName(properties[i])];
        // TODO: custom set method
        if (nil != propertyName) {
            
            TCMappingMeta *meta = [[TCMappingMeta alloc] init];
            meta->_typeName = typeName;
            meta->_isObj = isObj;
            meta->_typeClass = typeClass;
            meta->_classType = classType;
            meta->_ignoreCopying = ignoreCopying;
            meta->_ignoreMapping = ignoreMapping;
            meta->_ignoreNSCoding = ignoreNSCoding;
            
            if (Nil != typeClass) {
                if ([typeClass isSubclassOfClass:NSString.class]) {
                    meta->_classType = kTCMappingClassTypeNSString;
                } else if ([typeClass isSubclassOfClass:NSNumber.class]) {
                    meta->_classType = kTCMappingClassTypeNSNumber;
                } else if ([typeClass isSubclassOfClass:NSDictionary.class]) {
                    meta->_classType = kTCMappingClassTypeNSDictionary;
                } else if ([typeClass isSubclassOfClass:NSArray.class]) {
                    meta->_classType = kTCMappingClassTypeNSArray;
                } else if ([typeClass isSubclassOfClass:NSURL.class]) {
                    meta->_classType = kTCMappingClassTypeNSURL;
                } else if ([typeClass isSubclassOfClass:NSDate.class]) {
                    meta->_classType = kTCMappingClassTypeNSDate;
                } else if ([typeClass isSubclassOfClass:NSValue.class]) {
                    meta->_classType = kTCMappingClassTypeNSValue;
                }
            }
            
            propertyNames[propertyName] = meta;
        }
    }
    free(properties);
    
    [propertyNames addEntriesFromDictionary:tc_readwritePropertiesUntilNSObjectFrom(class_getSuperclass(klass))];
    s_writablePropertyByClass[key] = propertyNames;
    
    [s_recursiveLock unlock];
    return propertyNames;
}

@implementation TCMappingMeta

@end
