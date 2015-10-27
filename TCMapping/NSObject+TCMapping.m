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


#define NO_ASSERT

#ifdef NO_ASSERT

#ifdef NSCAssert
#undef NSCAssert
#endif

#define NSCAssert(...) ;

#endif


typedef NS_ENUM (NSUInteger, TCMappingClassType) {
    kTCMappingClassTypeUnknown = 0,
    kTCMappingClassTypeNSString,
    kTCMappingClassTypeNSMutableString,
    kTCMappingClassTypeNSValue,
    kTCMappingClassTypeNSNumber,
    kTCMappingClassTypeNSDate,
    kTCMappingClassTypeNSURL,
    kTCMappingClassTypeNSArray,
    kTCMappingClassTypeNSMutableArray,
    kTCMappingClassTypeNSDictionary,
    kTCMappingClassTypeNSMutableDictionary,
};


@interface TCMappingMeta : NSObject
{
@public
    NSString *_typeName;
    BOOL _isObj;
    
    TCMappingClassType _classType;
}

@end

@implementation TCMappingMeta

@end


NS_INLINE Class classForMeta(TCMappingMeta *meta)
{
    if ((id)kCFNull != meta && nil != meta && meta->_isObj) {
        return NSClassFromString(meta->_typeName);
    }
    
    return Nil;
}

NS_INLINE Class classForType(id type)
{
    if (nil == type) {
        return Nil;
    }
    
    if (class_isMetaClass(object_getClass(type))) {
        return type;
    }
    else if ([type isKindOfClass:NSString.class]) {
        return NSClassFromString(type);
    }
    
    return Nil;
}

static NSDictionary *readwritePropertyListUntilNSObjectFrom(Class klass)
{
    if (Nil == klass || klass == NSObject.class) {
        return nil;
    }
    
    static NSRecursiveLock *s_recursiveLock;
    static NSMutableDictionary *s_writablePropertyByClass;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_writablePropertyByClass = [NSMutableDictionary dictionary];
        s_recursiveLock = [[NSRecursiveLock alloc] init];
    });
    
    NSString *key = NSStringFromClass(klass);
    
    [s_recursiveLock lock];
    NSMutableDictionary *propertyNames = s_writablePropertyByClass[key];
    if (nil != propertyNames) {
        [s_recursiveLock unlock];
        return propertyNames;
    }
    
    propertyNames = [NSMutableDictionary dictionary];
    unsigned int num = 0;
    objc_property_t *properties = class_copyPropertyList(klass, &num);
    for (unsigned int i = 0; i < num; ++i) {
        
        const char *attributes = property_getAttributes(properties[i]);
        char buffer[1 + strlen(attributes)];
        strcpy(buffer, attributes);
        char *state = buffer;
        char *attribute = NULL;
        
        BOOL isObj = NO;
        BOOL isWritable = NULL != attributes;
        NSString *typeName = nil;
        
        NSInteger j = 0;
        while (j++ < 2 && (attribute = strsep(&state, ",")) != NULL) {
            switch (attribute[0]) {
                case 'T': { // type encoding
                    size_t len = strlen(attribute);
                    if ([@(attribute) hasPrefix:@"T@"]) {
                        
                        if (len == 2) {
                            isObj = NO;
                            typeName = @"id";
                        } else {
                            isObj = YES;
                            attribute[len - 1] = '\0';
                            typeName = @((attribute + 3));
                        }
                    } else {
                        isObj = NO;
                        if (len > 5 && attribute[1] == '{') { // CGRect. etc contains '{'
                            typeName = @((attribute + 1));
                        }
                    }
                    
                    break;
                }
                    
                case 'R': { // readonly
                    isWritable = NO;
                    break;
                }
                    
                default:
                    break;
            }
        }
        
        if (isWritable) {
            NSString *propertyName = [NSString stringWithUTF8String:property_getName(properties[i])];
            // TODO: custom set method
            if (nil != propertyName) {
                TCMappingMeta *meta = nil;
                if (nil != typeName) {
                    
                    // TODO: fill TCMappingClassType
                    meta = [[TCMappingMeta alloc] init];
                    meta->_typeName = typeName;
                    meta->_isObj = isObj;
                }
                
                propertyNames[propertyName] = meta ?: (id)kCFNull;
            }
        }
    }
    free(properties);
    
    [propertyNames addEntriesFromDictionary:readwritePropertyListUntilNSObjectFrom(class_getSuperclass(klass))];
    s_writablePropertyByClass[key] = propertyNames;
    
    [s_recursiveLock unlock];
    return propertyNames;
}


