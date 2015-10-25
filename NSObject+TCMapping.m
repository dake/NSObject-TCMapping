//
//  NSObject+TCMapping.m
//  TCKit
//
//  Created by ChenQi on 13-12-29.
//  Copyright (c) 2013年 Dake. All rights reserved.
//

#import "NSObject+TCMapping.h"
#import <objc/runtime.h>
#import <CoreGraphics/CGGeometry.h>
#import <UIKit/UIGeometry.h>

#if (__IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_7_0)
@import CoreData;
#else
#import <CoreData/CoreData.h>
#endif


#if ! __has_feature(objc_arc)
#error this file is ARC only. Either turn on ARC for the project or use -fobjc-arc flag
#endif


// TODO:

//@interface TCMappingMeta : NSObject
//{
//    @protected
//    NSString *_typeName;
//    BOOL _isObj;
//}
//
//@end
//
//@implementation TCMappingMeta
//
//
//@end


static NSRecursiveLock *s_recursiveLock;
static NSMutableDictionary *s_propertyClassByClassAndPropertyName;
static NSMutableDictionary *s_writablePropertyByClass;


static NSArray *readwritePropertyListUntilNSObjectFrom(Class klass)
{
    if (Nil == klass || klass == NSObject.class) {
        return nil;
    }
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_writablePropertyByClass = [NSMutableDictionary dictionary];
        s_propertyClassByClassAndPropertyName = [NSMutableDictionary dictionary];
        s_recursiveLock = [[NSRecursiveLock alloc] init];
    });
    
    NSString *key = NSStringFromClass(klass);
    
    [s_recursiveLock lock];
    NSMutableArray *propertyNames = s_writablePropertyByClass[key];
    if (nil != propertyNames) {
        [s_recursiveLock unlock];
        return propertyNames;
    }
    
    propertyNames = [NSMutableArray array];
    unsigned int num = 0;
    objc_property_t *properties = class_copyPropertyList(klass, &num);
    for (NSInteger i = 0; i < num; ++i) {
        
        const char *attributes = property_getAttributes(properties[i]);
        char buffer[1 + strlen(attributes)];
        strcpy(buffer, attributes);
        char *state = buffer;
        char *attribute = NULL;
        
        BOOL isObj = NO;
        BOOL isWritable = NULL != attributes;
        NSString *typeName = nil;
        
        while ((attribute = strsep(&state, ",")) != NULL) {
            switch (attribute[0]) {
                case 'T': { // type encoding
                    size_t len = strlen(attribute);
                    if ([@(attribute) hasPrefix:@"T@\""]) {
                        attribute[len - 1] = '\0';
                        isObj = YES;
                        typeName = @((attribute + 3));
                    } else {
                        isObj = NO;
                        if (len > 5 && attribute[1] == '{') { // CGRect 等 含 '{'
                            typeName = @((attribute + 1));
                        }
                    }
                    
                    break;
                }
                    
                case '@': {
                    isObj= YES;
                    typeName = @"id";
                    break;
                }
                    
                case 'R': { // readonly
                    isWritable = NO;
                    break;
                }
                    
                case 'S': { // custom setter
                    isWritable = YES;
                    break;
                }
                    
                default:
                    break;
            }
        }
        
        if (isWritable) {
            NSString *propertyName = [NSString stringWithUTF8String:property_getName(properties[i])];
            // TODO: custom set method
            if (nil != properties) {
                [propertyNames addObject:propertyName];
                
                if (nil != typeName) {
                    NSString *key = NSStringFromClass(klass);
                    NSMutableDictionary *dic = s_propertyClassByClassAndPropertyName[key];
                    if (nil == dic) {
                        dic = NSMutableDictionary.dictionary;
                        s_propertyClassByClassAndPropertyName[key] = dic;
                    }
                    dic[propertyName] = @[typeName, @(isObj)];
                }
            }
        }
    }
    free(properties);
    
    [propertyNames addObjectsFromArray:readwritePropertyListUntilNSObjectFrom(class_getSuperclass(klass))];
    s_writablePropertyByClass[key] = propertyNames;
    
    [s_recursiveLock unlock];
    return propertyNames;
}


#pragma mark - MappingRuntimeHelper

