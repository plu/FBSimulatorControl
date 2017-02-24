/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBTestLaunchConfiguration.h"

#import <FBControlCore/FBControlCore.h>

#import "FBTestManagerTestReporter.h"

@implementation FBTestLaunchConfiguration

- (instancetype)initWithTestBundlePath:(NSString *)testBundlePath applicationLaunchConfiguration:(FBApplicationLaunchConfiguration *)applicationLaunchConfiguration testHostPath:(NSString *)testHostPath timeout:(NSTimeInterval)timeout testEnvironment:(NSDictionary<NSString *, NSString *> *)testEnvironment testsToRun:(NSSet<NSString *> *)testsToRun testsToSkip:(NSSet<NSString *> *)testsToSkip initializeUITesting:(BOOL)initializeUITesting targetApplicationBundleID:(NSString *)targetApplicationBundleID targetApplicationPath:(NSString *)targetApplicationPath
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _testBundlePath = testBundlePath;
  _applicationLaunchConfiguration = applicationLaunchConfiguration;
  _testHostPath = testHostPath;
  _timeout = timeout;
  _testEnvironment = testEnvironment;
  _testsToRun = testsToRun ?: [NSSet set];
  _testsToSkip = testsToSkip ?: [NSSet set];
  _shouldInitializeUITesting = initializeUITesting;
  _targetApplicationBundleID = targetApplicationBundleID;
  _targetApplicationPath = targetApplicationPath;

  return self;
}

+ (instancetype)configurationWithTestBundlePath:(NSString *)testBundlePath
{
  NSParameterAssert(testBundlePath);
  return [[FBTestLaunchConfiguration alloc] initWithTestBundlePath:testBundlePath applicationLaunchConfiguration:nil testHostPath:nil timeout:0 testEnvironment:nil testsToRun:nil testsToSkip:[NSSet set] initializeUITesting:NO targetApplicationBundleID:nil targetApplicationPath:nil];
}

- (instancetype)withApplicationLaunchConfiguration:(FBApplicationLaunchConfiguration *)applicationLaunchConfiguration
{
  return [[FBTestLaunchConfiguration alloc]
    initWithTestBundlePath:self.testBundlePath
    applicationLaunchConfiguration:applicationLaunchConfiguration
    testHostPath:self.testHostPath
    timeout:self.timeout
    testEnvironment:self.testEnvironment
    testsToRun:self.testsToRun
    testsToSkip:self.testsToSkip
    initializeUITesting:self.shouldInitializeUITesting
    targetApplicationBundleID:self.targetApplicationBundleID
    targetApplicationPath:self.targetApplicationPath];
}

- (instancetype)withTestHostPath:(NSString *)testHostPath
{
  return [[FBTestLaunchConfiguration alloc]
    initWithTestBundlePath:self.testBundlePath
    applicationLaunchConfiguration:self.applicationLaunchConfiguration
    testHostPath:testHostPath
    timeout:self.timeout
    testEnvironment:self.testEnvironment
    testsToRun:self.testsToRun
    testsToSkip:self.testsToSkip
    initializeUITesting:self.shouldInitializeUITesting
    targetApplicationBundleID:self.targetApplicationBundleID
    targetApplicationPath:self.targetApplicationPath];
}

- (instancetype)withTimeout:(NSTimeInterval)timeout
{
  return [[FBTestLaunchConfiguration alloc]
    initWithTestBundlePath:self.testBundlePath
    applicationLaunchConfiguration:self.applicationLaunchConfiguration
    testHostPath:self.testHostPath
    timeout:timeout
    testEnvironment:self.testEnvironment
    testsToRun:self.testsToRun
    testsToSkip:self.testsToSkip
    initializeUITesting:self.shouldInitializeUITesting
    targetApplicationBundleID:self.targetApplicationBundleID
    targetApplicationPath:self.targetApplicationPath];
}

- (instancetype)withTestEnvironment:(NSDictionary<NSString *, NSString *> *)testEnvironment
{
  return [[FBTestLaunchConfiguration alloc]
    initWithTestBundlePath:self.testBundlePath
    applicationLaunchConfiguration:self.applicationLaunchConfiguration
    testHostPath:self.testHostPath
    timeout:self.timeout
    testEnvironment:testEnvironment
    testsToRun:self.testsToRun
    testsToSkip:self.testsToSkip
    initializeUITesting:self.shouldInitializeUITesting
    targetApplicationBundleID:self.targetApplicationBundleID
    targetApplicationPath:self.targetApplicationPath];
}

- (instancetype)withTestsToRun:(NSSet<NSString *> *)testsToRun
{
  return [[FBTestLaunchConfiguration alloc]
    initWithTestBundlePath:self.testBundlePath
    applicationLaunchConfiguration:self.applicationLaunchConfiguration
    testHostPath:self.testHostPath
    timeout:self.timeout
    testEnvironment:self.testEnvironment
    testsToRun:testsToRun
    testsToSkip:self.testsToSkip
    initializeUITesting:self.shouldInitializeUITesting
    targetApplicationBundleID:self.targetApplicationBundleID
    targetApplicationPath:self.targetApplicationPath];
}

- (instancetype)withTestsToSkip:(NSSet<NSString *> *)testsToSkip
{
  return [[FBTestLaunchConfiguration alloc]
    initWithTestBundlePath:self.testBundlePath
    applicationLaunchConfiguration:self.applicationLaunchConfiguration
    testHostPath:self.testHostPath
    timeout:self.timeout
    testEnvironment:self.testEnvironment
    testsToRun:self.testsToRun
    testsToSkip:testsToSkip
    initializeUITesting:self.shouldInitializeUITesting
    targetApplicationBundleID:self.targetApplicationBundleID
    targetApplicationPath:self.targetApplicationPath];
}