#pragma mark - MappingRuntimeHelper


NS_INLINE NSDictionary *nameMappingDicFor(NSDictionary *inputMappingDic, NSArray *sysWritableProperties)
{
    if (inputMappingDic.count < 1) {
        return [NSDictionary dictionaryWithObjects:sysWritableProperties forKeys:sysWritableProperties];
    }
    
    // FIXME: slow
    // filter out readonly property
    NSMutableDictionary *readOnlyInput = inputMappingDic.mutableCopy;
    [readOnlyInput removeObjectsForKeys:sysWritableProperties];
    NSDictionary *writableInput = inputMappingDic;
    if (readOnlyInput.count > 0) {
        writableInput = inputMappingDic.mutableCopy;
        [(NSMutableDictionary *)writableInput removeObjectsForKeys:readOnlyInput.allKeys];
    }
    
    NSMutableDictionary *tmpDic = [NSMutableDictionary dictionaryWithObjects:sysWritableProperties forKeys:sysWritableProperties];
    [tmpDic removeObjectsForKeys:writableInput.allKeys];
    [tmpDic addEntriesFromDictionary:writableInput];
    inputMappingDic = tmpDic;
    
    return inputMappingDic;
}

NS_INLINE id mappingNSValueWithString(NSString *value, const char *typeNameString)
{
    id ret = value;
    BOOL isStringValue = [value isKindOfClass:NSString.class];
    if (strcmp(typeNameString, @encode(CGPoint)) == 0) {
        // "{x,y}"
        ret = isStringValue ? [NSValue valueWithCGPoint:CGPointFromString(value)] : nil;
    } else if (strcmp(typeNameString, @encode(CGVector)) == 0) {
        // "{dx, dy}"
        ret = isStringValue ? [NSValue valueWithCGVector:CGVectorFromString(value)] : nil;
    } else if (strcmp(typeNameString, @encode(CGSize)) == 0) {
        // "{w, h}"
        ret = isStringValue ? [NSValue valueWithCGSize:CGSizeFromString(value)] : nil;
    } else if (strcmp(typeNameString, @encode(CGRect)) == 0) {
        // "{{x,y},{w, h}}"
        ret = isStringValue ? [NSValue valueWithCGRect:CGRectFromString(value)] : nil;
    } else if (strcmp(typeNameString, @encode(CGAffineTransform)) == 0) {
        // "{a, b, c, d, tx, ty}"
        ret = isStringValue ?  [NSValue valueWithCGAffineTransform:CGAffineTransformFromString(value)] : nil;
    } else if (strcmp(typeNameString, @encode(UIEdgeInsets)) == 0) {
        // "{top, left, bottom, right}"
        ret = isStringValue ? [NSValue valueWithUIEdgeInsets:UIEdgeInsetsFromString(value)] : nil;
    } else if (strcmp(typeNameString, @encode(UIOffset)) == 0) {
        // "{horizontal, vertical}"
        ret = isStringValue ? [NSValue valueWithUIOffset:UIOffsetFromString(value)] : nil;
    }
    NSCAssert(nil != ret, @"property type %s doesn't match value type %@", typeNameString, NSStringFromClass(((NSObject *)value).class));
    
    return ret;
}

static NSDateFormatter *tcmapping_writeFmter(void)
{
    static NSDateFormatter *s_fmt = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_fmt = [[NSDateFormatter alloc] init];
        s_fmt.dateStyle = NSDateFormatterNoStyle;
        s_fmt.timeStyle = NSDateFormatterNoStyle;
    });
    
    return s_fmt;
}

