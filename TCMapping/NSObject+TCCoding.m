//
//  NSObject+TCCoding.m
//  TCKit
//
//  Created by dake on 16/3/11.
//  Copyright © 2016年 dake. All rights reserved.
//

#import "NSObject+TCCoding.h"
#import <objc/runtime.h>

#import <CoreGraphics/CGGeometry.h>
#import <UIKit/UIGeometry.h>
#import "TCMappingMeta.h"


typedef NS_ENUM(NSInteger, TCPersisentStyle) {
    kTCPersisentStylePlist = 0,
    kTCPersisentStyleJSON,
};


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

static NSObject *codingObject(NSObject *obj, TCPersisentStyle const style, Class klass)
{
    if (nil == obj ||
        obj == (id)kCFNull ||
        [obj isKindOfClass:NSString.class] ||
        [obj isKindOfClass:NSNumber.class]) {
        if (kTCPersisentStylePlist == style && obj == (id)kCFNull) {
            return nil;
        }
        return obj;
    }
    
    if ([obj isKindOfClass:NSDictionary.class]) {
        if (kTCPersisentStyleJSON == style && [NSJSONSerialization isValidJSONObject:obj]) {
            return obj;
        }
        
        NSMutableDictionary *dic = NSMutableDictionary.dictionary;
        for (NSString *key in (NSDictionary *)obj) {
            NSString *strKey = [key isKindOfClass:NSString.class] ? key : key.description;
            if (strKey.length < 1) {
                continue;
            }
            NSObject *value = codingObject(((NSDictionary *)obj)[key], style, klass);
            if (nil != value) {
                dic[strKey] = value;
            }
        }
        return dic;
        
    } else if ([obj isKindOfClass:NSArray.class]) {
        if (kTCPersisentStyleJSON == style && [NSJSONSerialization isValidJSONObject:obj]) {
            return obj;
        }
        
        NSMutableArray *arry = NSMutableArray.array;
        for (id value in (NSArray *)obj) {
            NSObject *jsonValue = codingObject(value, style, klass);
            if (nil != jsonValue) {
                [arry addObject:jsonValue];
            }
        }
        return arry;
        
    } else if ([obj isKindOfClass:NSSet.class]) { // -> array
        return codingObject(((NSSet *)obj).allObjects, style, klass);
        
    } else if ([obj isKindOfClass:NSURL.class]) { // -> string
        return ((NSURL *)obj).absoluteString;
        
    } else if ([obj isKindOfClass:NSDate.class]) { // -> string
        if (kTCPersisentStylePlist == style) {
            return obj;
        }
        return [tcISODateFormatter() stringFromDate:(NSDate *)obj];
        
    } else if ([obj isKindOfClass:NSData.class]) { // -> Base64 string
        if (kTCPersisentStylePlist == style) {
            return obj;
        }
        return [(NSData *)obj base64EncodedStringWithOptions:kNilOptions];
        
    } else if ([obj isKindOfClass:UIColor.class]) { // -> string
        if ([klass respondsToSelector:@selector(tc_transformHexStringFromColor:)]) {
            UIColor *color = (typeof(color))obj;
            return [klass tc_transformHexStringFromColor:color];
        }
        return nil;
        
    } else if ([obj isKindOfClass:UIImage.class]) { // -> data
        if ([klass respondsToSelector:@selector(tc_transformDataFromImage:)]) {
            return codingObject([klass tc_transformDataFromImage:(UIImage *)obj], style, klass);
        }
        return nil;
        
    } else if ([obj isKindOfClass:NSAttributedString.class]) { // -> string
        return ((NSAttributedString *)obj).string;
        
    } else if ([obj isKindOfClass:NSValue.class]) { // -> Base64 string
        return mappingForNSValue((NSValue *)obj);
        
    } else if (class_isMetaClass(object_getClass(obj))) { // -> string
        return NSStringFromClass((Class)obj);
        
    } else { // user defined class
        __unsafe_unretained Class curClass = obj.class;
        TCMappingOption *opt = [curClass respondsToSelector:@selector(tc_mappingOption)] ? [curClass tc_mappingOption] : nil;
        BOOL isNSNullValid = opt.shouldCodingNSNull;
        NSDictionary<NSString *, NSString *> *nameDic = opt.nameCodingMapping;
        __unsafe_unretained NSDictionary<NSString *, TCMappingMeta *> *metaDic = tc_propertiesUntilRootClass(curClass);
        NSMutableDictionary *dic = NSMutableDictionary.dictionary;
        
        for (NSString *key in metaDic) {
            __unsafe_unretained TCMappingMeta *meta = metaDic[key];
            if (NULL == meta->_getter ||
                tc_ignoreCodingForInfo(meta->_info) ||
                nameDic[key] == (id)kCFNull ||
                tc_typeForInfo(meta->_info) == kTCEncodingTypeBlock) {
                continue;
            }
            
            NSObject *value = [obj valueForKey:NSStringFromSelector(meta->_getter) meta:meta ignoreNSNull:!isNSNullValid];
            if (nil == value && isNSNullValid) {
                value = (typeof(value))kCFNull;
            }
            if (nil != value) {
                value = codingObject(value, style, curClass);
            }
            
            if (nil != value) {
                dic[nameDic[key] ?: key] = value;
            }
        }
        
        return dic.count > 0 ? dic : nil;
    }
    
    return nil;
}


@implementation NSObject (TCCoding)

- (id)tc_JSONObject
{
    NSObject *obj = codingObject(self, kTCPersisentStyleJSON, self.class);
    if (nil == obj || [obj isKindOfClass:NSArray.class] || [obj isKindOfClass:NSDictionary.class]) {
        return obj;
    }
    return nil;
}

- (NSData *)tc_JSONData
{
    id obj = self.tc_JSONObject;
    return nil != obj ? [NSJSONSerialization dataWithJSONObject:obj options:kNilOptions error:NULL] : nil;
}

- (NSString *)tc_JSONString
{
    NSData *data = self.tc_JSONData;
    if (nil == data || data.length < 1) {
        return nil;
    }
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}


#pragma mark - TCPlistMapping

- (id)tc_plistObject
{
    NSObject * obj = codingObject(self, kTCPersisentStylePlist, self.class);
    if (nil == obj ||
        [obj isKindOfClass:NSString.class] ||
        [obj isKindOfClass:NSNumber.class] ||
        [obj isKindOfClass:NSArray.class] ||
        [obj isKindOfClass:NSDictionary.class] ||
        [obj isKindOfClass:NSData.class] ||
        [obj isKindOfClass:NSDate.class]) {
        return obj;
    }
    return nil;
}


@end


@implementation NSString (TCJSONMapping)

- (id)tc_JSONObject
{
    return [NSJSONSerialization JSONObjectWithData:[self dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:NULL];
}

@end


@implementation NSData (TCJSONMapping)

- (id)tc_JSONObject
{
    return [NSJSONSerialization JSONObjectWithData:self options:kNilOptions error:NULL];
}

@end
