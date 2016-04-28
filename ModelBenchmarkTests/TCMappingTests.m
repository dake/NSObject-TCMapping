//
//  TCMappingTests.m
//  TCKit
//
//  Created by dake on 16/3/16.
//  Copyright © 2016年 dake. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "NSObject+TCMapping.h"
#import "NSObject+TCNSCoding.h"
#import "NSObject+TCJSONMapping.h"
#import "TCMappingMeta.h"
#import "UIColor+TCUtilities.h"


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

@property (nonatomic, strong) UIColor *color;

@end


@implementation TestModel

+ (TCMappingOption *)tc_mappingOption
{
    static TCMappingOption *opt = nil;
    if (nil == opt) {
        opt = [[TCMappingOption alloc] init];
        opt.typeMapping = @{PropertySTR(model): @"TestModel2"};
        opt.shouldJSONMappingNSNull = YES;
    }
    
    return opt;
}

- (NSString *)tc_serializedStringForKey:(NSString *)key meta:(TCMappingMeta *)meta
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

- (void)tc_setSerializedString:(nullable NSString *)str forKey:(NSString *)key meta:(TCMappingMeta *)meta
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



@interface TestIgnoreModel : NSObject <NSCoding, NSCopying>

@property (nonatomic, strong) NSNumber<TCMappingIgnore> *num;
@property (nonatomic, copy) NSString<NSCopyingIgnore> *str;
@property (nonatomic, weak) Class klass;
@property (nonatomic, strong) NSURL<TCJSONMappingIgnore> *url;


@end

@implementation TestIgnoreModel

+ (TCMappingOption *)tc_mappingOption
{
    static TCMappingOption *opt = nil;
    if (nil == opt) {
        opt = [[TCMappingOption alloc] init];
        opt.nameNSCodingMapping = @{PropertySTR(klass): NSNull.null};
    }
    
    return opt;
}

- (void)encodeWithCoder:(NSCoder *)aCoder { [self tc_encodeWithCoder:aCoder]; }
- (instancetype)initWithCoder:(NSCoder *)aDecoder { return [self tc_initWithCoder:aDecoder]; }
- (instancetype)copyWithZone:(NSZone *)zone { return self.tc_copy; }
- (NSUInteger)hash { return self.tc_hash; }
- (BOOL)isEqual:(id)object { return [self tc_isEqual:object]; }

@end




@interface TCMappingTests : XCTestCase

@end

@implementation TCMappingTests


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
    [model tc_mappingWithDictionary:@{PropertySTR(userId): @423, PropertySTR(frame): @"{{1,2},{3,4}}", PropertySTR(color): @{@"rgb": @(0xff00ff)}, PropertySTR(model): @{PropertySTR(frame): @"{{61,78},{3,4}}"}}];
    XCTAssertNotNil(model);
    XCTAssertNotNil(model.model);
    XCTAssertNotNil(model.color);
    UIColor *color = RGBHex(0xff00ff);
    XCTAssertEqualObjects(model.color, color);
    
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
    XCTAssertNotNil(json[@"color"]);
    
    
    // mapping
    TestModel *map = [TestModel tc_mappingWithDictionary:json];
    XCTAssertNotNil(map);
    XCTAssertEqualObjects(model.color, map.color);
    
    map.block = model.block;
    XCTAssertTrue([map isEqual:model]);
    
    
    // nscoding
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:model];
    XCTAssertNotNil(data);
    
    TestModel *coding = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    XCTAssertNotNil(coding);
    XCTAssertNotNil(coding.color);
    XCTAssertEqualObjects(model.color, coding.color);
    
    coding.block = model.block;
    coding.model = model.model;
    XCTAssertTrue([coding isEqual:model]);
}

- (void)testIgnoreModel
{
    NSDictionary *dic = @{PropertySTR(num): @1,
                          PropertySTR(str): @"3444",
                          PropertySTR(klass): TestIgnoreModel.class,
                          PropertySTR(url): @"http://glade.tk"};
    
    
    // mapping
    TestIgnoreModel *model = [TestIgnoreModel tc_mappingWithDictionary:dic];
    XCTAssertNotNil(model);
    XCTAssertNil(model.num);
    XCTAssertTrue([model.str isEqualToString:dic[PropertySTR(str)]]);
    XCTAssertTrue(model.klass == dic[PropertySTR(klass)]);
    XCTAssertTrue([model.url.absoluteString isEqualToString:dic[PropertySTR(url)]]);
    
    
    // copying
    model.num = dic[PropertySTR(num)];
    TestIgnoreModel *copy = model.copy;
    XCTAssertNotNil(copy);
    XCTAssertNil(copy.str);
    XCTAssertTrue([copy.num isEqualToNumber:dic[PropertySTR(num)]]);
    XCTAssertTrue(copy.klass == dic[PropertySTR(klass)]);
    XCTAssertTrue([copy.url.absoluteString isEqualToString:dic[PropertySTR(url)]]);
    
    
    // coding
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:model];
    XCTAssertNotNil(data);
    
    TestIgnoreModel *coding = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    XCTAssertNotNil(coding);
    XCTAssertNil(coding.klass);
    XCTAssertTrue([coding.num isEqualToNumber:dic[PropertySTR(num)]]);
    XCTAssertTrue([coding.str isEqualToString:dic[PropertySTR(str)]]);
    XCTAssertTrue([coding.url.absoluteString isEqualToString:dic[PropertySTR(url)]]);
    
    
    // json
    NSDictionary *json = model.tc_JSONObject;
    XCTAssertNotNil(json);
    XCTAssertNil(json[PropertySTR(url)]);
    XCTAssertTrue([json[PropertySTR(num)] isEqualToNumber:dic[PropertySTR(num)]]);
    XCTAssertTrue([json[PropertySTR(str)] isEqualToString:dic[PropertySTR(str)]]);
    XCTAssertTrue(NSClassFromString(json[PropertySTR(klass)]) == dic[PropertySTR(klass)]);
}


//- (void)testPerformanceExample {
//    // This is an example of a performance test case.
//    [self measureBlock:^{
//        // Put the code you want to measure the time of here.
//    }];
//}

@end
