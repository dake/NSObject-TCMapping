//
//  NSObject+TCMapping.m
//  TCKit
//
//  Created by dake on 13-12-29.
//  Copyright (c) 2013年 dake. All rights reserved.
//

#import "NSObject+TCMapping.h"
#import <objc/runtime.h>
#import <objc/message.h>

#import <CoreGraphics/CGGeometry.h>
#import <UIKit/UIGeometry.h>

#import "TCMappingMeta.h"
#import "UIColor+TCUtilities.h"


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

NS_INLINE Class classForType(id type, id value)
{
    if (nil == type) {
        return Nil;
    }
    
    if (class_isMetaClass(object_getClass(type))) {
        return type;
    } else if ([type isKindOfClass:NSString.class]) {
        return NSClassFromString(type);
    } else if ([TCMappingMeta isBlock:type]) {
        TCTypeMappingBlock block = type;
        return block(value);
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

NS_INLINE NSValue *mappingNSValueWithString(NSString *value, __unsafe_unretained TCMappingMeta *meta)
{
    id ret = nil;
    
    switch (tc_typeForInfo(meta->_info)) {
        case kTCEncodingTypeCGPoint:
            // "{x,y}"
            ret = [NSValue valueWithCGPoint:CGPointFromString(value)];
            break;
            
        case kTCEncodingTypeCGVector:
            // "{dx, dy}"
            ret = [NSValue valueWithCGVector:CGVectorFromString(value)];
            break;
            
        case kTCEncodingTypeCGSize:
            // "{w, h}"
            ret = [NSValue valueWithCGSize:CGSizeFromString(value)];
            break;
            
        case kTCEncodingTypeCGRect:
            // "{{x,y},{w, h}}"
            ret = [NSValue valueWithCGRect:CGRectFromString(value)];
            break;
            
        case kTCEncodingTypeCGAffineTransform:
            // "{a, b, c, d, tx, ty}"
            ret = [NSValue valueWithCGAffineTransform:CGAffineTransformFromString(value)];
            break;
            
        case kTCEncodingTypeUIEdgeInsets:
            // "{top, left, bottom, right}"
            ret = [NSValue valueWithUIEdgeInsets:UIEdgeInsetsFromString(value)];
            break;
            
        case kTCEncodingTypeUIOffset:
            // "{horizontal, vertical}"
            ret = [NSValue valueWithUIOffset:UIOffsetFromString(value)];
            break;
            
        case kTCEncodingTypeNSRange:
            // "{location, length}"
            ret = [NSValue valueWithRange:NSRangeFromString(value)];
            break;
            
        default:
            break;
    }
    
    NSCAssert(nil != ret, @"property type %@ doesn't match value type %@", meta->_typeName, NSStringFromClass(value.class));
    return ret;
}

//  UIColor <- {r:0~1, g:0~1, b:0~1, a:0~1}, {rgb:0x322834}, {rgba:0x12345678}, {argb:0x12345678}
NS_INLINE UIColor *valueForUIColor(NSDictionary *dic, Class klass)
{
    static NSString *const rgbKey = @"rgb";
    static NSString *const rgbaKey = @"rgba";
    static NSString *const argbKey = @"argb";
    
    static NSString *const rKey = @"r";
    static NSString *const gKey = @"g";
    static NSString *const bKey = @"b";
    static NSString *const aKey = @"a";
    
    NSArray *keys = dic.allKeys;
    
    if ([keys containsObject:rgbKey]) {
        NSNumber *rgb = [dic valueForKeyExceptNull:rgbKey];
        return nil != rgb ? RGBHex(rgb.unsignedIntValue) : nil;
        
    } else if ([keys containsObject:rgbaKey]) {
        NSNumber *rgba = [dic valueForKeyExceptNull:rgbaKey];
        return nil != rgba ? RGBHex(rgba.unsignedIntValue) : nil;
        
    } else if ([keys containsObject:argbKey]) {
        NSNumber *argb = [dic valueForKeyExceptNull:argbKey];
        return nil != argb ? RGBHex(argb.unsignedIntValue) : nil;
        
    } else {
        NSNumber *r = [dic valueForKeyExceptNull:rKey];
        NSNumber *g = [dic valueForKeyExceptNull:gKey];
        NSNumber *b = [dic valueForKeyExceptNull:bKey];
        NSNumber *a = [dic valueForKeyExceptNull:aKey];
        
        if (nil != r ||
            nil != g ||
            nil != b ||
            nil != a) {
            
            return [UIColor colorWithRed:r.doubleValue green:g.doubleValue blue:b.doubleValue alpha:nil != a ? a.doubleValue : 1.0f];
        }
    }
    
    return nil;
}

NS_INLINE id valueForBaseTypeOfProperty(id value, TCMappingMeta *meta, TCMappingOption *option)
{
    id ret = nil;
    
    TCEncodingType type = tc_typeForInfo(meta->_info);
    if (tc_isObjForInfo(meta->_info)) {
        __unsafe_unretained Class klass = meta->_typeClass;
        
        switch (type) {
            case kTCEncodingTypeNSString: { // NSString <- non NSString
                if (!option.ignoreTypeConsistency) {
                    NSCAssert([value isKindOfClass:NSString.class], @"property %@ type %@ doesn't match value type %@", meta->_propertyName, meta->_typeName, NSStringFromClass([value class]));
                }
                if (![value isKindOfClass:NSString.class]) {
                    ret = [klass stringWithFormat:@"%@", value];
                } else {
                    if ([value isKindOfClass:klass]) {
                        ret = value;
                    } else {
                        ret = [klass stringWithString:value];
                    }
                }
            
                break;
            }
                
            case kTCEncodingTypeNSDecimalNumber:
            case kTCEncodingTypeNSNumber: { // NSNumber <- NSString
                if ([value isKindOfClass:NSNumber.class]) {
                    if (type == kTCEncodingTypeNSDecimalNumber) {
                        if ([value isKindOfClass:klass]) {
                            ret = value;
                        } else {
                            ret = [klass decimalNumberWithDecimal:[((NSNumber *)value) decimalValue]];
                        }
                    } else if ([value isKindOfClass:klass]) {
                        ret = value;
                    }
                } else {
                    if (!option.ignoreTypeConsistency) {
                        NSCAssert(false, @"property %@ type %@ doesn't match value type %@", meta->_propertyName, meta->_typeName, NSStringFromClass([value class]));
                    }
                    if ([value isKindOfClass:NSString.class] && ((NSString *)value).length > 0) {
                        if (type == kTCEncodingTypeNSNumber) {
                            ret = [tc_mapping_number_fmter() numberFromString:(NSString *)value];
                        } else {
                            ret = [NSDecimalNumber decimalNumberWithString:value];
                        }
                    }
                }
                
                break;
            }
                
            case kTCEncodingTypeNSDate: { // NSDate <- NSString
                if ([value isKindOfClass:NSString.class] && ((NSString *)value).length > 0) { // NSDate <- NSString
                    NSString *fmtStr = (NSString *)option.typeMapping[meta->_propertyName];
                    if (nil != fmtStr && (id)kCFNull != fmtStr && [fmtStr isKindOfClass:NSString.class] && fmtStr.length > 0) {
                        NSDateFormatter *fmt = tc_mapping_date_write_fmter();
                        fmt.dateFormat = fmtStr;
                        if (nil != option.setUpDateFormatter) {
                            option.setUpDateFormatter(NSSelectorFromString(meta->_propertyName), fmt);
                        }
                        
                        ret = [fmt dateFromString:value];
                        fmt.timeZone = nil;
                        fmt.dateFormat = nil;
                    }
                } else if ([value isKindOfClass:NSNumber.class]) { // NSDate <- timestamp
                    NSTimeInterval timestamp = ((NSNumber *)value).doubleValue;
                    BOOL ignore = timestamp <= 0;
                    if (!ignore && nil != option.secondSince1970) {
                        timestamp = option.secondSince1970(NSSelectorFromString(meta->_propertyName), timestamp, &ignore);
                    }
                    if (!ignore) {
                        ret = [klass dateWithTimeIntervalSince1970:timestamp];
                    }
                } else if ([value isKindOfClass:klass]) {
                    ret = value;
                }
                
                break;
            }
                
            case kTCEncodingTypeNSURL: { // NSURL <- NSString
                if ([value isKindOfClass:NSString.class]) {
                    if (((NSString *)value).length > 0) {
                        ret = [klass URLWithString:[(NSString *)value stringByReplacingOccurrencesOfString:@"\x20" withString:@""]];
                        NSCParameterAssert(ret);
                    }
                } else if ([value isKindOfClass:NSURL.class]) {
                    ret = value;
                }
                
                break;
            }
                
            case kTCEncodingTypeNSData: { // NSData <- Base64 NSString
                if ([value isKindOfClass:NSString.class]) {
                    if (((NSString *)value).length > 0) {
                        ret = [[klass alloc] initWithBase64EncodedString:value options:NSDataBase64DecodingIgnoreUnknownCharacters];
                    }
                } else if ([value isKindOfClass:NSData.class]) {
                    if ([value isKindOfClass:klass]) {
                        ret = value;
                    } else {
                        ret = [klass dataWithData:value];
                    }
                }
                
                break;
            }
                
            case kTCEncodingTypeNSValue: {
                if ([value isKindOfClass:klass] || tc_isTypeNeedSerialization(type)) {
                    ret = value;
                }

                break;
            }
                
            case kTCEncodingTypeNSAttributedString: {
                if ([value isKindOfClass:klass]) {
                    ret = value;
                } else if ([value isKindOfClass:NSString.class] && ((NSString *)value).length > 0) {
                    ret = [[klass alloc] initWithString:value];
                }
                
                NSCAssert(nil != ret, @"property %@ type %@ doesn't match value type %@", meta->_propertyName, meta->_typeName, NSStringFromClass([value class]));
                break;
            }
                
            case kTCEncodingTypeBlock: {
                if ([value isKindOfClass:meta->_typeClass]) {
                    ret = value;
                }
                
                NSCAssert(nil != ret, @"property %@ type %@ doesn't match value type %@", meta->_propertyName, meta->_typeName, NSStringFromClass([value class]));
                break;
            }
                
            case kTCEncodingTypeUIColor: {
                if ([value isKindOfClass:meta->_typeClass]) {
                    ret = value;
                } else if ([value isKindOfClass:NSString.class]) { // "0xff65ce00" or "#0xff65ce00"
                    NSString *str = ((NSString *)value).lowercaseString;
                    if ([str hasPrefix:@"#"]) {
                        str = [str substringFromIndex:1];
                    }
                    
                    if ([str hasPrefix:@"0x"]) {
                        str = [str substringFromIndex:2];
                    }
                    
                    NSUInteger len = str.length;
                    if (len == 6) {
                        ret = [UIColor colorWithRGBHexString:(NSString *)value];
                        
                    } else if (len == 8) {
                        ret = [UIColor colorWithARGBHexString:(NSString *)value];
                    }
                } else if ([value isKindOfClass:NSNumber.class]) {
                    uint32_t hex = ((NSNumber *)value).unsignedIntValue;
                    if (hex < 0x01000000) { // RGB or clear
                        ret = [UIColor colorWithRGBHex:hex];
                    } else { // ARGB
                        ret = [UIColor colorWithARGBHex:hex];
                    }
                }
                break;
            }
                
            default:
                ret = value;
                break;
        }
    
    } else if (tc_isStructForInfo(meta->_info)) { // NSValue <- NSString
        NSValue *tmpValue = nil;
        if ([value isKindOfClass:NSValue.class]) {
            tmpValue = value;
        } else if (type != kTCEncodingTypeCommonStruct && type != kTCEncodingTypeBitStruct) {
            if ([value isKindOfClass:NSString.class] && ((NSString *)value).length > 0) {
                tmpValue = mappingNSValueWithString(value ,meta);
            }
        }
        
        if (nil != tmpValue && strcmp(tmpValue.objCType, meta->_typeName.UTF8String) == 0) {
            ret = tmpValue;
        }
        
        if (nil == ret) {
            ret = value;
        }
    } else {
        ret = value;
    }
    
    return ret;
}


#pragma mark - TCMapping

static id tc_mappingWithDictionary(NSDictionary *dataDic,
                                   TCMappingOption *opt,
                                   id<TCMappingPersistentContext> context,
                                   id target,
                                   Class curClass);


static NSArray *mappingArray(NSArray *value, Class arryKlass, id<TCMappingPersistentContext> context, NSString *property, TCMappingOption *option, TCTypeMappingBlock typeBlock)
{
    NSMutableArray *arry = NSMutableArray.array;
    TCMappingMeta *meta = nil;
    for (NSDictionary *dic in value) {
        Class klass = arryKlass;
        if (nil != typeBlock) {
            klass = typeBlock(dic);
        }
        
        if (Nil == klass) {
            continue;
        }
        
        if ([dic isKindOfClass:klass]) {
            [arry addObject:dic];
            
        } else if ([dic isKindOfClass:NSDictionary.class]) {
            
            id obj = tc_mappingWithDictionary(dic, nil, context, nil, klass);
            if (nil != obj) {
                [arry addObject:obj];
            }
        } else {
            if (nil == meta) {
                meta = [TCMappingMeta metaForNSClass:klass];
                if (nil == meta) {
                    break;
                }
                
                meta->_propertyName =  property;
            }

            id obj = valueForBaseTypeOfProperty(dic, meta, option);
            if (nil != obj) {
                [arry addObject:obj];
            }
        }
    }
    
    return (value.count > 0 && arry.count < 1) ? nil : arry.copy;
}

static id databaseInstanceWithValue(NSDictionary *value, NSDictionary *primaryKey, NSDictionary *nameDic, id<TCMappingPersistentContext> context, Class klass)
{
    // fill in primary keys
    NSMutableDictionary *pKeys = primaryKey.mutableCopy;
    for (NSString *pKey in pKeys) {
        id tmpValue = value[nameDic[pKey]];
        if (nil != tmpValue && tmpValue != (id)kCFNull) {
            pKeys[pKey] = tmpValue;
        }
        
        if (pKeys[pKey] == (id)kCFNull) {
            pKeys = nil;
            break;
        }
    }
    
    return [context instanceForPrimaryKey:pKeys class:klass];
}


@implementation NSObject (TCMapping)

+ (TCMappingOption *)tc_mappingOption
{
    return nil;
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
            id obj = tc_mappingWithDictionary(dic, nil, context, nil, self);
            if (nil != obj) {
                [outArry addObject:obj];
            }
        }
    }
    
    return outArry.count > 0 ? outArry : nil;
}

