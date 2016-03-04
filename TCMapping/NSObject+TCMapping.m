//
//  NSObject+TCMapping.m
//  TCKit
//
//  Created by dake on 13-12-29.
//  Copyright (c) 2013年 dake. All rights reserved.
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

#import "TCMappingMeta.h"


#if ! __has_feature(objc_arc)
#error this file is ARC only. Either turn on ARC for the project or use -fobjc-arc flag
#endif

//#define NO_ASSERT

#ifdef NO_ASSERT

#ifdef NSCAssert
#undef NSCAssert
#endif

#define NSCAssert(...) ;

#endif



#pragma mark -

static NSDateFormatter *tc_mapping_date_write_fmter(void)
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

static NSNumberFormatter *tc_mapping_number_fmter(void)
{
    static NSNumberFormatter *s_fmt = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_fmt = [[NSNumberFormatter alloc] init];
        s_fmt.numberStyle = NSNumberFormatterDecimalStyle;
    });
    
    return s_fmt;
}


#pragma mark -

NS_INLINE Class classForType(id type)
{
    if (nil != type) {
        if (class_isMetaClass(object_getClass(type))) {
            return type;
        } else if ([type isKindOfClass:NSString.class]) {
            return NSClassFromString(type);
        }
    }
    
    return Nil;
}

