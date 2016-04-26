//
//  TCMappingOption.m
//  TCKit
//
//  Created by dake on 16/3/29.
//  Copyright © 2016年 dake. All rights reserved.
//

#import "TCMappingOption.h"

@implementation TCMappingOption


+ (instancetype)optionWithNameMapping:(NSDictionary<NSString *, NSString *> *)nameMapping
{
    NSParameterAssert(nameMapping);
    
    TCMappingOption *opt = [[self alloc] init];
    opt.propertyNameMapping = nameMapping;
    
    return opt;
}

+ (instancetype)optionWithMappingType:(NSDictionary<NSString *, id> *)mappingType
{
    NSParameterAssert(mappingType);
    
    TCMappingOption *opt = [[self alloc] init];
    opt.propertyMappingType = mappingType;
    
    return opt;
}

+ (instancetype)optionWithMappingValidate:(BOOL (^)(id obj))validate
{
    NSParameterAssert(validate);
    
    TCMappingOption *opt = [[self alloc] init];
    opt.mappingValidate = validate;
    
    return opt;
}

@end


