//
//  TCMappingTests.m
//  SudiyiClient
//
//  Created by dake on 16/3/16.
//  Copyright © 2016年 dake. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "NSObject+TCMapping.h"
#import "NSObject+TCNSCoding.h"
#import "NSObject+TCJSONMapping.h"
#import "TCMappingMeta.h"


#define PropertySTR(name)   NSStringFromSelector(@selector(name))


@interface TestModel2 : NSObject <NSCoding, NSCopying>

@property (nonatomic, assign) CGRect frame;
@property (nonatomic, strong) NSArray<NSString *> *list;

@end


@implementation TestModel2

- (void)encodeWithCoder:(NSCoder *)aCoder { [self tc_encodeWithCoder:aCoder]; }
- (instancetype)initWithCoder:(NSCoder *)aDecoder { return [self tc_initWithCoder:aDecoder]; }
- (instancetype)copyWithZone:(NSZone *)zone { return self.tc_copy; }
- (NSUInteger)hash { return self.tc_hash; }
- (BOOL)isEqual:(id)object { return [self tc_isEqual:object]; }

@end



typedef struct TestStruct {
    int a;
    short d;
    char e;
    double b;
    float *c;
} TestStruct;

typedef struct BitStruct {
    int a:3;
    int b:3;
    int c:2;
} BitStruct;

typedef union TestUnion {
    int a;
    char b;
} TestUnion;

typedef NS_ENUM(NSInteger, TestEnume) {
    a = 0,
};

@interface TestModel : NSObject <NSCoding, NSCopying>

@property (nonatomic, copy) dispatch_block_t block;
@property (nonatomic, assign) TestEnume testEnume;
@property (nonatomic, assign) TestStruct testStruct;
@property (nonatomic, assign) BitStruct bitStruct;
@property (nonatomic, assign) TestUnion testUnion;
@property (nonatomic, assign) NSInteger userId;
@property (nonatomic, assign) CGRect frame;
@property (nonatomic, strong) id<NSCodingIgnore> model;
@property (nonatomic, weak) Class klass;
@property (nonatomic, assign) SEL selector;
@property (nonatomic, assign) int *pointer;
@property (nonatomic, assign) char const *cString;

@end


@implementation TestModel

+ (NSDictionary *)tc_propertyTypeFormat
{
    return @{PropertySTR(model): @"TestModel2"};
}

+ (BOOL)tc_JSONMappingIgnoreNSNull
{
    return NO;
}

- (NSString *)tc_stringValueForKey:(NSString *)key meta:(TCMappingMeta *)meta
{
    if ([key isEqualToString:PropertySTR(testStruct)]) {
        return [(NSValue *)[self valueForKey:key] unsafeStringValueForCustomStruct];
        
    } else if ([key isEqualToString:PropertySTR(bitStruct)]) {
        BitStruct bitStruct = self.bitStruct;
        NSDictionary *dic = @{@"a": @(bitStruct.a), @"b": @(bitStruct.b), @"c": @(bitStruct.c)};
        return dic.tc_JSONString;
        
    } else if ([key isEqualToString:PropertySTR(testUnion)]) {
        TestUnion testUnion = self.testUnion;
        return [[NSValue valueWithBytes:&testUnion objCType:meta->_typeName.UTF8String] unsafeStringValueForCustomStruct];
    }
    return nil;
}

- (void)tc_setStringValue:(nullable NSString *)str forKey:(NSString *)key meta:(TCMappingMeta *)meta
{
    if ([key isEqualToString:PropertySTR(testStruct)]) {
        [self setValue:[NSValue valueWitUnsafeStringValue:str customStructType:meta->_typeName.UTF8String] forKey:key];
        
    } else if ([key isEqualToString:PropertySTR(bitStruct)]) {
        NSDictionary<NSString *, NSNumber *> *dic = str.tc_JSONObject;
        BitStruct bitStruct = {0};
        bitStruct.a = dic[@"a"].intValue;
        bitStruct.b = dic[@"b"].intValue;
        bitStruct.c = dic[@"c"].intValue;
        self.bitStruct = bitStruct;
        
    } else if ([key isEqualToString:PropertySTR(testUnion)]) {
        NSValue *value = [NSValue valueWitUnsafeStringValue:str customStructType:meta->_typeName.UTF8String];
        TestUnion testUnion = {0};
        [value getValue:&testUnion];
        self.testUnion = testUnion;
        
    } else if ([key isEqualToString:PropertySTR(cString)]) {
        self.cString = str.UTF8String;
    }
}

- (void)encodeWithCoder:(NSCoder *)aCoder { [self tc_encodeWithCoder:aCoder]; }
- (instancetype)initWithCoder:(NSCoder *)aDecoder { return [self tc_initWithCoder:aDecoder]; }
- (instancetype)copyWithZone:(NSZone *)zone { return self.tc_copy; }
- (NSUInteger)hash { return self.tc_hash; }
- (BOOL)isEqual:(id)object { return [self tc_isEqual:object]; }

@end

@interface TestModel (xx)

@property (nonatomic, strong) id test;

@end

@implementation TestModel (xx)

@dynamic test;
//
//- (id)test
//{
//    return nil;
//}
//
//- (void)setTest:(id)test
//{
//
//}


@end






@interface TCMappingTests : XCTestCase

@end

@implementation TCMappingTests
{
    @private
    
}

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testModelMapping
{
    TestModel *model = [[TestModel alloc] init];
    [model tc_mappingWithDictionary:@{PropertySTR(userId): @423, PropertySTR(frame): @"{{1,2},{3,4}}", PropertySTR(model): @{PropertySTR(frame): @"{{61,78},{3,4}}"}}];
    XCTAssertNotNil(model);
    XCTAssertNotNil(model.model);
    
    [model setValue:^{NSLog(@"xfrsfsdfsdfds");} forKey:PropertySTR(block)];
    [model setValue:NSString.class forKey:PropertySTR(klass)];
    model.cString = "1234";
    
    BitStruct bitStruct = {0};
    bitStruct.a = 1;
    bitStruct.b = 3;
    model.bitStruct = bitStruct;
    
    
    TestUnion testUnion = {0};
    testUnion.a = 7;
    model.testUnion = testUnion;
    
    TestStruct testStruct = {0};
    testStruct.a = 5;
    testStruct.d = 6;
    [model setValue:[NSValue valueWithBytes:&testStruct objCType:@encode(TestStruct)] forKey:PropertySTR(testStruct)];
    
    
    // copy
    TestModel *copy = model.copy;
    XCTAssertNotNil(copy);
    
    
    // equal
    XCTAssertTrue([copy isEqual:model]);
    
    
    // json
    NSDictionary *json = model.tc_JSONObject;
    XCTAssertNotNil(json);
    
    
    // mapping
    TestModel *map = [TestModel tc_mappingWithDictionary:json];
    XCTAssertNotNil(map);
    
    map.block = model.block;
    XCTAssertTrue([map isEqual:model]);
    
    
    // nscoding
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:model];
    XCTAssertNotNil(data);
    
    TestModel *coding = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    XCTAssertNotNil(coding);
    
    coding.block = model.block;
    coding.model = model.model;
    XCTAssertTrue([coding isEqual:model]);
}


//- (void)testPerformanceExample {
//    // This is an example of a performance test case.
//    [self measureBlock:^{
//        // Put the code you want to measure the time of here.
//    }];
//}

@end
