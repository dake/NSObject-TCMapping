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


static const char *property_getTypeName(objc_property_t property)
{
	const char *attributes = property_getAttributes(property);
    char buffer[1 + strlen(attributes)];
	strcpy(buffer, attributes);
	char *state = buffer, *attribute;
	while ((attribute = strsep(&state, ",")) != NULL) {
		if (attribute[0] == 'T') {
			size_t len = strlen(attribute);
			attribute[len - 1] = '\0';
			return (const char *)[[NSData dataWithBytes:(attribute + 3) length:len - 2] bytes];
		}
	}
	return "@";
}



static NSMutableDictionary *s_propertyClassByClassAndPropertyName;
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
        id obj = [self mappingWithDictionary:dic managerObjectContext:context];
        if (nil != obj) {
            [outArry addObject:obj];
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
    if (nil == dic || ![dic isKindOfClass:NSDictionary.class] || dic.count < 1) {
        return nil;
    }
    
    NSArray *systemReadwriteProperties = self.readwritePropertyListForCurrentClass;
    NSMutableDictionary *tmpDic = [NSMutableDictionary dictionaryWithObjects:systemReadwriteProperties forKeys:systemReadwriteProperties];
    NSDictionary *nameMappingDic = self.propertyNameMapping;
    [tmpDic removeObjectsForKeys:nameMappingDic.allKeys];
    [tmpDic addEntriesFromDictionary:nameMappingDic];
    nameMappingDic = tmpDic;
    
    NSDictionary *typeMappingDic = self.propertyTypeFormat;
    
    id obj = nil;
    
    for (NSString *nameKey in nameMappingDic.allKeys) {
        if (nil == nameKey || [NSNull null] == (NSNull *)nameKey) {
            continue;
        }
        id key = nameMappingDic[nameKey];
        id value = dic[key];
        if (nil == value) {
            value = dic[nameKey];
        }
        if (nil == value
            || [NSNull null] == value
            /*|| (context != nil && [self isPropertyReadOnly:self propertyName:nameKey])*/) {
            continue;
        }
        
        if ([value isKindOfClass:NSDictionary.class]) {
            if ([(NSDictionary *)value count] > 0) {
                
                NSString *klassName = typeMappingDic[nameKey];
                Class klass = Nil;
                if (nil == klassName) {
                    klass = [self propertyClassForPropertyName:key ofClass:self];
                }
                else {
                    klass = NSClassFromString(klassName);
                }
                if (Nil != klass) {
                    value = [klass mappingWithDictionary:value managerObjectContext:context];
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
                    arrayItemType = [self propertyClassForPropertyName:nameMappingDic[nameKey] ofClass:self];
                    if (![arrayItemType isSubclassOfClass:NSArray.class]) {
                        value = nil;
                    }
                }
            }
            else {
                value = nil;
            }
        }
        else {
            if (nil == value) {
                NSAssert(false, @"value not correspond to property type.");
                return nil;
            }
        }
        
        if (nil != value) {
            if (nil == obj) {
                if (nil == context) {
                    obj = [[self alloc] init];
                }
                else {
                    obj = [self coreDataInstanceWithValue:dic withNameMappingDic:nameMappingDic withContext:context];
                }
            }
            [obj setValue:value forKey:nameKey];
        }
    }
    
    return [obj tc_validate] ? obj : nil;
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


#pragma mark - MappingRuntimeHelper

/**
 *	Judge  if the property is readOnly
 *
 *	@param	klass	the property'owner class
 *	@param	propertyName
 *
 *	@return	<#return value description#>
 */
+ (BOOL)isPropertyReadOnly:(Class)klass propertyName:(NSString *)propertyName
{
    const char *type = property_getAttributes(class_getProperty(klass, [propertyName UTF8String]));
    NSString *typeString = [NSString stringWithUTF8String:type];
    NSArray *attributes = [typeString componentsSeparatedByString:@","];
    NSString *typeAttribute = [attributes firstObject];
    
    return [typeAttribute rangeOfString:@"R"].length > 0;
}

/**
 *	return property'class by the property'name
 *
 *	@param	propertyName	<#propertyName description#>
 *	@param	klass	<#klass description#>
 *
 *	@return	property'class by the property'name
 */
+ (Class)propertyClassForPropertyName:(NSString *)propertyName ofClass:(Class)klass
{
	if (nil == s_propertyClassByClassAndPropertyName) {
        s_propertyClassByClassAndPropertyName = [NSMutableDictionary dictionary];
    }
	
	NSString *key = [NSString stringWithFormat:@"%@:%@", NSStringFromClass(klass), propertyName];
	NSString *value = [s_propertyClassByClassAndPropertyName objectForKey:key];
	
	if (nil != value) {
		return NSClassFromString(value);
	}
	
	unsigned int propertyCount = 0;
	objc_property_t *properties = class_copyPropertyList(klass, &propertyCount);
	
	const char *cPropertyName = propertyName.UTF8String;
	
	for (NSInteger i = 0; i < propertyCount; ++i) {
		objc_property_t property = properties[i];
		const char *name = property_getName(property);
        
		if (strcmp(cPropertyName, name) == 0) {
			free(properties);
            NSString *className = nil;
            const char *typeName = property_getTypeName(property);
            if (typeName != NULL) {
                className = [NSString stringWithUTF8String:typeName];
                
                [s_propertyClassByClassAndPropertyName setObject:className forKey:key];
                // we found the property - we need to free
                return NSClassFromString(className);
            }
            
            return Nil;
		}
	}
    
    free(properties);
    
	return [self propertyClassForPropertyName:propertyName ofClass:class_getSuperclass(klass)];
}

+ (NSArray *)readwritePropertyListForCurrentClass
{
    NSMutableArray *propertyNames = [NSMutableArray array];
    unsigned int num = 0;
    objc_property_t *properties = class_copyPropertyList(self, &num);
    for (NSInteger i = 0; i < num; ++i) {
        // !!!: filter out readonly property
        char *readonly = property_copyAttributeValue(properties[i], "R");
        if (NULL == readonly) {
            [propertyNames addObject:[NSString stringWithCString:property_getName(properties[i]) encoding:NSUTF8StringEncoding]];
        }
        else {
           free(readonly);
        }
    }
    free(properties);
    return propertyNames;
}

@end


@interface NSString (TC_NSNumber)
@end

@implementation NSString (TC_NSNumber)

#pragma mark -

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
    return self.intValue;
}

- (unsigned long)unsignedLongValue
{
    return self.intValue;
}

- (unsigned long long)unsignedLongLongValue
{
    return self.longLongValue;
}


@end
