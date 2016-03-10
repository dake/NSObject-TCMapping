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

#import "TCMappingMeta.h"


#if ! __has_feature(objc_arc)
#error this file is ARC only. Either turn on ARC for the project or use -fobjc-arc flag
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
    id ret = nil;
    
    switch (meta->_classType) {
        case kTCMappingClassTypeCGPoint:
            // "{x,y}"
            ret = [NSValue valueWithCGPoint:CGPointFromString(value)];
            break;
            
        case kTCMappingClassTypeCGVector:
            // "{dx, dy}"
            ret = [NSValue valueWithCGVector:CGVectorFromString(value)];
            break;
            
        case kTCMappingClassTypeCGSize:
            // "{w, h}"
            ret = [NSValue valueWithCGSize:CGSizeFromString(value)];
            break;
            
        case kTCMappingClassTypeCGRect:
            // "{{x,y},{w, h}}"
            ret = [NSValue valueWithCGRect:CGRectFromString(value)];
            break;
            
        case kTCMappingClassTypeCGAffineTransform:
            // "{a, b, c, d, tx, ty}"
            ret = [NSValue valueWithCGAffineTransform:CGAffineTransformFromString(value)];
            break;
            
        case kTCMappingClassTypeUIEdgeInsets:
            // "{top, left, bottom, right}"
            ret = [NSValue valueWithUIEdgeInsets:UIEdgeInsetsFromString(value)];
            break;
            
        case kTCMappingClassTypeUIOffset:
            // "{horizontal, vertical}"
            ret = [NSValue valueWithUIOffset:UIOffsetFromString(value)];
            break;
            
        default:
            ret = value;
            break;
    }
    
    NSCAssert(nil != ret, @"property type %@ doesn't match value type %@", meta->_typeName, NSStringFromClass(value.class));
    return ret;
}

NS_INLINE id valueForBaseTypeOfPropertyName(NSString *propertyName, id value, __unsafe_unretained TCMappingMeta *meta, NSDictionary *typeMappingDic, __unsafe_unretained Class curClass)
{
    id ret = nil;
    
    if (meta->_isObj) {
        __unsafe_unretained Class klass = meta->_typeClass;
        
        switch (meta->_classType) {
            case kTCMappingClassTypeNSString: { // NSString <- non NSString
                BOOL isStringValue = [value isKindOfClass:NSString.class];
                NSCAssert(isStringValue, @"property %@ type %@ doesn't match value type %@", propertyName, NSStringFromClass(klass), NSStringFromClass([value class]));
                if (!isStringValue) {
                    ret = [klass stringWithFormat:@"%@", value];
                } else {
                    if (klass != [value class]) {
                        ret = [klass stringWithString:value];
                    } else {
                        ret = value;
                    }
                }
            
                break;
            }
                
            case kTCMappingClassTypeNSNumber: { // NSNumber <- NSString
                if ([value isKindOfClass:NSNumber.class]) {
                    ret = value;
                } else {
                    NSCAssert(false, @"property %@ type %@ doesn't match value type %@", propertyName, NSStringFromClass(klass), NSStringFromClass([value class]));
                    if ([value isKindOfClass:NSString.class]) {
                        ret = [tc_mapping_number_fmter() numberFromString:(NSString *)value];
                    }
                }
                
                break;
            }
                
            case kTCMappingClassTypeNSDate: { // NSDate <- NSString
                if ([value isKindOfClass:NSString.class]) { // NSDate <- NSString
                    NSString *fmtStr = typeMappingDic[propertyName];
                    if (nil != fmtStr && (id)kCFNull != fmtStr && [fmtStr isKindOfClass:NSString.class] && fmtStr.length > 0) {
                        NSDateFormatter *fmt = tc_mapping_date_write_fmter();
                        fmt.timeZone = [curClass tc_dateTimeZone];
                        fmt.dateFormat = fmtStr;
                        ret = [fmt dateFromString:value];
                    }
                } else if ([value isKindOfClass:NSNumber.class]) { // NSDate <- timestamp
                    BOOL ignore = NO;
                    NSTimeInterval timestamp = [curClass tc_timestampToSecondSince1970:((NSNumber *)value).doubleValue ignoreReturn:&ignore];
                    if (!ignore) {
                        ret = [NSDate dateWithTimeIntervalSince1970:timestamp];
                    }
                } else if ([value isKindOfClass:NSDate.class]) {
                    ret = value;
                }
                
                break;
            }
                
            case kTCMappingClassTypeNSURL: { // NSURL <- NSString
                if ([value isKindOfClass:NSString.class]) {
                    ret = [klass URLWithString:value];
                } else if ([ret isKindOfClass:NSURL.class]) {
                    ret = value;
                }
                
                break;
            }
                
            case kTCMappingClassTypeNSData: { // NSData <- Base64 NSString
                if ([value isKindOfClass:NSString.class]) {
                    ret = [[klass alloc] initWithBase64EncodedString:value options:0];
                } else if ([value isKindOfClass:NSData.class]) {
                    if (klass != [value class]) {
                        ret = [klass dataWithData:value];
                    } else {
                        ret = value;
                    }
                }
                
                break;
            }
                
            case kTCMappingClassTypeNSValue: {
                if ([value isMemberOfClass:klass]) {
                    ret = value;
                } else {
                    NSCAssert(false, @"property %@ type %@ doesn't match value type %@", propertyName, NSStringFromClass(klass), NSStringFromClass(((NSObject *)ret).class));
                }
                
                break;
            }
                
            default:
                ret = value;
                break;
        }
    } else if ([meta->_typeName hasPrefix:@"{"]) { // NSValue <- NSString
        if ([value isKindOfClass:NSString.class]) {
            ret = mappingNSValueWithString(value ,meta);
        }
    } else {
        ret = value;
    }
    
    return ret;
}


