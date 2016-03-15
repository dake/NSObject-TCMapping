//
//  NSObject+TCJSONMapping.m
//  TCKit
//
//  Created by dake on 16/3/11.
//  Copyright © 2016年 dake. All rights reserved.
//

#import "NSObject+TCJSONMapping.h"
#import <objc/runtime.h>

#import <CoreGraphics/CGGeometry.h>
#import <UIKit/UIGeometry.h>
#import "TCMappingMeta.h"


/**
 @brief	Get ISO date formatter.
 
 ISO8601 format example:
 2010-07-09T16:13:30+12:00
 2011-01-11T11:11:11+0000
 2011-01-26T19:06:43Z
 
 length: 20/24/25
 */
NS_INLINE NSDateFormatter *tcISODateFormatter(void) {
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZ";
    });
    return formatter;
}

NS_INLINE NSString *mappingForNSValue(NSValue *value)
{
    const char *type = value.objCType;
    if (strcmp(type, @encode(CGPoint)) == 0) {
        return NSStringFromCGPoint(value.CGPointValue);
    } else if (strcmp(type, @encode(CGSize)) == 0) {
        return NSStringFromCGSize(value.CGSizeValue);
    } else if (strcmp(type, @encode(CGRect)) == 0) {
        return NSStringFromCGRect(value.CGRectValue);
    } else if (strcmp(type, @encode(UIEdgeInsets)) == 0) {
        return NSStringFromUIEdgeInsets(value.UIEdgeInsetsValue);
    } else if (strcmp(type, @encode(CGAffineTransform)) == 0) {
        return NSStringFromCGAffineTransform(value.CGAffineTransformValue);
    } else if (strcmp(type, @encode(UIOffset)) == 0) {
        return NSStringFromUIOffset(value.UIOffsetValue);
    } else if (strcmp(type, @encode(NSRange)) == 0) {
        return NSStringFromRange(value.rangeValue);
    } else if (strcmp(type, @encode(CGVector)) == 0) {
        return NSStringFromCGVector(value.CGVectorValue);
    }
    
    return nil;
}

static id mappingToJSONObject(id obj)
{
    if (nil == obj ||
        obj == (id)kCFNull ||
        [obj isKindOfClass:NSString.class] ||
        [obj isKindOfClass:NSNumber.class]) {
        return obj;
    }
    
    if ([obj isKindOfClass:NSDictionary.class]) {
        if ([NSJSONSerialization isValidJSONObject:obj]) {
            return obj;
        }
        
        NSMutableDictionary *dic = [NSMutableDictionary dictionary];
        for (NSString *key in (NSDictionary *)obj) {
            NSString *strKey = [key isKindOfClass:NSString.class] ? key : key.description;
            if (strKey.length < 1) {
                continue;
            }
            id value = mappingToJSONObject((NSDictionary *)obj[key]);
            if (nil != value) {
                dic[strKey] = value;
            }
        }
        return dic;
        
    } else if ([obj isKindOfClass:NSArray.class]) {
        if ([NSJSONSerialization isValidJSONObject:obj]) {
            return obj;
        }
        
        NSMutableArray *arry = [NSMutableArray array];
        for (id value in (NSArray *)obj) {
            id jsonValue = mappingToJSONObject(value);
            if (nil != jsonValue) {
                [arry addObject:jsonValue];
            }
        }
        return arry;
        
    } else if ([obj isKindOfClass:NSSet.class]) { // -> array
        return mappingToJSONObject(((NSSet *)obj).allObjects);
        
    } else if ([obj isKindOfClass:NSURL.class]) { // -> string
        return ((NSURL *)obj).absoluteString;
        
    } else if ([obj isKindOfClass:NSDate.class]) { // -> string
        return [tcISODateFormatter() stringFromDate:obj];
        
    } else if ([obj isKindOfClass:NSData.class]) { // -> Base64 string
        return [(NSData *)obj base64EncodedStringWithOptions:0];
        
    } else if ([obj isKindOfClass:NSAttributedString.class]) { // -> string
        return ((NSAttributedString *)obj).string;
        
    } else if ([obj isKindOfClass:NSValue.class]) { // -> Base64 string
        return mappingForNSValue(obj);
        
    } else if (class_isMetaClass(object_getClass(obj))) { // -> string
        return NSStringFromClass(obj);
        
    } else { // user defined class
        NSDictionary<NSString *, NSString *> *nameDic = [[obj class] tc_propertyNameJSONMapping];
        __unsafe_unretained NSDictionary<NSString *, TCMappingMeta *> *metaDic = tc_propertiesUntilRootClass([obj class]);
        NSMutableDictionary *dic = [NSMutableDictionary dictionary];
        for (NSString *key in metaDic) {
            __unsafe_unretained TCMappingMeta *meta = metaDic[key];
            if (NULL == meta->_getter || meta->_ignoreJSONMapping || nameDic[key] == (id)kCFNull) {
                continue;
            }
            
            id value = [obj valueForKey:NSStringFromSelector(meta->_getter) meta:meta];
            if (nil != value) {
                value = mappingToJSONObject(value);
            }
            
            if (nil != value) {
                dic[nameDic[key] ?: key] = value;
            }
        }
        
        return dic.count > 0 ? dic : nil;
    }
    
    return nil;
}


@implementation NSObject (TCJSONMapping)

- (NSDictionary<NSString *, NSString *> *)tc_propertyNameJSONMapping
{
    return nil;
}

- (id)tc_JSONObject
{
    id obj = mappingToJSONObject(self);
    if (nil == obj || [obj isKindOfClass:NSArray.class] || [obj isKindOfClass:NSDictionary.class]) {
        return obj;
    }
    return nil;
}

- (NSData *)tc_JSONData
{
    id obj = self.tc_JSONObject;
    if (nil == obj) {
        return nil;
    }
    return [NSJSONSerialization dataWithJSONObject:obj options:0 error:NULL];
}

- (NSString *)tc_JSONString
{
    NSData *data = self.tc_JSONData;
    if (nil == data || data.length < 1) {
        return nil;
    }
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

@end