// FIXME: slow
static Class propertyClassForPropertyName(NSString *propertyName, Class klass, NSString **typeNameString)
{
    if (Nil == klass || klass == NSObject.class || nil == propertyName) {
        return Nil;
    }
    
    [s_recursiveLock lock];
    
    NSString *key = NSStringFromClass(klass);
    __unsafe_unretained NSDictionary *dic = s_propertyClassByClassAndPropertyName[key];
    __unsafe_unretained NSArray *arry = dic[propertyName];
    if (nil != arry) {
        __unsafe_unretained NSString *value = arry.firstObject;
        if (NULL != typeNameString) {
            *typeNameString = value;
        }
        
        __unsafe_unretained Class retClass = Nil;
        if ([arry.lastObject boolValue]) {
            retClass = NSClassFromString(value);
        }
        [s_recursiveLock unlock];
        return retClass;
    }

    [s_recursiveLock unlock];
    return propertyClassForPropertyName(propertyName, class_getSuperclass(klass), typeNameString);
}

NS_INLINE id mappingNSValueWithString(NSString *value, const char *typeNameString)
{
    id ret = value;
    BOOL isStringValue = [value isKindOfClass:NSString.class];
    if (strcmp(typeNameString, @encode(CGPoint)) == 0) {
        // "{x,y}"
        NSCAssert(isStringValue, @"property type %s doesn't match value type %@", typeNameString, NSStringFromClass(((NSObject *)value).class));
        ret = isStringValue ? [NSValue valueWithCGPoint:CGPointFromString(value)] : nil;
    } else if (strcmp(typeNameString, @encode(CGVector)) == 0) {
        // "{dx, dy}"
        NSCAssert(isStringValue, @"property type %s doesn't match value type %@", typeNameString, NSStringFromClass(((NSObject *)value).class));
        ret = isStringValue ? [NSValue valueWithCGVector:CGVectorFromString(value)] : nil;
    } else if (strcmp(typeNameString, @encode(CGSize)) == 0) {
        // "{w, h}"
        NSCAssert(isStringValue, @"property type %s doesn't match value type %@", typeNameString, NSStringFromClass(((NSObject *)value).class));
        ret = isStringValue ? [NSValue valueWithCGSize:CGSizeFromString(value)] : nil;
    } else if (strcmp(typeNameString, @encode(CGRect)) == 0) {
        // "{{x,y},{w, h}}"
        NSCAssert(isStringValue, @"property type %s doesn't match value type %@", typeNameString, NSStringFromClass(((NSObject *)value).class));
        ret = isStringValue ? [NSValue valueWithCGRect:CGRectFromString(value)] : nil;
    } else if (strcmp(typeNameString, @encode(CGAffineTransform)) == 0) {
        // "{a, b, c, d, tx, ty}"
        NSCAssert(isStringValue, @"property type %s doesn't match value type %@", typeNameString, NSStringFromClass(((NSObject *)value).class));
        ret = isStringValue ?  [NSValue valueWithCGAffineTransform:CGAffineTransformFromString(value)] : nil;
    } else if (strcmp(typeNameString, @encode(UIEdgeInsets)) == 0) {
        // "{top, left, bottom, right}"
        NSCAssert(isStringValue, @"property type %s doesn't match value type %@", typeNameString, NSStringFromClass(((NSObject *)value).class));
        ret = isStringValue ? [NSValue valueWithUIEdgeInsets:UIEdgeInsetsFromString(value)] : nil;
    } else if (strcmp(typeNameString, @encode(UIOffset)) == 0) {
        // "{horizontal, vertical}"
        NSCAssert(isStringValue, @"property type %s doesn't match value type %@", typeNameString, NSStringFromClass(((NSObject *)value).class));
        ret = isStringValue ? [NSValue valueWithUIOffset:UIOffsetFromString(value)] : nil;
    }
    
    return ret;
}