NS_INLINE id valueForBaseTypeOfPropertyName(NSString *propertyName, id value, __unsafe_unretained TCMappingMeta *meta, NSDictionary *typeMappingDic, __unsafe_unretained Class currentClass)
{
    if ((id)kCFNull == meta || nil == meta) {
        return value;
    }
    
    id ret = value;
    
    if (meta->_isObj) {
        Class klass = NSClassFromString(meta->_typeName);
        
        if (Nil == klass) {
            
        } else if ([klass isSubclassOfClass:NSString.class]) { // NSString <- non NSString
            
            BOOL isStringValue = [ret isKindOfClass:NSString.class];
            NSCAssert(isStringValue, @"property %@ type %@ doesn't match value type %@", propertyName, NSStringFromClass(klass), NSStringFromClass(((NSObject *)ret).class));
            if (!isStringValue) {
                ret = [NSString stringWithFormat:@"%@", ret];
            }
            
            if (klass != NSString.class) {
                ret = [klass stringWithString:ret];
            }
        } else if ([klass isSubclassOfClass:NSNumber.class]) { // NSNumber <- NSString
            if (![ret isKindOfClass:NSNumber.class]) {
                NSCAssert(false, @"property %@ type %@ doesn't match value type %@", propertyName, NSStringFromClass(klass), NSStringFromClass(((NSObject *)ret).class));
                if ([ret isKindOfClass:NSString.class]) {
                    ret = [klass numberWithDouble:((NSString *)value).doubleValue];
                } else {
                    ret = nil;
                }
            }
            
        } else if ([klass isSubclassOfClass:NSValue.class]) {
            if (![ret isMemberOfClass:klass]) {
                NSCAssert(false, @"property %@ type %@ doesn't match value type %@", propertyName, NSStringFromClass(klass), NSStringFromClass(((NSObject *)ret).class));
                ret = nil;
            }
        } else if ([klass isSubclassOfClass:NSDate.class]) {
            
            if ([ret isKindOfClass:NSDate.class]) {
                
            } else if ([ret isKindOfClass:NSString.class]) { // NSDate <-- NSString
                NSString *fmtStr = typeMappingDic[propertyName];
                if (nil != fmtStr && (id)kCFNull != fmtStr && [fmtStr isKindOfClass:NSString.class] && fmtStr.length > 0) {
                    NSDateFormatter *fmt = tcmapping_writeFmter();
                    fmt.timeZone = [currentClass dateTimeZone];
                    fmt.dateFormat = fmtStr;
                    ret = [fmt dateFromString:ret];
                    
                } else {
                    ret = nil;
                }
            } else if ([ret isKindOfClass:NSNumber.class]) { // NSDate <-- timestamp
                NSTimeInterval timestamp = [currentClass timestampToSecondSince1970:((NSNumber *)ret).doubleValue];
                ret = [NSDate dateWithTimeIntervalSince1970:timestamp];
            } else {
                ret = nil;
            }
        } else if ([klass isSubclassOfClass:NSURL.class]) { // NSURL <-- NSString
            if ([ret isKindOfClass:NSURL.class]) {
                
            } else if ([ret isKindOfClass:NSString.class]) {
                ret = [klass URLWithString:ret];
                
            } else {
                ret = nil;
            }
        }
        
    } else {
        
        if ([meta->_typeName hasPrefix:@"{"]) {
            // NSValue <- NSString
            ret = mappingNSValueWithString(ret ,meta->_typeName.UTF8String);
        }
    }
    
    return ret;
}



@implementation NSObject (TCMapping)

- (BOOL)tc_validate
{
    return YES;
}

+ (NSDictionary<__kindof NSString *, __kindof NSString *> *)propertyNameMapping
{
    return nil;
}

+ (NSDictionary<__kindof NSString *, __kindof NSString *> *)propertyTypeFormat
{
    return nil;
}

+ (NSDictionary<__kindof NSString *, __kindof NSObject *> *)propertyForPrimaryKey
{
    return nil;
}

+ (NSTimeZone *)dateTimeZone
{
    return nil;
}

+ (NSTimeInterval)timestampToSecondSince1970:(NSTimeInterval)timestamp
{
    return timestamp;
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
    return [self mappingWithDictionary:dic propertyMapping:nil context:nil targetBlock:nil useInputPropertyDicOnly:NO];
}

+ (instancetype)mappingWithDictionary:(NSDictionary *)dic managerObjectContext:(NSManagedObjectContext *)context
{
    return [self mappingWithDictionary:dic propertyMapping:nil context:context targetBlock:nil useInputPropertyDicOnly:NO];
}

