/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>

#import <XCTestBootstrap/XCTestBootstrap.h>

#import "FBXCTestBootstrapFixtures.h"

@interface FBXCTestRunTests : XCTestCase

@end

@implementation FBXCTestRunTests

- (void)testValidTestRunConfiguration
{
  if (!FBControlCoreGlobalConfiguration.isXcode8OrGreater) {
    NSLog(@"Skipping running -[%@ %@] since Xcode 8 or greater is required", NSStringFromClass(self.class), NSStringFromSelector(_cmd));
    return;
  }

  NSError *error;
  FBXCTestRun *testRun = [[FBXCTestRun
    withTestRunFileAtPath:[FBXCTestRunTests sampleXCTestRunPath]]
    buildWithError:&error];

  XCTAssertNil(error);
  XCTAssertEqual(testRun.targets.count, 2u);

  // First Unit Testing target
  {
    FBXCTestRunTarget *target = testRun.targets.firstObject;
    XCTAssertEqual(target.applications.count, 1u);
    XCTAssertEqualObjects(target.applications.firstObject.bundleID, @"com.facebook.Sample");

    FBTestLaunchConfiguration *testLaunchConfiguration = target.testLaunchConfiguration;
    XCTAssertEqualObjects(testLaunchConfiguration.testBundlePath.lastPathComponent, @"SampleTests.xctest");
    XCTAssertEqualObjects(testLaunchConfiguration.testHostPath.lastPathComponent, @"Sample.app");
    XCTAssertFalse(testLaunchConfiguration.shouldInitializeUITesting);
    XCTAssertNil(testLaunchConfiguration.targetApplicationPath);
    XCTAssertNil(testLaunchConfiguration.targetApplicationBundleID);
    XCTAssertGreaterThan(testLaunchConfiguration.testEnvironment.count, 0u);
    XCTAssertEqualObjects(testLaunchConfiguration.testsToSkip, [NSSet setWithArray:@[@"SampleTests/testSkipped"]]);

    FBApplicationLaunchConfiguration *applicationLaunchConfiguration = testLaunchConfiguration.applicationLaunchConfiguration;
    XCTAssertEqualObjects(applicationLaunchConfiguration.bundleID, @"com.facebook.Sample");
    XCTAssertEqualObjects(applicationLaunchConfiguration.bundleName, @"Sample");
  }

  // Second UI Testing target
  {
    FBXCTestRunTarget *target = testRun.targets.lastObject;
    XCTAssertEqual(target.applications.count, 2u);
    XCTAssertEqualObjects(target.applications.firstObject.bundleID, @"com.apple.test.SampleUITests-Runner");
    XCTAssertEqualObjects(target.applications.lastObject.bundleID, @"com.facebook.Sample");

    FBTestLaunchConfiguration *testLaunchConfiguration = target.testLaunchConfiguration;
    XCTAssertEqualObjects(testLaunchConfiguration.testBundlePath.lastPathComponent, @"SampleUITests.xctest");
    XCTAssertEqualObjects(testLaunchConfiguration.testHostPath.lastPathComponent, @"SampleUITests-Runner.app");
    XCTAssertTrue(testLaunchConfiguration.shouldInitializeUITesting);
    XCTAssertEqualObjects(testLaunchConfiguration.targetApplicationPath.lastPathComponent, @"Sample.app");
    XCTAssertEqualObjects(testLaunchConfiguration.targetApplicationBundleID, @"com.facebook.Sample");
    XCTAssertGreaterThan(testLaunchConfiguration.testEnvironment.count, 0u);
    XCTAssertEqualObjects(testLaunchConfiguration.testsToSkip, ([NSSet set]));

    FBApplicationLaunchConfiguration *applicationLaunchConfiguration = testLaunchConfiguration.applicationLaunchConfiguration;
    XCTAssertEqualObjects(applicationLaunchConfiguration.bundleID, @"com.apple.test.SampleUITests-Runner");
    XCTAssertEqualObjects(applicationLaunchConfiguration.bundleName, @"SampleUITests-Runner");
  }
}

- (void)testInvalidTestRunConfigurationPath
{
  if (!FBControlCoreGlobalConfiguration.isXcode8OrGreater) {
    NSLog(@"Skipping running -[%@ %@] since Xcode 8 or greater is required", NSStringFromClass(self.class), NSStringFromSelector(_cmd));
    return;
  }

  NSError *error;
  FBXCTestRun *testRun = [[FBXCTestRun
    withTestRunFileAtPath:@"/tmp/doesntexist.xctestrun"]
    buildWithError:&error];
  XCTAssertNotNil(error);
  XCTAssertNil(testRun);
}

- (void)testEmptyTestRunConfigurationPath
{
  if (!FBControlCoreGlobalConfiguration.isXcode8OrGreater) {
    NSLog(@"Skipping running -[%@ %@] since Xcode 8 or greater is required", NSStringFromClass(self.class), NSStringFromSelector(_cmd));
    return;
  }

  NSError *error;
  FBXCTestRun *testRun = [[FBXCTestRun
    withTestRunFileAtPath:[FBXCTestRunTests emptyXCTestRunPath]]
    buildWithError:&error];
  XCTAssertNotNil(error);
  XCTAssertNil(testRun);
}

@end
