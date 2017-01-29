/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class FBTestManagerTestReporterTestSuite;

/**
 Transforms a graph of FBTestManagerTestReporterTestSuite objects into
 an NSXMLDocument representation of the JUnit format.
 */
@interface FBTestManagerJUnitGenerator : NSObject

/**
 Generates JUnit XML document for given test suite.

 @param testSuite the test suite to transform.
 @return an NSXMLDocument instance.
 */
+ (NSXMLDocument *)documentForTestSuite:(FBTestManagerTestReporterTestSuite *)testSuite;

@end

NS_ASSUME_NONNULL_END
