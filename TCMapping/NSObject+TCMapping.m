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


typedef NS_ENUM (NSUInteger, TCMappingClassType) {
    kTCMappingClassTypeUnknown = 0,
    kTCMappingClassTypeNSString,
    kTCMappingClassTypeNSValue,
    kTCMappingClassTypeNSNumber,
    kTCMappingClassTypeNSDate,
    kTCMappingClassTypeNSURL,
    kTCMappingClassTypeNSArray,
    kTCMappingClassTypeNSDictionary,
    
    kTCMappingClassTypeId, // id type
    kTCMappingClassTypeBaseScalar, // int, double, etc...
    
    kTCMappingClassTypeCGPoint,
    kTCMappingClassTypeCGVector,
    kTCMappingClassTypeCGSize,
    kTCMappingClassTypeCGRect,
    kTCMappingClassTypeCGAffineTransform,
    kTCMappingClassTypeUIEdgeInsets,
    kTCMappingClassTypeUIOffset,
};


@interface TCMappingMeta : NSObject
{
@public
    BOOL _isObj;
    NSString *_typeName;
    Class _typeClass;
    TCMappingClassType _classType;
}

@end

@implementation TCMappingMeta

@end


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

NS_INLINE TCMappingClassType classTypeForStructType(const char *typeNameString)
{
    if (strcmp(typeNameString, @encode(CGPoint)) == 0) {
        return kTCMappingClassTypeCGPoint;
    } else if (strcmp(typeNameString, @encode(CGVector)) == 0) {
        return kTCMappingClassTypeCGVector;
    } else if (strcmp(typeNameString, @encode(CGSize)) == 0) {
        return kTCMappingClassTypeCGSize;
    } else if (strcmp(typeNameString, @encode(CGRect)) == 0) {
        return kTCMappingClassTypeCGRect;
    } else if (strcmp(typeNameString, @encode(CGAffineTransform)) == 0) {
        return kTCMappingClassTypeCGAffineTransform;
    } else if (strcmp(typeNameString, @encode(UIEdgeInsets)) == 0) {
        return kTCMappingClassTypeUIEdgeInsets;
    } else if (strcmp(typeNameString, @encode(UIOffset)) == 0) {
        return kTCMappingClassTypeUIOffset;
    } else {
        return kTCMappingClassTypeBaseScalar;
    }
}