#pragma mark - TCMapping

static id tc_mappingWithDictionary(NSDictionary *dataDic,
                                   NSDictionary<NSString *, NSString *> *inputNameDic,
                                   id<TCMappingPersistentContext> context,
                                   id target,
                                   Class curClass,
                                   BOOL useInputNameDicOnly);

static NSArray *mappingArray(NSArray *value, Class klass, id<TCMappingPersistentContext> context)
{
    NSMutableArray *arry = [NSMutableArray array];
    
    for (NSDictionary *dic in value) {
        if ([dic isKindOfClass:NSDictionary.class]) {
            id obj = tc_mappingWithDictionary(dic, nil, context, nil, klass, NO);
            if (nil != obj) {
                [arry addObject:obj];
            }
        } else {
            if ([dic isKindOfClass:klass]) {
                [arry addObject:dic];
            }
        }
    }
    
    return arry.count > 0 ? arry.copy : nil;
}

static id databaseInstanceWithValue(NSDictionary *value, NSDictionary *nameDic, id<TCMappingPersistentContext> context, Class klass)
{
    // fill in primary keys
    NSMutableDictionary *primaryKey = [klass tc_propertyForPrimaryKey].mutableCopy;
    for (NSString *pKey in primaryKey) {
        id tmpValue = value[nameDic[pKey]];
        if (nil != tmpValue && tmpValue != (id)kCFNull) {
            primaryKey[pKey] = tmpValue;
        }
        
        if (primaryKey[pKey] == (id)kCFNull) {
            primaryKey = nil;
            break;
        }
    }
    
    return [context instanceForPrimaryKey:primaryKey class:klass];
}


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
    return [self tc_mappingWithArray:arry context:nil];
}

+ (NSMutableArray *)tc_mappingWithArray:(NSArray *)arry context:(id<TCMappingPersistentContext>)context
{
    if (nil == arry || ![arry isKindOfClass:NSArray.class] || arry.count < 1) {
        return nil;
    }
    
    NSMutableArray *outArry = [NSMutableArray array];
    for (NSDictionary *dic in arry) {
        @autoreleasepool {
            id obj = tc_mappingWithDictionary(dic, nil, context, nil, self, NO);
            if (nil != obj) {
                [outArry addObject:obj];
            }
        }
    }
    
    return outArry.count > 0 ? outArry : nil;
}

+ (instancetype)tc_mappingWithDictionary:(NSDictionary *)dic
{
    return tc_mappingWithDictionary(dic, nil, nil, nil, self, NO);
}

+ (instancetype)tc_mappingWithDictionary:(NSDictionary *)dic context:(id<TCMappingPersistentContext>)context
{
    return tc_mappingWithDictionary(dic, nil, context, nil, self, NO);
}

- (void)tc_mappingWithDictionary:(NSDictionary *)dic
{
    [self tc_mappingWithDictionary:dic propertyNameMapping:nil];
}

- (void)tc_mappingWithDictionary:(NSDictionary *)dic propertyNameMapping:(NSDictionary *)extraNameDic
{
    tc_mappingWithDictionary(dic, extraNameDic, nil, self, self.class, NO);
}


#pragma mark - async

NS_INLINE dispatch_queue_t tc_mappingQueue(void)
{
    return dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
}


+ (void)tc_asyncMappingWithArray:(NSArray *)arry finish:(void(^)(NSMutableArray *dataList))finish
{
    [self tc_asyncMappingWithArray:arry context:nil inQueue:nil finish:finish];
}

+ (void)tc_asyncMappingWithDictionary:(NSDictionary *)dic finish:(void(^)(id data))finish
{
    [self tc_asyncMappingWithDictionary:dic context:nil inQueue:nil finish:finish];
}

+ (void)tc_asyncMappingWithArray:(NSArray *)arry inQueue:(dispatch_queue_t)queue finish:(void(^)(NSMutableArray *dataList))finish
{
    [self tc_asyncMappingWithArray:arry context:nil inQueue:queue finish:finish];
}

+ (void)tc_asyncMappingWithDictionary:(NSDictionary *)dic inQueue:(dispatch_queue_t)queue finish:(void(^)(id data))finish
{
    [self tc_asyncMappingWithDictionary:dic context:nil inQueue:queue finish:finish];
}