NS_INLINE NSDictionary<NSString *, NSString *> *nameMappingDicFor(NSDictionary *inputMappingDic, NSArray<NSString *> *sysWritableProperties)
{
    if (inputMappingDic.count < 1) {
        return [NSDictionary dictionaryWithObjects:sysWritableProperties forKeys:sysWritableProperties];
    }
    
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

NS_INLINE id mappingNSValueWithString(NSString *value, __unsafe_unretained TCMappingMeta *meta)
{
    id ret = value;
    BOOL isStringValue = [value isKindOfClass:NSString.class];
    
    switch (meta->_classType) {
        case kTCMappingClassTypeCGPoint:
            // "{x,y}"
            ret = isStringValue ? [NSValue valueWithCGPoint:CGPointFromString(value)] : nil;
            break;
            
        case kTCMappingClassTypeCGVector:
            // "{dx, dy}"
            ret = isStringValue ? [NSValue valueWithCGVector:CGVectorFromString(value)] : nil;
            break;
            
        case kTCMappingClassTypeCGSize:
            // "{w, h}"
            ret = isStringValue ? [NSValue valueWithCGSize:CGSizeFromString(value)] : nil;
            break;
            
        case kTCMappingClassTypeCGRect:
            // "{{x,y},{w, h}}"
            ret = isStringValue ? [NSValue valueWithCGRect:CGRectFromString(value)] : nil;
            break;
            
        case kTCMappingClassTypeCGAffineTransform:
            // "{a, b, c, d, tx, ty}"
            ret = isStringValue ?  [NSValue valueWithCGAffineTransform:CGAffineTransformFromString(value)] : nil;
            break;
            
        case kTCMappingClassTypeUIEdgeInsets:
            // "{top, left, bottom, right}"
            ret = isStringValue ? [NSValue valueWithUIEdgeInsets:UIEdgeInsetsFromString(value)] : nil;
            break;
            
        case kTCMappingClassTypeUIOffset:
            // "{horizontal, vertical}"
            ret = isStringValue ? [NSValue valueWithUIOffset:UIOffsetFromString(value)] : nil;
            
        default:
            break;
    }
    
    NSCAssert(nil != ret, @"property type %@ doesn't match value type %@", meta->_typeName, NSStringFromClass(value.class));
    return ret;
}

NS_INLINE id valueForBaseTypeOfPropertyName(NSString *propertyName, id value, __unsafe_unretained TCMappingMeta *meta, NSDictionary *typeMappingDic, __unsafe_unretained Class currentClass)
{
    if (nil == meta) {
        return nil;
    }
    
    id ret = value;
    
    if (meta->_isObj) {
        __unsafe_unretained Class klass = meta->_typeClass;
        
        switch (meta->_classType) {
            case kTCMappingClassTypeNSString: { // NSString <- non NSString
                BOOL isStringValue = [ret isKindOfClass:NSString.class];
                NSCAssert(isStringValue, @"property %@ type %@ doesn't match value type %@", propertyName, NSStringFromClass(klass), NSStringFromClass(((NSObject *)ret).class));
                if (!isStringValue) {
                    ret = [NSString stringWithFormat:@"%@", ret];
                }
                
                if (klass != NSString.class) {
                    ret = [klass stringWithString:ret];
                }
                
                break;
            }
                
            case kTCMappingClassTypeNSNumber: { // NSNumber <- NSString
                if (![ret isKindOfClass:NSNumber.class]) {
                    NSCAssert(false, @"property %@ type %@ doesn't match value type %@", propertyName, NSStringFromClass(klass), NSStringFromClass(((NSObject *)ret).class));
                    if ([ret isKindOfClass:NSString.class]) {
                        ret = [tc_mapping_number_fmter() numberFromString:(NSString *)ret];
                    } else {
                        ret = nil;
                    }
                }
                
                break;
            }
                
            case kTCMappingClassTypeNSValue: {
                if (![ret isMemberOfClass:klass]) {
                    NSCAssert(false, @"property %@ type %@ doesn't match value type %@", propertyName, NSStringFromClass(klass), NSStringFromClass(((NSObject *)ret).class));
                    ret = nil;
                }
                
                break;
            }
                
            case kTCMappingClassTypeNSDate: { // NSDate <-- NSString
                if ([ret isKindOfClass:NSString.class]) { // NSDate <-- NSString
                    NSString *fmtStr = typeMappingDic[propertyName];
                    if (nil != fmtStr && (id)kCFNull != fmtStr && [fmtStr isKindOfClass:NSString.class] && fmtStr.length > 0) {
                        NSDateFormatter *fmt = tc_mapping_date_write_fmter();
                        fmt.timeZone = [currentClass tc_dateTimeZone];
                        fmt.dateFormat = fmtStr;
                        ret = [fmt dateFromString:ret];
                    } else {
                        ret = nil;
                    }
                } else if ([ret isKindOfClass:NSNumber.class]) { // NSDate <-- timestamp
                    BOOL ignore = NO;
                    NSTimeInterval timestamp = [currentClass tc_timestampToSecondSince1970:((NSNumber *)ret).doubleValue ignoreReturn:&ignore];
                    if (ignore) {
                        ret = nil;
                    } else {
                        ret = [NSDate dateWithTimeIntervalSince1970:timestamp];
                    }
                } else if (![ret isKindOfClass:NSDate.class]) {
                    ret = nil;
                }
                
                break;
            }
                
            case kTCMappingClassTypeNSURL: { // NSURL <-- NSString
                if ([ret isKindOfClass:NSString.class]) {
                    ret = [klass URLWithString:ret];
                } else if (![ret isKindOfClass:NSURL.class]) {
                    ret = nil;
                }
                
                break;
            }
                
            default:
                break;
        }
        
    } else {
        if ([meta->_typeName hasPrefix:@"{"]) {
            // NSValue <- NSString
            ret = mappingNSValueWithString(ret ,meta);
        }
    }
    
    return ret;
}


#pragma mark - TCMapping

@implementation NSObject (TCMapping)

- (BOOL)tc_mappingValidate
{
    return YES;
}

+ (BOOL)tc_mappingIgnoreNSNull
{
    return YES;
}

+ (NSDictionary<__kindof NSString *, __kindof NSString *> *)tc_propertyNameMapping
{
    return nil;
}

+ (NSDictionary<__kindof NSString *, id> *)tc_propertyTypeFormat
{
    return nil;
}

+ (NSDictionary<__kindof NSString *, __kindof NSObject *> *)tc_propertyForPrimaryKey
{
    return nil;
}

+ (NSTimeZone *)tc_dateTimeZone
{
    return nil;
}

+ (NSTimeInterval)tc_timestampToSecondSince1970:(NSTimeInterval)timestamp ignoreReturn:(BOOL *)ignore
{
    if (NULL != ignore) {
        *ignore = timestamp <= 0;
    }
    return timestamp;
}

+ (NSMutableArray *)tc_mappingWithArray:(NSArray *)arry
{
    return [self tc_mappingWithArray:arry managerObjectContext:nil];
}

+ (NSMutableArray *)tc_mappingWithArray:(NSArray *)arry managerObjectContext:(NSManagedObjectContext *)context
{
    if (nil == arry || ![arry isKindOfClass:NSArray.class] || arry.count < 1) {
        return nil;
    }
    
    NSMutableArray *outArry = [NSMutableArray array];
    for (NSDictionary *dic in arry) {
        @autoreleasepool {
            id obj = [self tc_mappingWithDictionary:dic managerObjectContext:context];
            if (nil != obj) {
                [outArry addObject:obj];
            }
        }
    }
    
    return outArry.count > 0 ? outArry : nil;
}

+ (instancetype)tc_mappingWithDictionary:(NSDictionary *)dic
{
    return [self tc_mappingWithDictionary:dic propertyMapping:nil context:nil targetBlock:nil useInputPropertyMappingOnly:NO];
}

+ (instancetype)tc_mappingWithDictionary:(NSDictionary *)dic managerObjectContext:(NSManagedObjectContext *)context
{
    return [self tc_mappingWithDictionary:dic propertyMapping:nil context:context targetBlock:nil useInputPropertyMappingOnly:NO];
}

+ (instancetype)tc_mappingWithDictionary:(NSDictionary *)dataDic
                         propertyMapping:(NSDictionary<NSString *, NSString *> *)inputNameDic
                                 context:(NSManagedObjectContext *)context
                             targetBlock:(id(^)(void))targetBlock
             useInputPropertyMappingOnly:(BOOL)useInputNameDicOnly
{
    if (nil == dataDic || ![dataDic isKindOfClass:NSDictionary.class] || dataDic.count < 1) {
        return nil;
    }
    
    NSObject *obj = nil;
    if (nil != targetBlock) {
        obj = targetBlock();
    }
    Class currentClass = obj.class ?: self;
    
    NSDictionary *typeDic = currentClass.tc_propertyTypeFormat;
    NSDictionary *nameDic = inputNameDic;
    __unsafe_unretained NSDictionary<NSString *, TCMappingMeta *> *metaDic = tc_propertiesUntilRootClass(currentClass);
    
    if (!useInputNameDicOnly || inputNameDic.count < 1) {
        NSDictionary *inputMappingDic = inputNameDic;
        if (inputMappingDic.count < 1) {
            inputMappingDic = currentClass.tc_propertyNameMapping;
        }
        nameDic = nameMappingDicFor(inputMappingDic, metaDic.allKeys);
    }
    
    BOOL ignoreNSNull = currentClass.tc_mappingIgnoreNSNull;
    for (__unsafe_unretained NSString *propertyName in nameDic) {
        if (nil == propertyName || (id)kCFNull == propertyName || (id)kCFNull == nameDic[propertyName]) {
            continue;
        }
        
        TCMappingMeta *meta = metaDic[propertyName];
        if (meta->_ignoreMapping || NULL == meta->_setter) {
            continue;
        }
        
        NSObject *value = dataDic[nameDic[propertyName]];
        if (nil == value) {
            value = dataDic[propertyName];
        }
        
        if (nil == value || ((id)kCFNull == value && ignoreNSNull)) {
            continue;
        }
        
        if ([value isKindOfClass:NSDictionary.class]) {
            __unsafe_unretained NSDictionary *valueDataDic = (NSDictionary *)value;
            if (valueDataDic.count > 0) {
                __unsafe_unretained TCMappingMeta *meta = metaDic[propertyName];
                __unsafe_unretained Class klass = meta->_typeClass;
                if (Nil == klass) {
                    value = nil;
                } else if (meta->_classType == kTCMappingClassTypeNSDictionary) {
                    
                    __unsafe_unretained Class dicValueClass = classForType(typeDic[propertyName]);
                    if (Nil != dicValueClass) {
                        NSMutableDictionary *tmpDic = [NSMutableDictionary dictionary];
                        NSDictionary *dicValueNameDic = nameMappingDicFor(dicValueClass.tc_propertyNameMapping, tc_propertiesUntilRootClass(dicValueClass).allKeys);
                        for (id dicKey in valueDataDic) {
                            id tmpValue = [dicValueClass tc_mappingWithDictionary:valueDataDic[dicKey] propertyMapping:dicValueNameDic context:context targetBlock:nil useInputPropertyMappingOnly:YES];
                            if (nil != tmpValue) {
                                tmpDic[dicKey] = tmpValue;
                            }
                        }
                        
                        value = tmpDic.count > 0 ? [klass dictionaryWithDictionary:tmpDic] : nil;
                    } else if (valueDataDic.class != klass) {
                        value = [klass dictionaryWithDictionary:valueDataDic];
                    }
                } else {
                    value = [klass tc_mappingWithDictionary:valueDataDic propertyMapping:nil context:context targetBlock:nil == obj ? nil : ^{
                        return [obj valueForKey:propertyName];
                    } useInputPropertyMappingOnly:NO];
                }
            } else {
                value = nil;
            }
            
        } else if ([value isKindOfClass:NSArray.class]) {
            __unsafe_unretained NSArray *valueDataArry = (NSArray *)value;
            if (valueDataArry.count > 0) {
                
                __unsafe_unretained TCMappingMeta *meta = metaDic[propertyName];
                if (Nil == meta->_typeClass || meta->_classType != kTCMappingClassTypeNSArray) {
                    value = nil;
                } else {
                    __unsafe_unretained Class arrayItemType = classForType(typeDic[propertyName]);
                    if (Nil != arrayItemType) {
                        value = [arrayItemType mappingArray:valueDataArry withContext:context];
                    }
                    
                    if (nil != value && ![value isKindOfClass:meta->_typeClass]) {
                        value = [meta->_typeClass arrayWithArray:(NSArray *)value];
                    }
                }
            }
        } else if (value != (id)kCFNull) {
            value = valueForBaseTypeOfPropertyName(propertyName, value, metaDic[propertyName], typeDic, currentClass);
        }
        
        if (nil == value) {
            continue;
        } else if (value == (id)kCFNull) {
            value = nil;
        }
        
        if (nil == obj) {
            if (nil == context) {
                obj = [[currentClass alloc] init];
            } else {
                obj = [currentClass coreDataInstanceWithValue:dataDic nameMappingDic:nameDic context:context];
            }
        }
        
        [obj setValue:value forKey:propertyName];
    }
    
    return obj.tc_mappingValidate ? obj : nil;
}

+ (instancetype)coreDataInstanceWithValue:(NSDictionary *)value nameMappingDic:(NSDictionary *)nameDic context:(NSManagedObjectContext *)context
{
    // fill up primary keys
    NSMutableDictionary *primaryKey = self.tc_propertyForPrimaryKey.mutableCopy;
    for (NSString *pKey in primaryKey) {
        id tmpValue = value[nameDic[pKey]];
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
            id obj = [self tc_mappingWithDictionary:dic managerObjectContext:context];
            if (nil != obj) {
                [arry addObject:obj];
            }
        } else {
            if ([dic isKindOfClass:self]) {
                [arry addObject:dic];
            }
        }
    }
    
    return arry.count > 0 ? arry : nil;
}

