/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>

@protocol FBFileManager;

/**
 Represents XCTestConfiguration class used by Apple to configure tests (aka .xctestconfiguration)
 */
@interface FBTestConfiguration : NSObject

/**
 The session identifier
 */
@property (nonatomic, copy, readonly) NSUUID *sessionIdentifier;

/**
 The name of the test module
 */
@property (nonatomic, copy, readonly) NSString *moduleName;

/**
 The path to test bundle
 */
@property (nonatomic, copy, readonly) NSString *testBundlePath;

/**
 The path to test configuration, if saved
 */
@property (nonatomic, copy, readonly) NSString *path;

/**
 Determines whether should initialize for UITesting
 */
@property (nonatomic, assign, readonly) BOOL shouldInitializeForUITesting;

@end

/**
 Creates FBTestConfiguration by:
 - creating object with requested values
 - saving it, if saveAs is set
 */
@interface FBTestConfigurationBuilder : NSObject

/**
 @return builder that uses [NSFileManager defaultManager] as file manager
 */
+ (instancetype)builder;

/**
 @param fileManager a file manager used with builder
 @return builder
 */
+ (instancetype)builderWithFileManager:(id<FBFileManager>)fileManager;

/**
 @param sessionIdentifier test session identifer
 @return builder
 */
- (instancetype)withSessionIdentifier:(NSUUID *)sessionIdentifier;

/**
 @param moduleName test module name
 @return builder
 */
- (instancetype)withModuleName:(NSString *)moduleName;

/**
 @param testBundlePath path to test bundle
 @return builder
 */
- (instancetype)withTestBundlePath:(NSString *)testBundlePath;

/**
 @param shouldInitializeForUITesting determines whether should initialize for UITesting
 @return builder
 */
- (instancetype)withUITesting:(BOOL)shouldInitializeForUITesting;

/**
 Adds tests to skip.

 @param testsToSkip tests to skip
 @return builder
 */
- (instancetype)withTestsToSkip:(NSSet<NSString *> *)testsToSkip;

/**
 Adds tests to run.

 @param testsToRun tests to run
 @return builder
 */
- (instancetype)withTestsToRun:(NSSet<NSString *> *)testsToRun;

/**
 Adds path to the target application for UI tests.

 @param targetApplicationPath path to the target application
 @return builder
 */
- (instancetype)withTargetApplicationPath:(NSString *)targetApplicationPath;

/**
 Adds bundle ID of to the target application for UI tests.

 @param targetApplicationBundleID bundle ID of to the target application
 @return builder
 */
- (instancetype)withTargetApplicationBundleID:(NSString *)targetApplicationBundleID;

/**
 Adds test environment dictionary, mapping Strings to Strings of the Environment to
 set when the tests are launched.

 @param testEnvironment test environment dictionary
 @return builder
 */
- (instancetype)withTestEnvironment:(NSDictionary<NSString *, NSString *> *)testEnvironment;

/**
 @param savePath is set, builder will save file at given path that can be loaded directly by XCTestConfiguration
 @return builder
 */
- (instancetype)saveAs:(NSString *)savePath;

/**
 @param error If there is an error, upon return contains an NSError object that describes the problem.
 @return prepared test configuration if the operation succeeds, otherwise nil.
 */
- (FBTestConfiguration *)buildWithError:(NSError **)error;

@end