+ (void)tc_asyncMappingWithDictionary:(NSDictionary *)dic context:(id<TCMappingPersistentContext>)context inQueue:(dispatch_queue_t)queue finish:(void(^)(id data))finish
{
    if (nil == finish) {
        return;
    }
    
    dispatch_async(queue ?: tc_mappingQueue(), ^{
        @autoreleasepool {
            id data = [self tc_mappingWithDictionary:dic context:context];
            dispatch_async(dispatch_get_main_queue(), ^{
                finish(data);
            });
        }
    });
}

+ (void)tc_asyncMappingWithArray:(NSArray *)arry context:(id<TCMappingPersistentContext>)context inQueue:(dispatch_queue_t)queue finish:(void(^)(NSMutableArray *dataList))finish
{
    if (nil == finish) {
        return;
    }
    
    dispatch_async(queue ?: tc_mappingQueue(), ^{
        @autoreleasepool {
            NSMutableArray *dataList = [self tc_mappingWithArray:arry context:context];
            dispatch_async(dispatch_get_main_queue(), ^{
                finish(dataList);
            });
        }
    });
}

@end

static id tc_mappingWithDictionary(NSDictionary *dataDic,
                                   NSDictionary<NSString *, NSString *> *inputNameDic,
                                   id<TCMappingPersistentContext> context,
                                   id target,
                                   Class curClass,
                                   BOOL useInputNameDicOnly)
{
    if (nil == dataDic || ![dataDic isKindOfClass:NSDictionary.class] || dataDic.count < 1) {
        return nil;
    }
    
    NSDictionary *typeDic = [curClass tc_propertyTypeFormat];
    NSDictionary *nameDic = inputNameDic;
    __unsafe_unretained NSDictionary<NSString *, TCMappingMeta *> *metaDic = tc_propertiesUntilRootClass(curClass);
    
    if (!useInputNameDicOnly || inputNameDic.count < 1) {
        NSDictionary *inputMappingDic = inputNameDic;
        if (inputMappingDic.count < 1) {
            inputMappingDic = [curClass tc_propertyNameMapping];
        }
        nameDic = nameMappingDicFor(inputMappingDic, metaDic.allKeys);
    }
    
    
    NSObject *obj = target;
    BOOL ignoreNSNull = [curClass tc_mappingIgnoreNSNull];
    
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
                        NSDictionary *dicValueNameDic = nameMappingDicFor([dicValueClass tc_propertyNameMapping], tc_propertiesUntilRootClass(dicValueClass).allKeys);
                        for (id dicKey in valueDataDic) {
                            id tmpValue = tc_mappingWithDictionary(valueDataDic[dicKey], dicValueNameDic, context, nil, dicValueClass, YES);
                            if (nil != tmpValue) {
                                tmpDic[dicKey] = tmpValue;
                            }
                        }
                        
                        value = tmpDic.count > 0 ? [klass dictionaryWithDictionary:tmpDic] : nil;
                    } else if (valueDataDic.class != klass) {
                        value = [klass dictionaryWithDictionary:valueDataDic];
                    }
                } else {
                    value = tc_mappingWithDictionary(valueDataDic, nil, context, nil == obj ? nil : [obj valueForKey:propertyName], klass, NO);
                }
            } else {
                value = nil;
            }
        } else if ([value isKindOfClass:NSArray.class]) {
            __unsafe_unretained NSArray *valueDataArry = (NSArray *)value;
            if (valueDataArry.count > 0) {
                __unsafe_unretained TCMappingMeta *meta = metaDic[propertyName];
                if (Nil == meta->_typeClass || (meta->_classType != kTCMappingClassTypeNSArray && meta->_classType != kTCMappingClassTypeNSSet)) {
                    value = nil;
                } else {
                    __unsafe_unretained Class arrayItemType = classForType(typeDic[propertyName]);
                    if (Nil != arrayItemType) {
                        value = mappingArray(valueDataArry, arrayItemType, context);
                    }
                    
                    if (nil != value) {
                        if (meta->_classType == kTCMappingClassTypeNSArray) {
                            if (![value isKindOfClass:meta->_typeClass]) {
                                value = [meta->_typeClass arrayWithArray:(NSArray *)value];
                            }
                        } else { // NSSet
                            value = [meta->_typeClass setWithArray:(NSArray *)value];
                        }
                    }
                }
            }
        } else if (value != (id)kCFNull) {
            value = valueForBaseTypeOfPropertyName(propertyName, value, metaDic[propertyName], typeDic, curClass);
        }
        
        if (nil == value) {
            continue;
        } else if (value == (id)kCFNull) {
            value = nil;
        }
        
        if (nil == obj) {
            if (nil == context || ![context respondsToSelector:@selector(instanceForPrimaryKey:class:)]) {
                obj = [[curClass alloc] init];
            } else {
                obj = databaseInstanceWithValue(dataDic, nameDic, context, curClass);
            }
        }
        
        [obj setValue:value forKey:propertyName];
    }
    
    return obj.tc_mappingValidate ? obj : nil;
}


#pragma mark - NSDictionary+TCMapping

@implementation NSDictionary (TCMapping)

- (id)valueForKeyExceptNull:(NSString *)key
{
    NSParameterAssert(key);
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