- (void)tc_mappingWithDictionary:(NSDictionary *)dic
{
    [self tc_mappingWithDictionary:dic propertyNameMapping:nil];
}

- (void)tc_mappingWithDictionary:(NSDictionary *)dic propertyNameMapping:(NSDictionary *)extraNameMappingDic
{
    [self.class tc_mappingWithDictionary:dic propertyMapping:extraNameMappingDic context:nil targetBlock:^{
        return self;
    } useInputPropertyMappingOnly:NO];
}



#pragma mark - async

+ (dispatch_queue_t)tc_mappingQueue
{
    return dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
}


+ (void)tc_asyncMappingWithArray:(NSArray *)arry finish:(void(^)(NSMutableArray *dataList))finish
{
    [self tc_asyncMappingWithArray:arry managerObjectContext:nil inQueue:nil finish:finish];
}

+ (void)tc_asyncMappingWithDictionary:(NSDictionary *)dic finish:(void(^)(id data))finish
{
    [self tc_asyncMappingWithDictionary:dic managerObjectContext:nil inQueue:nil finish:finish];
}

+ (void)tc_asyncMappingWithArray:(NSArray *)arry inQueue:(dispatch_queue_t)queue finish:(void(^)(NSMutableArray *dataList))finish
{
    [self tc_asyncMappingWithArray:arry managerObjectContext:nil inQueue:queue finish:finish];
}