+ (instancetype)tc_mappingWithDictionary:(NSDictionary *)dic
{
    return tc_mappingWithDictionary(dic, nil, nil, nil, self);
}

+ (instancetype)tc_mappingWithDictionary:(NSDictionary<NSString *, id> *)dic option:(TCMappingOption *)option
{
    return tc_mappingWithDictionary(dic, option, nil, nil, self);
}

+ (instancetype)tc_mappingWithDictionary:(NSDictionary *)dic context:(id<TCMappingPersistentContext>)context
{
    return tc_mappingWithDictionary(dic, nil, context, nil, self);
}

- (void)tc_mappingWithDictionary:(NSDictionary *)dic
{
    tc_mappingWithDictionary(dic, nil, nil, self, self.class);
}

- (void)tc_mappingWithDictionary:(NSDictionary<NSString *, id> *)dic option:(TCMappingOption *)option
{
    tc_mappingWithDictionary(dic, option, nil, self, self.class);
}


#pragma mark - JSON file

+ (instancetype)tc_mappingWithDictionaryOfJSONFile:(NSString *)path error:(NSError **)error
{
    NSParameterAssert(path);
    
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (nil == data) {
        return nil;
    }
    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:data
                                                        options:kNilOptions
                                                          error:error];
    
    return [self tc_mappingWithDictionary:dic];
}

