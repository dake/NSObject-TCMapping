//
//  NSObject+TCNSCoding.m
//  TCKit
//
//  Created by dake on 16/3/2.
//  Copyright © 2016年 dake. All rights reserved.
//

#import "NSObject+TCNSCoding.h"
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
    NSDictionary<NSString *, TCMappingMeta *> *metaDic = tc_propertiesUntilRootClass(self.class);
    for (NSString *key in metaDic.allKeys) {
        TCMappingMeta *meta = metaDic[key];
        if (meta->_ignoreNSCoding || NULL == meta->_getter || NULL == meta->_setter) {
            continue;
        }
        
        NSString *mapKey = nameMapping[key];
        if (nil == mapKey) {
            mapKey = key;
        } else if ((id)kCFNull == mapKey) {
            continue;
        }
        NSObject *value = [self valueForKey:key];
        NSAssert(nil == value || [value respondsToSelector:@selector(encodeWithCoder:)], @"+[%@ encodeWithCoder:] unrecognized selector sent to class %@", NSStringFromClass(value.class), value.class);
        if (nil == value || [value respondsToSelector:@selector(encodeWithCoder:)]) {
            [coder encodeObject:value forKey:mapKey];
        }
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
    NSDictionary<NSString *, TCMappingMeta *> *metaDic = tc_propertiesUntilRootClass(self.class);
    for (NSString *key in metaDic.allKeys) {
        TCMappingMeta *meta = metaDic[key];
        if (meta->_ignoreNSCoding || NULL == meta->_setter) {
            continue;
        }
        NSString *mapKey = nameMapping[key];
        if (nil == mapKey) {
            mapKey = key;
        } else if ((id)kCFNull == mapKey) {
            continue;
        }
        [obj setValue:[coder decodeObjectForKey:mapKey] forKey:key];
    }
    
    return obj;
}

@end


@implementation NSObject (TCNSCopying)

+ (NSArray<NSString *> *)tc_propertyCopyIgnore
{
    return nil;
}

- (instancetype)tc_copy
{
    NSAssert(![TCMappingMeta isNSTypeForClass:self.class], @"use copy instead of tc_copy!");
    typeof(self) copy = [[self.class alloc] init];
    
    NSArray<NSString *> *ignoreList = self.class.tc_propertyCopyIgnore;
    NSDictionary<NSString *, TCMappingMeta *> *metaDic = tc_propertiesUntilRootClass(self.class);
    for (NSString *key in metaDic.allKeys) {
        TCMappingMeta *meta = metaDic[key];
        if (NULL == meta->_getter || NULL == meta->_setter || [ignoreList containsObject:key]) {
            continue;
        }

        [copy setValue:[self valueForKey:key] forKey:key];
    }
    
    return copy;
}

@end


@implementation NSObject (TCEqual)

// TODO:
- (NSUInteger)tc_hash
{
    NSAssert(![TCMappingMeta isNSTypeForClass:self.class], @"use hash instead of tc_hash!");
    return 0;
}

- (BOOL)tc_isEqual:(id)object
{
    return NO;
}

@end
