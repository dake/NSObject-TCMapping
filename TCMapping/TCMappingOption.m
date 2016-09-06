//
//  TCMappingOption.m
//  TCKit
//
//  Created by dake on 16/3/29.
//  Copyright © 2016年 dake. All rights reserved.
//

#import "TCMappingOption.h"
#import "NSObject+TCPersistent.h"

@implementation TCMappingOption

- (instancetype)copyWithZone:(NSZone *)zone
{
    return self.tc_copy;
}


+ (instancetype)optionWithNameMapping:(NSDictionary<NSString *, NSString *> *)nameMapping
{
    NSParameterAssert(nameMapping);
    
    TCMappingOption *opt = [[self alloc] init];
    opt.nameMapping = nameMapping;
    
    return opt;
}

+ (instancetype)optionWithTypeMapping:(NSDictionary<NSString *, Class> *)typeMapping
{
    NSParameterAssert(typeMapping);
    
    TCMappingOption *opt = [[self alloc] init];
    opt.typeMapping = typeMapping;
    
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