+ (void)tc_asyncMappingWithDictionary:(NSDictionary *)dic inQueue:(dispatch_queue_t)queue finish:(void(^)(id data))finish
{
    [self tc_asyncMappingWithDictionary:dic managerObjectContext:nil inQueue:queue finish:finish];
}


+ (void)tc_asyncMappingWithDictionary:(NSDictionary *)dic managerObjectContext:(NSManagedObjectContext *)context inQueue:(dispatch_queue_t)queue finish:(void(^)(id data))finish
{
    if (nil == finish) {
        return;
    }
    
    dispatch_async(queue ?: self.tc_mappingQueue, ^{
        @autoreleasepool {
            id data = [self tc_mappingWithDictionary:dic managerObjectContext:context];
            dispatch_async(dispatch_get_main_queue(), ^{
                finish(data);
            });
        }
    });
}

+ (void)tc_asyncMappingWithArray:(NSArray *)arry managerObjectContext:(NSManagedObjectContext *)context inQueue:(dispatch_queue_t)queue finish:(void(^)(NSMutableArray *dataList))finish
{
    if (nil == finish) {
        return;
    }
    
    dispatch_async(queue ?: self.tc_mappingQueue, ^{
        @autoreleasepool {
            NSMutableArray *dataList = [self tc_mappingWithArray:arry managerObjectContext:context];
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
