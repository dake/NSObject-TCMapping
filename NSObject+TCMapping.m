//
//  NSObject+TCMapping.m
//  TCKit
//
//  Created by ChenQi on 13-12-29.
//  Copyright (c) 2013年 Dake. All rights reserved.
//

#import "NSObject+TCMapping.h"
#import <objc/runtime.h>

#if (__IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_7_0)
@import CoreData;
#else
#import <CoreData/CoreData.h>
#endif


#if ! __has_feature(objc_arc)
#error this file is ARC only. Either turn on ARC for the project or use -fobjc-arc flag
#endif


static char const *const kReadOnlyFlag = "R";


static NSString *property_getTypeName(objc_property_t property, BOOL *isObj)
{
	const char *attributes = property_getAttributes(property);
    char buffer[1 + strlen(attributes)];
	strcpy(buffer, attributes);
    char *state = buffer;
    char *attribute = NULL;
	while ((attribute = strsep(&state, ",")) != NULL) {
		if (attribute[0] == 'T') {
			size_t len = strlen(attribute);
            if ([@(attribute) hasPrefix:@"T@\""]) {
                attribute[len - 1] = '\0';
                if (NULL != isObj) {
                    *isObj = YES;
                }
                return @((attribute + 3));
            }
            else {
                if (NULL != isObj) {
                    *isObj = NO;
                }
                return @((attribute + 1));
            }
		}
	}
    
    if (NULL != isObj) {
        *isObj = YES;
    }
	return @"@";
}

static BOOL isPropertyReadOnly(Class klass ,NSString *propertyName)
{
    if (Nil == klass || klass == NSObject.class) {
        return YES;
    }
    
    objc_property_t property = class_getProperty(klass, propertyName.UTF8String);
    if (NULL != property) {
        char *readonly = property_copyAttributeValue(property, kReadOnlyFlag);
        if (NULL == readonly) {
            return NO;
        }
        else {
            free(readonly);
            return YES;
        }
    }
    else {
        return isPropertyReadOnly(class_getSuperclass(klass), propertyName);
    }
}

static NSArray *readwritePropertyListUntilNSObjectFrom(Class klass)
{
    if (Nil == klass || klass == NSObject.class) {
        return nil;
    }
    
    NSMutableArray *propertyNames = [NSMutableArray array];
    unsigned int num = 0;
    objc_property_t *properties = class_copyPropertyList(klass, &num);
    for (NSInteger i = 0; i < num; ++i) {
        // !!!: filter out readonly property
        char *readonly = property_copyAttributeValue(properties[i], kReadOnlyFlag);
        if (NULL == readonly) {
            [propertyNames addObject:[NSString stringWithCString:property_getName(properties[i]) encoding:NSUTF8StringEncoding]];
        }
        else {
            free(readonly);
        }
    }
    free(properties);
    
    [propertyNames addObjectsFromArray:readwritePropertyListUntilNSObjectFrom(class_getSuperclass(klass))];
    return propertyNames;
}




static NSRecursiveLock *s_recursiveLock;
static NSMutableDictionary *s_propertyClassByClassAndPropertyName;
static NSMutableDictionary *s_propertyScalaTypeByClassAndPropertyName;

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
    
    NSDictionary *nameMappingDic = extraNameMappingDic;
    if (nameMappingDic.count < 1) {
        
        NSArray *systemReadwriteProperties = readwritePropertyListUntilNSObjectFrom(currentClass);
        NSMutableDictionary *tmpDic = [NSMutableDictionary dictionaryWithObjects:systemReadwriteProperties forKeys:systemReadwriteProperties];
        nameMappingDic = self.propertyNameMapping;
        [tmpDic removeObjectsForKeys:nameMappingDic.allKeys];
        [tmpDic addEntriesFromDictionary:nameMappingDic];
        nameMappingDic = tmpDic;
    }
    
    NSDictionary *typeMappingDic = self.propertyTypeFormat;
    
    
    for (NSString *nameKey in nameMappingDic.allKeys) {
        if (nil == nameKey
            || [NSNull null] == (NSNull *)nameKey
            || isPropertyReadOnly(currentClass, nameKey)) {
            continue;
        }
        
        id jsonKey = nameMappingDic[nameKey];
        id value = dataDic[jsonKey];
        if (nil == value) {
            value = dataDic[nameKey];
        }
        if (nil == value || [NSNull null] == value) {
            continue;
        }
        
        if ([value isKindOfClass:NSDictionary.class]) {
            if ([(NSDictionary *)value count] > 0) {
                
                NSString *klassName = typeMappingDic[nameKey];
                Class klass = Nil;
                if (nil == klassName) {
                    klass = [self propertyClassForPropertyName:jsonKey ofClass:currentClass];
                }
                else {
                    klass = NSClassFromString(klassName);
                }
                
                if (Nil != klass) {
                    value = [klass mappingWithDictionary:value propertyNameMapping:nil managerObjectContext:context targetBlock:nil == obj ? nil : ^id{
                        return [obj valueForKey:nameKey];
                    }];
                }
                else {
                    value = nil;
                }
            }
            else {
                value = nil;
            }
        }
        else if ([value isKindOfClass:NSArray.class]) {
            if ([(NSArray *)value count] > 0) {
                Class arrayItemType = NSClassFromString(typeMappingDic[nameKey]);
                if (Nil != arrayItemType) {
                    value = [arrayItemType mappingArray:value withContext:context];
                }
                else {
                    arrayItemType = [self propertyClassForPropertyName:nameMappingDic[nameKey] ofClass:currentClass];
                    if (![arrayItemType isSubclassOfClass:NSArray.class]) {
                        value = nil;
                    }
                }
            }
            else {
                value = nil;
            }
        }
        else if ([value isKindOfClass:NSString.class]) {
            value = [currentClass mappingNSValueWithString:value propertyName:nameMappingDic[nameKey]];
        }
    
        
        if (nil == value) {
            continue;
        }
        
        if (nil == obj) {
            if (nil == context) {
                obj = [[self alloc] init];
            }
            else {
                obj = [self coreDataInstanceWithValue:dataDic withNameMappingDic:nameMappingDic withContext:context];
            }
        }
        [obj setValue:value forKey:nameKey];
    }
    
    return [obj tc_validate] ? obj : nil;
}