+ (NSMutableArray *)tc_mappingWithArrayOfJSONFile:(NSString *)path error:(NSError **)error
{
    NSParameterAssert(path);
    
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (nil == data) {
        return nil;
    }
    NSArray *arry = [NSJSONSerialization JSONObjectWithData:data
                                                    options:kNilOptions
                                                      error:error];
    
    return [self tc_mappingWithArray:arry];
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
                                   TCMappingOption *opt,
                                   id<TCMappingPersistentContext> context,
                                   id target,
                                   Class curClass)
{
    if (nil == dataDic || ![dataDic isKindOfClass:NSDictionary.class] || dataDic.count < 1) {
        return nil;
    }
    
    
    NSDictionary *nameDic = opt.nameMapping;
    __unsafe_unretained NSDictionary<NSString *, TCMappingMeta *> *metaDic = tc_propertiesUntilRootClass(curClass);
    
    if (nameDic.count < 1) {
        NSDictionary *tmpDic = nameDic;
        if (tmpDic.count < 1) {
            tmpDic = [curClass tc_mappingOption].nameMapping;
        }
        nameDic = nameMappingDicFor(tmpDic, metaDic.allKeys);
    } else {
        nameDic = nameMappingDicFor(nameDic, metaDic.allKeys);
    }
    
    NSObject *obj = target;
    TCMappingOption *option = opt ?: [curClass tc_mappingOption];
    BOOL isNSNullValid = option.shouldMappingNSNull;
    NSDictionary *typeDic = option.typeMapping;

    
    for (__unsafe_unretained NSString *property in nameDic) {
        if (nil == property || (id)kCFNull == property || (id)kCFNull == nameDic[property]) {
            continue;
        }
        
        __unsafe_unretained TCMappingMeta *meta = metaDic[property];
        if (tc_ignoreMappingForInfo(meta->_info) || NULL == meta->_setter) {
            continue;
        }
        
        NSObject *value = dataDic[nameDic[property]];
        if (nil == value) {
            value = dataDic[property];
        }
        
        if (nil == value || ((id)kCFNull == value && !isNSNullValid)) {
            continue;
        }
        
        
        TCEncodingType type = tc_typeForInfo(meta->_info);
        BOOL emptyDictionaryToNSNull = option.emptyDictionaryToNSNull;
        
        if ([value isKindOfClass:NSDictionary.class]) {
            __unsafe_unretained NSDictionary *valueDic = (NSDictionary *)value;
            
            if (valueDic.count > 0) {
                if (type == kTCEncodingTypeNSDictionary) {
                    __unsafe_unretained Class dicItemClass = classForType(typeDic[property], value);
                    if (Nil != dicItemClass) {
                        NSMutableDictionary *tmpDic = NSMutableDictionary.dictionary;
                        for (id dicKey in valueDic) {
                            id tmpValue = tc_mappingWithDictionary(valueDic[dicKey], [dicItemClass tc_mappingOption], context, nil, dicItemClass);
                            if (nil != tmpValue) {
                                tmpDic[dicKey] = tmpValue;
                            }
                        }
                        
                        value = tmpDic.count > 0 ? [meta->_typeClass dictionaryWithDictionary:tmpDic] : nil;
                        
                    } else if (valueDic.class != meta->_typeClass) {
                        value = [meta->_typeClass dictionaryWithDictionary:valueDic];
                    }
                    
                } else {
                    __unsafe_unretained Class klass = meta->_typeClass;
                    if (Nil == klass) {
                        klass = classForType(typeDic[property], value);
                    }
                    
                    if ([klass isSubclassOfClass:UIColor.class]) {
                        value = valueForUIColor((NSDictionary *)value, klass);
                        
                    } else {
                        value = tc_mappingWithDictionary(valueDic, nil, context, (nil == obj ? nil : [obj valueForKey:property]), klass);
                    }
                }
                
            } else {
                value = emptyDictionaryToNSNull ? (id)kCFNull : nil;
            }
            
        } else if ([value isKindOfClass:NSArray.class] || [value isKindOfClass:NSSet.class]) {
            
            NSArray *valueArry = [value isKindOfClass:NSArray.class] ? (NSArray *)value : ((NSSet *)value).allObjects;
            if (valueArry.count > 0) {
                if (Nil == meta->_typeClass || (type != kTCEncodingTypeNSArray && type != kTCEncodingTypeNSSet)) {
                    value = nil;
                    
                } else {
                    TCTypeMappingBlock typeBlock = nil;
                    __unsafe_unretained Class arryItemType = Nil;
                    
                    id properyType = typeDic[property];
                    if (nil != properyType) {
                        if (![TCMappingMeta isBlock:properyType]) {
                            arryItemType = classForType(properyType, nil);
                        } else {
                            typeBlock = properyType;
                        }
                    }
                    
                    if (Nil != arryItemType || nil != typeBlock) {
                        value = mappingArray(valueArry, arryItemType, context, property, option, typeBlock);
                    }
                    
                    if (nil != value) {
                        if (type == kTCEncodingTypeNSArray) {
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
            value = valueForBaseTypeOfProperty(value, meta, option);
        }
        
        if (nil == value) {
            continue;
        }
        
        if (value == (id)kCFNull && !isNSNullValid) {
            value = nil;
        }
        
        if (nil == obj) {
            if (nil == context || ![context respondsToSelector:@selector(instanceForPrimaryKey:class:)]) {
                obj = [[curClass alloc] init];
            } else {
                obj = databaseInstanceWithValue(dataDic, option.primaryKey, nameDic, context, curClass);
            }
        }
        
        [obj setValue:value forKey:property meta:meta forPersistent:NO];
    }
    
    if (nil == option.mappingValidate) {
        return obj;
    }
    
    return option.mappingValidate(obj) ? obj : nil;
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