static id valueForBaseTypeOfPropertyName(NSString *propertyName, id value, Class currentClass)
{
    id ret = value;
    
    NSString *typeNameString = nil;
    Class klass = propertyClassForPropertyName(propertyName, currentClass, &typeNameString);
    if (nil == typeNameString) {
        return ret;
    }
    
    if ([typeNameString hasPrefix:@"{"]) {
        // NSValue <- NSString
        ret = mappingNSValueWithString(ret ,typeNameString.UTF8String);
    }
    
    if (nil == ret || Nil == klass) {
        return ret;
    }
    
    if ([klass isSubclassOfClass:NSString.class]) {
        // NSString <- non NSString
        BOOL isStringValue = [ret isKindOfClass:NSString.class];
        NSCAssert(isStringValue, @"property %@ type %@ doesn't match value type %@", propertyName, NSStringFromClass(klass), NSStringFromClass(((NSObject *)ret).class));
        if (!isStringValue) {
            ret = [NSString stringWithFormat:@"%@", ret];
        }
        
        // [klass isSubclassOfClass:NSMutableString.class]
        if (klass != NSString.class) {
            ret = [klass stringWithString:ret];
        }
        
    } else if ([klass isSubclassOfClass:NSNumber.class]) {
        if (![ret isKindOfClass:NSNumber.class]) {
            NSCAssert(false, @"property %@ type %@ doesn't match value type %@", propertyName, NSStringFromClass(klass), NSStringFromClass(((NSObject *)ret).class));
            if ([ret isKindOfClass:NSString.class]) {
                // NSNumber <- NSString
                ret = [klass numberWithDouble:((NSString *)value).doubleValue];
            } else {
                ret = nil;
            }
        }
    }
    
    return ret;
}



@implementation NSObject (TCMapping)

- (BOOL)tc_validate
{
    return YES;
}

+ (NSDictionary *)propertyNameMapping
{
    return nil;
}

+ (NSDictionary *)propertyTypeFormat
{
    return nil;
}

+ (NSDictionary *)propertyForPrimaryKey
{
    return nil;
}

+ (NSMutableArray *)mappingWithArray:(NSArray *)arry
{
    return [self mappingWithArray:arry managerObjectContext:nil];
}

+ (NSMutableArray *)mappingWithArray:(NSArray *)arry managerObjectContext:(NSManagedObjectContext *)context
{
    if (nil == arry || ![arry isKindOfClass:NSArray.class] || arry.count < 1) {
        return nil;
    }
    
    NSMutableArray *outArry = [NSMutableArray array];
    for (NSDictionary *dic in arry) {
        @autoreleasepool {
            id obj = [self mappingWithDictionary:dic managerObjectContext:context];
            if (nil != obj) {
                [outArry addObject:obj];
            }
        }
    }
    
    return outArry.count > 0 ? outArry : nil;
}

+ (instancetype)mappingWithDictionary:(NSDictionary *)dic
{
    return [self mappingWithDictionary:dic managerObjectContext:nil];
}

+ (instancetype)mappingWithDictionary:(NSDictionary *)dic managerObjectContext:(NSManagedObjectContext *)context
{
    return [self mappingWithDictionary:dic propertyNameMapping:nil managerObjectContext:context targetBlock:nil];
}

