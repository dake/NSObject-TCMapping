//
//  NSObject+TCDictionaryMapping.h
//  TCKit
//
//  Created by dake on 16/4/29.
//  Copyright © 2016年 dake. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TCMappingOption.h"


@interface NSObject (TCDictionaryMapping)

+ (TCMappingOption *)tc_mappingOption;

- (id)tc_dictionary;

@end

