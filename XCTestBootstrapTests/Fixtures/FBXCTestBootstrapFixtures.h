/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

/**
 Fetching Fixtures, causing test failures if they cannot be obtained.
 */
@interface XCTestCase (FBXCTestBootstrapFixtures)

/**
 An iOS Unit Test Bundle.
 */
+ (NSBundle *)iosUnitTestBundleFixture;

/**
 An Mac OS X Unit Test Bundle.
 */
+ (NSBundle *)macUnitTestBundleFixture;

/**
 A File Path to the first JUnit XML result.
 */
+ (NSString *)JUnitXMLResult0Path;

/**
 A File Path to the second JUnit XML result.
 */
+ (NSString *)JUnitXMLResult1Path;

/**
 A File Path to an xctestrun file.
 */
+ (NSString *)sampleXCTestRunPath;

@end