+ (instancetype)mappingWithDictionary:(NSDictionary *)dataDic
                  propertyNameMapping:(NSDictionary *)extraNameMappingDic
                 managerObjectContext:(NSManagedObjectContext *)context
                          targetBlock:(id(^)(void))targetBlock
{
    if (nil == dataDic || ![dataDic isKindOfClass:NSDictionary.class] || dataDic.count < 1) {
        return nil;
    }
    
    NSObject *obj = nil;
    if (nil != targetBlock) {
        obj = targetBlock();
    }
    Class currentClass = obj.class ?: self;
    
    NSDictionary *inputMappingDic = extraNameMappingDic;
    if (inputMappingDic.count < 1) {
        inputMappingDic = currentClass.propertyNameMapping;
    }
    
    NSArray *systemWritableProperties = readwritePropertyListUntilNSObjectFrom(currentClass);
    // filter out readonly property
    NSMutableDictionary *readOnlyInput = inputMappingDic.mutableCopy;
    [readOnlyInput removeObjectsForKeys:systemWritableProperties];
    NSDictionary *writableInput = inputMappingDic;
    if (readOnlyInput.count > 0) {
        writableInput = inputMappingDic.mutableCopy;
        [(NSMutableDictionary *)writableInput removeObjectsForKeys:readOnlyInput.allKeys];
    }
    
    NSMutableDictionary *tmpDic = [NSMutableDictionary dictionaryWithObjects:systemWritableProperties forKeys:systemWritableProperties];
    [tmpDic removeObjectsForKeys:writableInput.allKeys];
    [tmpDic addEntriesFromDictionary:writableInput];
    inputMappingDic = tmpDic;
    
    NSDictionary *nameMappingDic = inputMappingDic;
    NSDictionary *typeMappingDic = currentClass.propertyTypeFormat;
    
    
    for (NSString *propertyName in nameMappingDic.allKeys) {
        if (nil == propertyName
            || (id)kCFNull == propertyName) {
            continue;
        }
        
        id jsonKey = nameMappingDic[propertyName];
        id value = dataDic[jsonKey];
        if (nil == value) {
            value = dataDic[propertyName];
        }
        if (nil == value || (id)kCFNull == value) {
            continue;
        }
        
        if ([value isKindOfClass:NSDictionary.class]) {
            if ([(NSDictionary *)value count] > 0) {
                
                NSString *klassName = typeMappingDic[propertyName];
                Class klass = Nil;
                if (nil == klassName) {
                    klass = propertyClassForPropertyName(propertyName, currentClass, NULL);
                } else {
                    klass = NSClassFromString(klassName);
                }
                
                if (Nil != klass) {
                    value = [klass mappingWithDictionary:value propertyNameMapping:nil managerObjectContext:context targetBlock:nil == obj ? nil : ^id{
                        return [obj valueForKey:propertyName];
                    }];
                } else {
                    value = nil;
                }
            } else {
                value = nil;
            }
            
        } else if ([value isKindOfClass:NSArray.class]) {
            if ([(NSArray *)value count] > 0) {
                Class arrayItemType = NSClassFromString(typeMappingDic[propertyName]);
                if (Nil != arrayItemType) {
                    value = [arrayItemType mappingArray:value withContext:context];
                } else {
                    arrayItemType = propertyClassForPropertyName(propertyName, currentClass, NULL);
                    if (![arrayItemType isSubclassOfClass:NSArray.class]) {
                        value = nil;
                    }
                }
            } else {
                value = nil;
            }
        } else {
            value = valueForBaseTypeOfPropertyName(propertyName, value, currentClass);
        }
        
        
        if (nil == value) {
            continue;
        }
        
        if (nil == obj) {
            if (nil == context) {
                obj = [[currentClass alloc] init];
            } else {
                obj = [currentClass coreDataInstanceWithValue:dataDic withNameMappingDic:nameMappingDic withContext:context];
            }
        }
        
        [obj setValue:value forKey:propertyName];
    }
    
    return obj.tc_validate ? obj : nil;
}

+ (instancetype)coreDataInstanceWithValue:(NSDictionary *)value withNameMappingDic:(NSDictionary *)nameMappingDic withContext:(NSManagedObjectContext *)context
{
    NSMutableDictionary *primaryKey = self.propertyForPrimaryKey.mutableCopy;
    for (NSString *pKey in primaryKey.allKeys) {
        id tmpValue = value[nameMappingDic[pKey]];
        if (nil != tmpValue && tmpValue != (id)kCFNull) {
            primaryKey[pKey] = tmpValue;
        }
    }
    
    __block NSManagedObject *tempObj = nil;
    [context performBlockAndWait:^{
        if (primaryKey.count > 0) {
            tempObj = [self fetchDataFromDBWithPrimaryKey:primaryKey inContext:context];
        }
        
        if (nil == tempObj) {
            tempObj = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass(self) inManagedObjectContext:context];
        }
    }];
    
    return tempObj;
}


+ (instancetype)fetchDataFromDBWithPrimaryKey:(NSDictionary *)primaryKey inContext:(NSManagedObjectContext *)context
{
    NSMutableString *fmt = [NSMutableString string];
    NSArray *allKeys = primaryKey.allKeys;
    NSUInteger count = allKeys.count;
    for (NSInteger i = 0; i < count; ++i) {
        NSString *key = allKeys[i];
        if (i < count - 1) {
            [fmt appendFormat:@"%@==%%@&&", key];
        } else {
            [fmt appendFormat:@"%@==%%@", key];
        }
    }
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:fmt argumentArray:primaryKey.allValues];
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass(self)];
    fetchRequest.predicate = predicate;
    fetchRequest.fetchLimit = 1;
    //    fetchRequest.returnsObjectsAsFaults
    
    NSError *error = nil;
    NSArray *array = [context executeFetchRequest:fetchRequest error:&error];
    NSAssert(nil == error, @"%@", error.localizedDescription);
    
    return array.lastObject;
}


