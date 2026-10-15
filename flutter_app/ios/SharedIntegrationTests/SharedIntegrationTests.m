@import XCTest;
@import UIKit;

// Public integration_test runner API, resolved in the host to avoid linking a
// second copy of the plugin into the hosted test bundle.
@protocol SharedFlutterRunner
- (void)testIntegrationTestWithResults:(void (^)(SEL, BOOL, NSString *))result;
@end

@interface SharedIntegrationTests : XCTestCase
@end
@implementation SharedIntegrationTests
- (void)testSharedWorkouts {
#if !TARGET_OS_SIMULATOR
    XCTFail(@"Integration tests require an iOS simulator");
    return;
#endif
    Class runnerClass = NSClassFromString(@"FLTIntegrationTestRunner");
    XCTAssertNotNil(runnerClass, @"Build the integration_test Dart entry point in debug mode");
    if (!runnerClass) return;
    id<SharedFlutterRunner> runner = [[runnerClass alloc] init];
    __block NSUInteger completed = 0;
    [runner testIntegrationTestWithResults:^(SEL selector, BOOL success, NSString *failure) {
        completed++;
        NSLog(@"Shared Dart scenario %@: %@", NSStringFromSelector(selector), success ? @"PASS" : @"FAIL");
        XCTAssertTrue(success, @"%@: %@", NSStringFromSelector(selector), failure);
    }];
    XCTAssertGreaterThanOrEqual(completed, 3u, @"All three shared Dart scenarios must report results");
}
@end
