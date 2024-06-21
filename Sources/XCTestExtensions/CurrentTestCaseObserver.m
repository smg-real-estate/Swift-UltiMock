//
//  CurrentTestCase.m
//  
//
//  Created by Mykola Tarbaiev on 21.02.22.
//

#import "CurrentTestCase.h"

@interface CurrentTestCaseObserver () <XCTestObservation>
@end

XCTestCase *XCTCurrentTestCase;

static CurrentTestCaseObserver *observer;

@implementation CurrentTestCaseObserver

+ (void)load {
    observer = [CurrentTestCaseObserver new];
    [XCTestObservationCenter.sharedTestObservationCenter addTestObserver: observer];
}

+ (XCTestCase *)currentTestCase {
    return XCTCurrentTestCase;
}

- (void)testCaseWillStart:(XCTestCase *)testCase {
    XCTCurrentTestCase = testCase;
}

- (void)testCaseDidFinish:(XCTestCase *)testCase {
    XCTCurrentTestCase = nil;
}

@end