+ (id)mappingNSValueWithString:(NSString *)value propertyName:(NSString *)propertyName
{
    NSString *typeNameString = nil;
    [self propertyClassForPropertyName:propertyName ofClass:self toTypeName:&typeNameString];
    if (nil == typeNameString || typeNameString.length < 5) {
        return value;
    }
    
    id ret = value;
    if ([typeNameString isEqualToString:@(@encode(CGPoint))]) {
        // "{x,y}"
        ret = [NSValue valueWithCGPoint:CGPointFromString(value)];
    }
    else if ([typeNameString isEqualToString:@(@encode(CGVector))]) {
        // "{dx, dy}"
        ret = [NSValue valueWithCGVector:CGVectorFromString(value)];
    }
    else if ([typeNameString isEqualToString:@(@encode(CGSize))]) {
        // "{w, h}"
        ret = [NSValue valueWithCGSize:CGSizeFromString(value)];
    }
    else if ([typeNameString isEqualToString:@(@encode(CGRect))]) {
        // "{{x,y},{w, h}}"
        ret = [NSValue valueWithCGRect:CGRectFromString(value)];
    }
    else if ([typeNameString isEqualToString:@(@encode(CGAffineTransform))]) {
        // "{a, b, c, d, tx, ty}"
        ret = [NSValue valueWithCGAffineTransform:CGAffineTransformFromString(value)];
    }
    else if ([typeNameString isEqualToString:@(@encode(UIEdgeInsets))]) {
        // "{top, left, bottom, right}"
        ret = [NSValue valueWithUIEdgeInsets:UIEdgeInsetsFromString(value)];
    }
    else if ([typeNameString isEqualToString:@(@encode(UIOffset))]) {
        // "{horizontal, vertical}"
        ret = [NSValue valueWithUIOffset:UIOffsetFromString(value)];
    }
    
    return ret;
}

+ (instancetype)coreDataInstanceWithValue:(NSDictionary *)value withNameMappingDic:(NSDictionary *)nameMappingDic withContext:(NSManagedObjectContext *)context
{
    NSMutableDictionary *primaryKey = self.propertyForPrimaryKey.mutableCopy;
    for (NSString *pKey in primaryKey.allKeys) {
        id tmpValue = value[nameMappingDic[pKey]];
        if (nil != tmpValue && tmpValue != [NSNull null]) {
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
        }
        else {
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
        }
        else {
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


#pragma mark - MappingRuntimeHelper

+ (Class)propertyClassForPropertyName:(NSString *)propertyName ofClass:(Class)klass
{
    return [self propertyClassForPropertyName:propertyName ofClass:klass toTypeName:NULL];
}

+ (Class)propertyClassForPropertyName:(NSString *)propertyName ofClass:(Class)klass toTypeName:(NSString **)typeNameString
{
    if (Nil == klass || klass == NSObject.class) {
        return Nil;
    }
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_propertyClassByClassAndPropertyName = [NSMutableDictionary dictionary];
        s_propertyScalaTypeByClassAndPropertyName = [NSMutableDictionary dictionary];
        s_recursiveLock = [[NSRecursiveLock alloc] init];
    });
    
    [s_recursiveLock lock];
    
    NSString *key = [NSString stringWithFormat:@"%@:%@", NSStringFromClass(klass), propertyName];
    NSString *value = s_propertyClassByClassAndPropertyName[key];
    
    if (nil != value) {
        if (NULL != typeNameString) {
            *typeNameString = value;
        }
        [s_recursiveLock unlock];
        return NSClassFromString(value);
    }
    
    value = s_propertyScalaTypeByClassAndPropertyName[key];
    if (nil != value) {
        if (NULL != typeNameString) {
            *typeNameString = value;
        }
        [s_recursiveLock unlock];
        return Nil;
    }
    
    objc_property_t property = class_getProperty(klass, propertyName.UTF8String);
    if (NULL != property) {
        BOOL isObj = NO;
        NSString *className = property_getTypeName(property, &isObj);
        if (nil != className) {
            if (NULL != typeNameString) {
                *typeNameString = className;
            }
            
            if (isObj) {
                s_propertyClassByClassAndPropertyName[key] = className;
                [s_recursiveLock unlock];
                return NSClassFromString(className);
            }
            else {
                s_propertyScalaTypeByClassAndPropertyName[key] = className;
            }
        }
        
        [s_recursiveLock unlock];
        return Nil;
    }
    
    [s_recursiveLock unlock];
    return [self propertyClassForPropertyName:propertyName ofClass:class_getSuperclass(klass) toTypeName:typeNameString];
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
