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
    if (nil == coder) {
        return;
    }
    
    NSDictionary *nameMapping = self.class.tc_propertyNSCodingMapping;
    NSDictionary<NSString *, TCMappingMeta *> *metaDic = tc_readwritePropertiesUntilNSObjectFrom(self.class);
    for (NSString *key in metaDic.allKeys) {
        if (metaDic[key]->_ignoreNSCoding) {
            continue;
        }
        NSString *mapKey = nameMapping[key];
        if (nil == mapKey) {
            mapKey = key;
        } else if ((id)kCFNull == mapKey) {
            continue;
        }
        [coder encodeObject:[self valueForKey:key] forKey:mapKey];
    }
}

- (instancetype)tc_initWithCoder:(NSCoder *)coder
{
    NSParameterAssert(coder);
    if (nil == coder) {
        return nil;
    }
    
    typeof(self) obj = self.init;
    if (nil == obj) {
        return nil;
    }
    
    NSDictionary *nameMapping = self.class.tc_propertyNSCodingMapping;
    NSDictionary<NSString *, TCMappingMeta *> *metaDic = tc_readwritePropertiesUntilNSObjectFrom(self.class);
    for (NSString *key in metaDic.allKeys) {
        if (metaDic[key]->_ignoreNSCoding) {
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
    typeof(self) copy = [[self.class alloc] init];
    
    NSArray<NSString *> *ignoreList = self.class.tc_propertyCopyIgnore;
    NSDictionary<NSString *, TCMappingMeta *> *metaDic = tc_readwritePropertiesUntilNSObjectFrom(self.class);
    for (NSString *key in metaDic.allKeys) {
        if (metaDic[key]->_ignoreCopying || [ignoreList containsObject:key]) {
            continue;
        }

        [copy setValue:[self valueForKey:key] forKey:key];
    }
    
    return copy;
}

@end
