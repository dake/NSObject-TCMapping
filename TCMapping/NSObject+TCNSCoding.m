//
//  NSObject+TCNSCoding.m
//  TCKit
//
//  Created by dake on 16/3/2.
//  Copyright © 2016年 dake. All rights reserved.
//

#import "NSObject+TCNSCoding.h"
#import <objc/runtime.h>

#import "TCMappingMeta.h"


@implementation NSObject (TCNSCoding)

+ (NSDictionary<NSString *, NSString *> *)tc_propertyNSCodingMapping
{
    return nil;
}

- (void)tc_encodeWithCoder:(NSCoder *)coder
{
    NSParameterAssert(coder);
    NSAssert(![TCMappingMeta isNSTypeForClass:self.class], @"use encodeWithCoder instead!");
    if (nil == coder || [TCMappingMeta isNSTypeForClass:self.class]) {
        return;
    }
    
    NSDictionary *nameMapping = self.class.tc_propertyNSCodingMapping;
    __unsafe_unretained NSDictionary<NSString *, TCMappingMeta *> *metaDic = tc_propertiesUntilRootClass(self.class);
    for (NSString *key in metaDic) {
        __unsafe_unretained TCMappingMeta *meta = metaDic[key];
        TCEncodingType type = meta->_encodingType;
        
        if (meta->_ignoreNSCoding || NULL == meta->_getter || NULL == meta->_setter ||
            type == kTCEncodingTypeBlock) {
            continue;
        }
        
        NSString *mapKey = nameMapping[key];
        if (nil == mapKey) {
            mapKey = key;
        } else if ((id)kCFNull == mapKey) {
            continue;
        }
        
        id value = nil;
        if (type == kTCEncodingTypeClass) {
            value = [self valueForKey:key];
            if (![value isKindOfClass:NSString.class] && class_isMetaClass(object_getClass(value))) {
                value = NSStringFromClass(value);
            }
            
            if (![value isKindOfClass:NSString.class]) {
                continue;
            }
        } else {
            value = [self valueForKey:key meta:meta ignoreNSNull:NO];
        }
        
        if (nil == value) {
            continue;
        }
        
        NSAssert((id)kCFNull == value || [value respondsToSelector:@selector(encodeWithCoder:)], @"+[%@ encodeWithCoder:] unrecognized selector sent to class %@", NSStringFromClass([value class]), [value class]);
        
        [coder encodeObject:value forKey:mapKey];
    }
}

- (instancetype)tc_initWithCoder:(NSCoder *)coder
{
    NSParameterAssert(coder);
    NSAssert(![TCMappingMeta isNSTypeForClass:self.class], @"use encodeWithCoder instead!");
    if (nil == coder || [TCMappingMeta isNSTypeForClass:self.class]) {
        return nil;
    }
    
    typeof(self) obj = self.init;
    if (nil == obj) {
        return nil;
    }
    
    NSDictionary *nameMapping = self.class.tc_propertyNSCodingMapping;
    __unsafe_unretained NSDictionary<NSString *, TCMappingMeta *> *metaDic = tc_propertiesUntilRootClass(self.class);
    for (NSString *key in metaDic) {
        __unsafe_unretained TCMappingMeta *meta = metaDic[key];
        if (meta->_ignoreNSCoding || NULL == meta->_setter) {
            continue;
        }
        NSString *mapKey = nameMapping[key];
        if (nil == mapKey) {
            mapKey = key;
        } else if ((id)kCFNull == mapKey) {
            continue;
        }
        
        [obj setValue:[coder decodeObjectForKey:mapKey] forKey:key meta:meta];
    }
    
    return obj;
}

@end


#pragma mark - TCNSCopying

@implementation NSObject (TCNSCopying)

+ (NSArray<NSString *> *)tc_propertyCopyIgnore
{
    return nil;
}

- (instancetype)tc_copy
{
    NSAssert(![TCMappingMeta isNSTypeForClass:self.class], @"use copy instead of %@!", NSStringFromSelector(_cmd));
    if ([TCMappingMeta isNSTypeForClass:self.class]) {
        return nil;
    }
    
    typeof(self) copy = [[self.class alloc] init];
    
    NSArray<NSString *> *ignoreList = self.class.tc_propertyCopyIgnore;
    __unsafe_unretained NSDictionary<NSString *, TCMappingMeta *> *metaDic = tc_propertiesUntilRootClass(self.class);
    for (NSString *key in metaDic) {
        __unsafe_unretained TCMappingMeta *meta = metaDic[key];
        if (NULL == meta->_getter || NULL == meta->_setter || [ignoreList containsObject:key]) {
            continue;
        }
        
        [self copy:copy forKey:key meta:meta];
    }
    
    return copy;
}

@end


#pragma mark - TCEqual

@implementation NSObject (TCEqual)

- (NSUInteger)tc_hash
{
    NSAssert(![TCMappingMeta isNSTypeForClass:self.class], @"use hash instead of %@!", NSStringFromSelector(_cmd));
    if ([TCMappingMeta isNSTypeForClass:self.class]) {
        return (NSUInteger)((__bridge void *)self);
    }
    
    NSUInteger value = 0;
    __unsafe_unretained NSDictionary<NSString *, TCMappingMeta *> *metaDic = tc_propertiesUntilRootClass(self.class);
    for (NSString *key in metaDic) {
        __unsafe_unretained TCMappingMeta *meta = metaDic[key];
        if (NULL == meta->_getter) {
            continue;
        }
        
        id obj = nil;
        if (meta->_isObj || meta->_encodingType == kTCEncodingTypeCustomStruct) {
            obj = [self valueForKey:key];
        } else {
            obj = [self valueForKey:NSStringFromSelector(meta->_getter) meta:meta ignoreNSNull:YES];
        }
        
        value ^= [obj hash];
    }
    
    if (0 == value) {
        value = (NSUInteger)((__bridge void *)self);
    }
    
    return value;
}

- (BOOL)tc_isEqual:(id)object
{
    NSAssert(![TCMappingMeta isNSTypeForClass:self.class], @"use isEqual: instead of %@!", NSStringFromSelector(_cmd));
    
    if (self == object) {
        return YES;
    }
    
    if (![object isMemberOfClass:self.class] || self.hash != [object hash]) {
        return NO;
    }
    
    __unsafe_unretained NSDictionary<NSString *, TCMappingMeta *> *metaDic = tc_propertiesUntilRootClass(self.class);
    for (NSString *key in metaDic) {
        __unsafe_unretained TCMappingMeta *meta = metaDic[key];
        if (NULL == meta->_getter) {
            continue;
        }
        
        NSString *getter = NSStringFromSelector(meta->_getter);
        id left = [self valueForKey:getter meta:meta ignoreNSNull:YES];
        id right = [object valueForKey:getter meta:meta ignoreNSNull:YES];
        if (left == right) {
            continue;
        } else if (nil == left || nil == right) {
            return NO;
        } else if ([left isEqual:right]) {
            continue;
        }
    }
    
    return YES;
}

@end