static NSDictionary<NSString *, TCMappingMeta *> *readwritePropertyListUntilNSObjectFrom(Class klass)
{
    if (Nil == klass || klass == NSObject.class) {
        return nil;
    }
    
    static NSRecursiveLock *s_recursiveLock;
    static NSMutableDictionary<NSString *, NSMutableDictionary *> *s_writablePropertyByClass;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_writablePropertyByClass = [NSMutableDictionary dictionary];
        s_recursiveLock = [[NSRecursiveLock alloc] init];
    });
    
    NSString *key = NSStringFromClass(klass);
    
    [s_recursiveLock lock];
    NSMutableDictionary<NSString *, TCMappingMeta *> *propertyNames = s_writablePropertyByClass[key];
    if (nil != propertyNames) {
        [s_recursiveLock unlock];
        return propertyNames;
    }
    
    
    NSDictionary *nameMapping = [klass tc_propertyNameMapping];
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
        BOOL ignore = NULL == attributes;
        NSString *typeName = nil;
        TCMappingClassType classType = kTCMappingClassTypeUnknown;
        __unsafe_unretained Class typeClass = Nil;
        
        NSInteger j = 0;
        while (!ignore && j++ < 2 && (attribute = strsep(&state, ",")) != NULL) {
            switch (attribute[0]) {
                case 'T': { // type encoding
                    size_t len = strlen(attribute);
                    if (len >= 2 && attribute[0] == 'T' && attribute[1] == '@') { // [@(attribute) hasPrefix:@"T@"]
                        isObj = YES;
                        if (len == 2) {
                            typeName = @"@";
                            classType = kTCMappingClassTypeId;
                        } else {
                            attribute[len - 1] = '\0';
                            typeName = @((attribute + 3));
                            // "T@\"TestModel2<TCMappingIgnore><TCNSCodingIgnore>"
                            if (attribute[len - 2] == '>') {
                                NSRange range = [typeName rangeOfString:@"<"];
                                if (range.location != NSNotFound) {
                                    NSString *ignoreProtocol = [typeName substringFromIndex:range.location];
                                    if ([ignoreProtocol rangeOfString:NSStringFromProtocol(@protocol(TCMappingIgnore))].location != NSNotFound) {
                                        ignore = YES;
                                        break;
                                    }
                                    
                                    if (range.location != 0) {
                                        typeName = [typeName substringToIndex:range.location];
                                    } else {
                                        typeName = @"@";
                                        classType = kTCMappingClassTypeId;
                                    }
                                }
                            }
                            
                            if (kTCMappingClassTypeId != classType) {
                                typeClass = NSClassFromString(typeName);
                            }
                        }
                    } else {
                        isObj = NO;
                        if (len > 5 && attribute[1] == '{') { // CGRect. etc contains '{', filer out other scalar type
                            typeName = @((attribute + 1));
                            classType = classTypeForStructType(attribute + 1);
                            
                        } else {
                            classType = kTCMappingClassTypeBaseScalar;
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
        
        if (ignore || (isObj && classType != kTCMappingClassTypeId && Nil == typeClass)) {
            continue;
        }
        
        NSString *propertyName = [NSString stringWithUTF8String:property_getName(properties[i])];
        // TODO: custom set method
        if (nil != propertyName && nameMapping[propertyName] != (id)kCFNull) {
            
            TCMappingMeta *meta = [[TCMappingMeta alloc] init];
            meta->_typeName = typeName;
            meta->_isObj = isObj;
            meta->_typeClass = typeClass;
            meta->_classType = classType;
            
            if (Nil != typeClass) {
                if ([typeClass isSubclassOfClass:NSString.class]) {
                    meta->_classType = kTCMappingClassTypeNSString;
                } else if ([typeClass isSubclassOfClass:NSNumber.class]) {
                    meta->_classType = kTCMappingClassTypeNSNumber;
                } else if ([typeClass isSubclassOfClass:NSDictionary.class]) {
                    meta->_classType = kTCMappingClassTypeNSDictionary;
                } else if ([typeClass isSubclassOfClass:NSArray.class]) {
                    meta->_classType = kTCMappingClassTypeNSArray;
                } else if ([typeClass isSubclassOfClass:NSURL.class]) {
                    meta->_classType = kTCMappingClassTypeNSURL;
                } else if ([typeClass isSubclassOfClass:NSDate.class]) {
                    meta->_classType = kTCMappingClassTypeNSDate;
                } else if ([typeClass isSubclassOfClass:NSValue.class]) {
                    meta->_classType = kTCMappingClassTypeNSValue;
                }
            }
            
            propertyNames[propertyName] = meta;
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
    return [self tc_mappingWithDictionary:dic propertyMapping:nil context:nil targetBlock:nil useInputPropertyDicOnly:NO];
}

+ (instancetype)tc_mappingWithDictionary:(NSDictionary *)dic managerObjectContext:(NSManagedObjectContext *)context
{
    return [self tc_mappingWithDictionary:dic propertyMapping:nil context:context targetBlock:nil useInputPropertyDicOnly:NO];
}

+ (instancetype)tc_mappingWithDictionary:(NSDictionary *)dataDic
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
    
    NSDictionary *typeMappingDic = currentClass.tc_propertyTypeFormat;
    NSDictionary *nameMappingDic = inputPropertyDic;
    __unsafe_unretained NSDictionary<NSString *, TCMappingMeta *> *sysWritablePropertiesMeta = readwritePropertyListUntilNSObjectFrom(currentClass);
    
    if (!useInputPropertyDicOnly || inputPropertyDic.count < 1) {
        NSDictionary *inputMappingDic = inputPropertyDic;
        if (inputMappingDic.count < 1) {
            inputMappingDic = currentClass.tc_propertyNameMapping;
        }
        nameMappingDic = nameMappingDicFor(inputMappingDic, sysWritablePropertiesMeta.allKeys);
    }
    
    BOOL ignoreNSNull = currentClass.tc_mappingIgnoreNSNull;
    for (__unsafe_unretained NSString *propertyName in nameMappingDic) {
        if (nil == propertyName || (id)kCFNull == propertyName || (id)kCFNull == nameMappingDic[propertyName]) {
            continue;
        }
        
        NSObject *value = dataDic[nameMappingDic[propertyName]];
        if (nil == value) {
            value = dataDic[propertyName];
        }
        
        if (nil == value || ((id)kCFNull == value && ignoreNSNull)) {
            continue;
        }
        
        if ([value isKindOfClass:NSDictionary.class]) {
            __unsafe_unretained NSDictionary *valueDataDic = (NSDictionary *)value;
            if (valueDataDic.count > 0) {
                __unsafe_unretained TCMappingMeta *meta = sysWritablePropertiesMeta[propertyName];
                __unsafe_unretained Class klass = meta->_typeClass;
                if (Nil == klass) {
                    value = nil;
                } else if (meta->_classType == kTCMappingClassTypeNSDictionary) {
                    
                    __unsafe_unretained Class dicValueClass = classForType(typeMappingDic[propertyName]);
                    if (Nil != dicValueClass) {
                        NSMutableDictionary *tmpDic = [NSMutableDictionary dictionary];
                        NSDictionary *dicValueMappingDic = nameMappingDicFor(dicValueClass.tc_propertyNameMapping, readwritePropertyListUntilNSObjectFrom(dicValueClass).allKeys);
                        for (id dicKey in valueDataDic) {
                            id tmpValue = [dicValueClass tc_mappingWithDictionary:valueDataDic[dicKey] propertyMapping:dicValueMappingDic context:context targetBlock:nil useInputPropertyDicOnly:YES];
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
                    } useInputPropertyDicOnly:NO];
                }
            } else {
                value = nil;
            }
            
        } else if ([value isKindOfClass:NSArray.class]) {
            __unsafe_unretained NSArray *valueDataArry = (NSArray *)value;
            if (valueDataArry.count > 0) {
                
                __unsafe_unretained TCMappingMeta *meta = sysWritablePropertiesMeta[propertyName];
                if (Nil == meta->_typeClass || meta->_classType != kTCMappingClassTypeNSArray) {
                    value = nil;
                } else {
                    __unsafe_unretained Class arrayItemType = classForType(typeMappingDic[propertyName]);
                    if (Nil != arrayItemType) {
                        value = [arrayItemType mappingArray:valueDataArry withContext:context];
                    }
                    
                    if (nil != value && ![value isKindOfClass:meta->_typeClass]) {
                        value = [meta->_typeClass arrayWithArray:(NSArray *)value];
                    }
                }
            }
        } else if (value != (id)kCFNull) {
            value = valueForBaseTypeOfPropertyName(propertyName, value, sysWritablePropertiesMeta[propertyName], typeMappingDic, currentClass);
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
                obj = [currentClass coreDataInstanceWithValue:dataDic withNameMappingDic:nameMappingDic withContext:context];
            }
        }
        
        [obj setValue:value forKey:propertyName];
    }
    
    return obj.tc_mappingValidate ? obj : nil;
}

+ (instancetype)coreDataInstanceWithValue:(NSDictionary *)value withNameMappingDic:(NSDictionary *)nameMappingDic withContext:(NSManagedObjectContext *)context
{
    // fill up primary keys
    NSMutableDictionary *primaryKey = self.tc_propertyForPrimaryKey.mutableCopy;
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
    } useInputPropertyDicOnly:NO];
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
