//
//  NSObject+TCDictionaryMapping.m
//  TCKit
//
//  Created by dake on 16/4/29.
//  Copyright © 2016年 dake. All rights reserved.
//

#import "NSObject+TCDictionaryMapping.h"
#import "TCMappingMeta.h"


@implementation NSObject (TCDictionaryMapping)

+ (TCMappingOption *)tc_mappingOption
{
    return nil;
}

- (id)tc_dictionary
{
    TCEncodingType type = [TCMappingMeta typeForNSClass:self.class];

    if (kTCEncodingTypeNSDictionary == type) {
        NSDictionary<NSString *, NSObject *> *selfDic = (NSDictionary *)self;
        if (selfDic.count < 1) {
            return self;
        }
        
        NSMutableDictionary *dic = NSMutableDictionary.dictionary;
        
        for (NSString *key in selfDic) {
            if ([key isKindOfClass:NSString.class] || [key isKindOfClass:NSNumber.class]) {
                id value = selfDic[key].tc_dictionary;
                if (nil != value) {
                    dic[key] = value;
                }
            }
        }
        return [self.class dictionaryWithDictionary:dic];
        
    } else if (kTCEncodingTypeNSArray == type) {
        if (((NSArray *)self).count < 1) {
            return self;
        }
        
        NSMutableArray *arry = NSMutableArray.array;
        
        for (NSObject *obj in (NSArray *)self) {
            NSDictionary *dic = obj.tc_dictionary;
            if (nil != dic) {
                [arry addObject:dic];
            }
        }
        
        return [self.class arrayWithArray:arry];
        
        
    } else if (kTCEncodingTypeUnknown == type) {
        NSDictionary<NSString *, NSString *> *nameDic = [self.class tc_mappingOption].nameDictionaryMapping;
        __unsafe_unretained NSDictionary<NSString *, TCMappingMeta *> *metaDic = tc_propertiesUntilRootClass(self.class);
        NSMutableDictionary *dic = NSMutableDictionary.dictionary;
        
        for (NSString *key in metaDic) {
            __unsafe_unretained TCMappingMeta *meta = metaDic[key];
            if (NULL == meta->_getter ||
                NULL == meta->_setter ||
                nameDic[key] == (id)kCFNull) {
                continue;
            }
            
            NSObject *value = [self valueForKey:NSStringFromSelector(meta->_getter) meta:meta ignoreNSNull:NO];
            if (nil != value) {
                value = value.tc_dictionary;
            }
            
            if (nil != value) {
                dic[nameDic[key] ?: key] = value;
            }
        }
        
        return dic.count > 0 ? dic : nil;
    }

    return self;
}

@end