- (instancetype)withUITesting:(BOOL)shouldInitializeUITesting
{
  return [[FBTestLaunchConfiguration alloc]
    initWithTestBundlePath:self.testBundlePath
    applicationLaunchConfiguration:self.applicationLaunchConfiguration
    testHostPath:self.testHostPath
    timeout:self.timeout
    testEnvironment:self.testEnvironment
    testsToRun:self.testsToRun
    testsToSkip:self.testsToSkip
    initializeUITesting:shouldInitializeUITesting
    targetApplicationBundleID:self.targetApplicationBundleID
    targetApplicationPath:self.targetApplicationPath];
}

- (instancetype)withTargetApplicationBundleID:(NSString *)targetApplicationBundleID
{
  return [[FBTestLaunchConfiguration alloc]
    initWithTestBundlePath:self.testBundlePath
    applicationLaunchConfiguration:self.applicationLaunchConfiguration
    testHostPath:self.testHostPath
    timeout:self.timeout
    testEnvironment:self.testEnvironment
    testsToRun:self.testsToRun
    testsToSkip:self.testsToSkip
    initializeUITesting:self.shouldInitializeUITesting
    targetApplicationBundleID:targetApplicationBundleID
    targetApplicationPath:self.targetApplicationPath];
}

- (instancetype)withTargetApplicationPath:(NSString *)targetApplicationPath
{
  return [[FBTestLaunchConfiguration alloc]
    initWithTestBundlePath:self.testBundlePath
    applicationLaunchConfiguration:self.applicationLaunchConfiguration
    testHostPath:self.testHostPath
    timeout:self.timeout
    testEnvironment:self.testEnvironment
    testsToRun:self.testsToRun
    testsToSkip:self.testsToSkip
    initializeUITesting:self.shouldInitializeUITesting
    targetApplicationBundleID:self.targetApplicationBundleID
    targetApplicationPath:targetApplicationPath];
}

#pragma mark NSCopying

- (instancetype)copyWithZone:(NSZone *)zone
{
  return self;
}

#pragma mark NSObject

- (BOOL)isEqual:(FBTestLaunchConfiguration *)configuration
{
  if (![configuration isKindOfClass:self.class]) {
    return NO;
  }

  return (self.testBundlePath == configuration.testBundlePath || [self.testBundlePath isEqualToString:configuration.testBundlePath]) &&
         (self.applicationLaunchConfiguration == configuration.applicationLaunchConfiguration  || [self.applicationLaunchConfiguration isEqual:configuration.applicationLaunchConfiguration]) &&
         (self.testHostPath == configuration.testHostPath || [self.testHostPath isEqualToString:configuration.testHostPath]) &&
         (self.testEnvironment == configuration.testEnvironment || [self.testEnvironment isEqualToDictionary:configuration.testEnvironment]) &&
         (self.testsToRun == configuration.testsToRun || [self.testsToRun isEqualToSet:configuration.testsToRun]) &&
         (self.testsToSkip == configuration.testsToSkip || [self.testsToSkip isEqualToSet:configuration.testsToSkip]) &&
         (self.targetApplicationBundleID == configuration.targetApplicationBundleID || [self.targetApplicationBundleID isEqualToString:configuration.targetApplicationBundleID]) &&
         (self.targetApplicationPath == configuration.targetApplicationPath || [self.targetApplicationPath isEqualToString:configuration.targetApplicationPath]) &&
         self.timeout == configuration.timeout &&
         self.shouldInitializeUITesting == configuration.shouldInitializeUITesting;
}

- (NSUInteger)hash
{
  return self.testBundlePath.hash ^ self.applicationLaunchConfiguration.hash ^ self.testHostPath.hash ^ self.testEnvironment.hash ^ self.testsToSkip.hash ^ self.testsToRun.hash ^ self.targetApplicationBundleID.hash ^ self.targetApplicationPath.hash ^ (unsigned long) self.timeout ^ (unsigned long) self.shouldInitializeUITesting;
}

#pragma mark FBDebugDescribeable

- (NSString *)description
{
  return [NSString stringWithFormat:
    @"FBTestLaunchConfiguration TestBundlePath %@ | AppConfig %@ | HostPath %@ | UITesting %d | TestsToRun %@ | TestsToSkip %@",
    self.testBundlePath,
    self.applicationLaunchConfiguration,
    self.testHostPath,
    self.shouldInitializeUITesting,
    self.testsToRun,
    self.testsToSkip
  ];
}

- (NSString *)shortDescription
{
  return [self description];
}

- (NSString *)debugDescription
{
  return [self description];
}

#pragma mark FBJSONSerializable

- (NSDictionary *)jsonSerializableRepresentation
{
  return @{
    @"test_bundle_path" : self.testBundlePath ?: NSNull.null,
    @"test_app_bundle_id" : self.applicationLaunchConfiguration ?: NSNull.null,
    @"test_host_path" : self.testHostPath ?: NSNull.null,
    @"test_environment": self.testEnvironment ?: NSNull.null,
    @"tests_to_run": self.testsToRun.allObjects ?: NSNull.null,
    @"tests_to_skip": self.testsToSkip.allObjects ?: NSNull.null,
    @"test_should_initialize_ui_testing": @(self.shouldInitializeUITesting),
    @"test_target_application_bundle_id": self.targetApplicationBundleID ?: NSNull.null,
    @"test_target_application_path": self.targetApplicationPath ?: NSNull.null,
  };
}

@end
