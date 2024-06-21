//
//  CurrentTestCase.h
//  
//
//  Created by Mykola Tarbaiev on 21.02.22.
//

@import Foundation;
@import XCTest;

@interface CurrentTestCaseObserver : NSObject <XCTestObservation>
@property(class, readonly) XCTestCase* _Nullable currentTestCase;
@end