+ (NSArray *)mappingArray:(NSArray *)value withContext:(NSManagedObjectContext *)context
{
    NSMutableArray *childObjects = [NSMutableArray array];
    
    for (NSDictionary *child in value) {
        if ([child.class isSubclassOfClass:NSDictionary.class]) {
            NSObject *childDTO = [self mappingWithDictionary:child managerObjectContext:context];
            if (nil != childDTO) {
                [childObjects addObject:childDTO];
            }
        } else {
            [childObjects addObject:child];
        }
    }
    
    return childObjects.count > 0 ? childObjects : nil;
}

- (void)mappingWithDictionary:(NSDictionary *)dic
{
    [self mappingWithDictionary:dic propertyNameMapping:nil];
}

- (void)mappingWithDictionary:(NSDictionary *)dic propertyNameMapping:(NSDictionary *)extraNameMappingDic
{
    [self.class mappingWithDictionary:dic propertyNameMapping:extraNameMappingDic managerObjectContext:nil targetBlock:^id(void) {
        return self;
    }];
}



#pragma mark - async

+ (dispatch_queue_t)mappingQueue
{
    static dispatch_queue_t s_queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_queue = dispatch_queue_create("TCMappingQueue", DISPATCH_QUEUE_CONCURRENT);
    });
    
    return s_queue ?: dispatch_get_main_queue();
}


+ (void)asyncMappingWithArray:(NSArray *)arry finish:(void(^)(NSMutableArray *dataList))finish
{
    [self asyncMappingWithArray:arry managerObjectContext:nil inQueue:nil finish:finish];
}

+ (void)asyncMappingWithDictionary:(NSDictionary *)dic finish:(void(^)(id data))finish
{
    [self asyncMappingWithDictionary:dic managerObjectContext:nil inQueue:nil finish:finish];
}

+ (void)asyncMappingWithArray:(NSArray *)arry inQueue:(dispatch_queue_t)queue finish:(void(^)(NSMutableArray *dataList))finish
{
    [self asyncMappingWithArray:arry managerObjectContext:nil inQueue:queue finish:finish];
}

+ (void)asyncMappingWithDictionary:(NSDictionary *)dic inQueue:(dispatch_queue_t)queue finish:(void(^)(id data))finish
{
    [self asyncMappingWithDictionary:dic managerObjectContext:nil inQueue:queue finish:finish];
}


+ (void)asyncMappingWithDictionary:(NSDictionary *)dic managerObjectContext:(NSManagedObjectContext *)context inQueue:(dispatch_queue_t)queue finish:(void(^)(id data))finish
{
    if (nil == finish) {
        return;
    }
    
    dispatch_async(queue ?: self.mappingQueue, ^{
        @autoreleasepool {
            id data = [self mappingWithDictionary:dic managerObjectContext:context];
            dispatch_async(dispatch_get_main_queue(), ^{
                finish(data);
            });
        }
    });
}

+ (void)asyncMappingWithArray:(NSArray *)arry managerObjectContext:(NSManagedObjectContext *)context inQueue:(dispatch_queue_t)queue finish:(void(^)(NSMutableArray *dataList))finish
{
    if (nil == finish) {
        return;
    }
    
    dispatch_async(queue ?: self.mappingQueue, ^{
        @autoreleasepool {
            NSMutableArray *dataList = [self mappingWithArray:arry managerObjectContext:context];
            dispatch_async(dispatch_get_main_queue(), ^{
                finish(dataList);
            });
        }
    });
}

@end


#pragma mark - NSDictionary+TCMapping

@implementation NSDictionary (TCMapping)

- (id)valueForKeyExceptNull:(NSString *)key
{
    id obj = self[key];
    
    return (id)kCFNull == obj ? nil : obj;
}

@end



#pragma mark - NSString+TC_NSNumber

@interface NSString (TC_NSNumber)
@end

@implementation NSString (TC_NSNumber)


- (char)charValue
{
    return self.intValue;
}

- (unsigned char)unsignedCharValue
{
    return self.intValue;
}

- (short)shortValue
{
    return self.intValue;
}

- (unsigned short)unsignedShortValue
{
    return self.intValue;
}

- (unsigned int)unsignedIntValue
{
    return self.intValue;
}

- (long)longValue
{
    return self.integerValue;
}

- (unsigned long)unsignedLongValue
{
    return self.integerValue;
}

- (unsigned long long)unsignedLongLongValue
{
    return self.longLongValue;
}


@end