+ (instancetype)mappingWithDictionary:(NSDictionary *)dataDic
                      propertyMapping:(NSDictionary *)inputPropertyDic
                              context:(NSManagedObjectContext *)context
                          targetBlock:(id(^)(void))targetBlock
              useInputPropertyDicOnly:(BOOL)useInputPropertyDicOnly
{
    if (nil == dataDic || ![dataDic isKindOfClass:NSDictionary.class] || dataDic.count < 1) {
        return nil;
    }
    
    NSObject *obj = nil;
    if (nil != targetBlock) {
        obj = targetBlock();
    }
    Class currentClass = obj.class ?: self;
    
    NSDictionary *typeMappingDic = currentClass.propertyTypeFormat;
    NSDictionary *nameMappingDic = inputPropertyDic;
    __unsafe_unretained NSDictionary *sysWritablePropertiesMeta = readwritePropertyListUntilNSObjectFrom(currentClass);
    
    if (!useInputPropertyDicOnly || inputPropertyDic.count < 1) {
        NSDictionary *inputMappingDic = inputPropertyDic;
        if (inputMappingDic.count < 1) {
            inputMappingDic = currentClass.propertyNameMapping;
        }
        nameMappingDic = nameMappingDicFor(inputMappingDic, sysWritablePropertiesMeta.allKeys);
    }
    
    for (__unsafe_unretained NSString *propertyName in nameMappingDic) {
        if (nil == propertyName || (id)kCFNull == propertyName) {
            continue;
        }
        
        NSObject *value = dataDic[nameMappingDic[propertyName]];
        if (nil == value) {
            value = dataDic[propertyName];
        }
        if (nil == value || (id)kCFNull == value) {
            continue;
        }
        
        if ([value isKindOfClass:NSDictionary.class]) {
            __unsafe_unretained NSDictionary *valueDataDic = (NSDictionary *)value;
            if (valueDataDic.count > 0) {
                __unsafe_unretained Class klass = classForMeta(sysWritablePropertiesMeta[propertyName]);
                if (Nil == klass) {
                    value = nil;
                } else if ([klass isSubclassOfClass:NSDictionary.class]) {
                    __unsafe_unretained Class dicValueClass = classForType(typeMappingDic[propertyName]);
                    if (Nil != dicValueClass) {
                        NSMutableDictionary *tmpDic = [NSMutableDictionary dictionary];
                        NSDictionary *dicValueMappingDic = nameMappingDicFor(dicValueClass.propertyNameMapping, readwritePropertyListUntilNSObjectFrom(dicValueClass).allKeys);
                        for (id dicKey in valueDataDic) {
                            id tmpValue = [dicValueClass mappingWithDictionary:valueDataDic[dicKey] propertyMapping:dicValueMappingDic context:context targetBlock:nil useInputPropertyDicOnly:YES];
                            if (nil != tmpValue) {
                                tmpDic[dicKey] = tmpValue;
                            }
                        }
                        
                        value = tmpDic.count > 0 ? [klass dictionaryWithDictionary:tmpDic] : nil;
                    } else if (valueDataDic.class != klass) {
                        value = [klass dictionaryWithDictionary:valueDataDic];
                    }
                } else {
                    value = [klass mappingWithDictionary:valueDataDic propertyMapping:nil context:context targetBlock:nil == obj ? nil : ^{
                        return [obj valueForKey:propertyName];
                    } useInputPropertyDicOnly:NO];
                }
            } else {
                value = nil;
            }
            
        } else if ([value isKindOfClass:NSArray.class]) {
            __unsafe_unretained NSArray *valueDataArry = (NSArray *)value;
            if (valueDataArry.count > 0) {
                __unsafe_unretained Class arrayItemType = classForType(typeMappingDic[propertyName]);
                if (Nil != arrayItemType) {
                    value = [arrayItemType mappingArray:valueDataArry withContext:context];
                } else {
                    arrayItemType = classForMeta(sysWritablePropertiesMeta[propertyName]);
                    if (![arrayItemType isSubclassOfClass:NSArray.class]) {
                        value = nil;
                    } else if (arrayItemType != valueDataArry.class) {
                        value = [arrayItemType arrayWithArray:valueDataArry];
                    }
                }
            } else {
                value = nil;
            }
        } else {
            value = valueForBaseTypeOfPropertyName(propertyName, value, sysWritablePropertiesMeta[propertyName], typeMappingDic, currentClass);
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
    for (NSString *pKey in primaryKey) {
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
    NSMutableArray *arry = [NSMutableArray array];
    
    for (NSDictionary *dic in value) {
        if ([dic isKindOfClass:NSDictionary.class]) {
            id obj = [self mappingWithDictionary:dic managerObjectContext:context];
            if (nil != obj) {
                [arry addObject:obj];
            }
        } else {
            [arry addObject:dic];
        }
    }
    
    return arry.count > 0 ? arry : nil;
}

- (void)mappingWithDictionary:(NSDictionary *)dic
{
    [self mappingWithDictionary:dic propertyNameMapping:nil];
}

- (void)mappingWithDictionary:(NSDictionary *)dic propertyNameMapping:(NSDictionary *)extraNameMappingDic
{
    [self.class mappingWithDictionary:dic propertyMapping:extraNameMappingDic context:nil targetBlock:^{
        return self;
    } useInputPropertyDicOnly:NO];
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