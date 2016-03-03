//
//  NSObject+TCNSCoding.m
//  TCKit
//
//  Created by dake on 16/3/2.
//  Copyright © 2016年 dake. All rights reserved.
//

#import "NSObject+TCNSCoding.h"
#import <objc/runtime.h>


static NSArray<NSString *> *codingPropertyListUntilNSObjectFrom(Class klass)
{
    if (Nil == klass || klass == NSObject.class) {
        return nil;
    }
    
    static NSRecursiveLock *s_recursiveLock;
    static NSMutableDictionary<NSString *, NSMutableArray *> *s_writablePropertyByClass;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_writablePropertyByClass = [NSMutableDictionary dictionary];
        s_recursiveLock = [[NSRecursiveLock alloc] init];
    });
    
    NSString *key = NSStringFromClass(klass);
    
    [s_recursiveLock lock];
    NSArray *propertyNames = s_writablePropertyByClass[key];
    if (nil != propertyNames) {
        [s_recursiveLock unlock];
        return propertyNames;
    }

    
    NSMutableArray *arry = [NSMutableArray array];
    NSDictionary *nameMapping = [klass tc_propertyNSCodingMapping];
    unsigned int num = 0;
    objc_property_t *properties = class_copyPropertyList(klass, &num);
    for (unsigned int i = 0; i < num; ++i) {
        
        const char *attributes = property_getAttributes(properties[i]);
        char buffer[1 + strlen(attributes)];
        strcpy(buffer, attributes);
        char *state = buffer;
        char *attribute = NULL;
        
        BOOL ignore = NULL == attributes;
        NSInteger j = 0;
        while (!ignore && j++ < 2 && (attribute = strsep(&state, ",")) != NULL) {
            switch (attribute[0]) {
                case 'T': { // type encoding
                    size_t len = strlen(attribute);
                    if (len > 2 && attribute[0] == 'T' && attribute[1] == '@') { // [@(attribute) hasPrefix:@"T@"]
                        attribute[len - 1] = '\0';
                        NSString *typeName = @((attribute + 3));
                        // "T@\"TestModel2<TCMappingIgnore><TCNSCodingIgnore>"
                        if (attribute[len - 2] == '>') {
                            NSRange range = [typeName rangeOfString:@"<"];
                            if (range.location != NSNotFound) {
                                typeName = [typeName substringFromIndex:range.location];
                                if ([typeName rangeOfString:NSStringFromProtocol(@protocol(NSCodingIgnore))].location != NSNotFound) {
                                    ignore = YES;
                                }
                            }
                        }
                    }
                    break;
                }
                    
                case 'R': { // readonly
                    ignore = YES;
                    break;
                }
                    
                default:
                    break;
            }
        }
        
        if (ignore) {
            continue;
        }
        
        NSString *propertyName = [NSString stringWithUTF8String:property_getName(properties[i])];
        if (nil != propertyName && nameMapping[propertyName] != (id)kCFNull) {
            [arry addObject:propertyName];
        }
    }
    free(properties);
    
    [arry addObjectsFromArray:codingPropertyListUntilNSObjectFrom(class_getSuperclass(klass))];
    s_writablePropertyByClass[key] = arry;
    
    [s_recursiveLock unlock];
    return arry;
}

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
    for (NSString *key in codingPropertyListUntilNSObjectFrom(self.class)) {
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
    for (NSString *key in codingPropertyListUntilNSObjectFrom(self.class)) {
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
