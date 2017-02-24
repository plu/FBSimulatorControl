/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBTestConfiguration.h"

#import <FBControlCore/FBControlCore.h>

#import <XCTest/XCTestConfiguration.h>

#import <objc/runtime.h>

@interface FBTestConfiguration ()
@property (nonatomic, copy) NSUUID *sessionIdentifier;
@property (nonatomic, copy) NSString *moduleName;
@property (nonatomic, copy) NSString *testBundlePath;
@property (nonatomic, copy) NSString *path;
@property (nonatomic, assign) BOOL shouldInitializeForUITesting;
@end

@implementation FBTestConfiguration
@end


@interface FBTestConfigurationBuilder ()
@property (nonatomic, strong) id<FBFileManager> fileManager;
@property (nonatomic, copy) NSUUID *sessionIdentifier;
@property (nonatomic, copy) NSString *moduleName;
@property (nonatomic, copy) NSString *testBundlePath;
@property (nonatomic, copy) NSString *savePath;
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *testEnvironment;
@property (nonatomic, copy) NSSet<NSString *> *testsToRun;
@property (nonatomic, copy) NSSet<NSString *> *testsToSkip;
@property (nonatomic, assign) BOOL shouldInitializeForUITesting;
@property (nonatomic, copy) NSString *targetApplicationBundleID;
@property (nonatomic, copy) NSString *targetApplicationPath;
@end

@implementation FBTestConfigurationBuilder

+ (instancetype)builder
{
  return [self.class builderWithFileManager:[NSFileManager defaultManager]];
}

+ (instancetype)builderWithFileManager:(id<FBFileManager>)fileManager
{
  FBTestConfigurationBuilder *builder = [self.class new];
  builder.fileManager = fileManager;
  return builder;
}

- (instancetype)withSessionIdentifier:(NSUUID *)sessionIdentifier
{
  self.sessionIdentifier = sessionIdentifier;
  return self;
}

- (instancetype)withModuleName:(NSString *)moduleName
{
  self.moduleName = moduleName;
  return self;
}

- (instancetype)withTestBundlePath:(NSString *)testBundlePath
{
  self.testBundlePath = testBundlePath;
  return self;
}

- (instancetype)withTestEnvironment:(NSDictionary<NSString *, NSString *> *)testEnvironment
{
  self.testEnvironment = testEnvironment;
  return self;
}

- (instancetype)withUITesting:(BOOL)shouldInitializeForUITesting
{
  self.shouldInitializeForUITesting = shouldInitializeForUITesting;
  return self;
}

- (instancetype)withTestsToRun:(NSSet<NSString *> *)testsToRun
{
  self.testsToRun = testsToRun;
  return self;
}

- (instancetype)withTestsToSkip:(NSSet<NSString *> *)testsToSkip
{
  self.testsToSkip = testsToSkip;
  return self;
}

- (instancetype)withTargetApplicationBundleID:(NSString *)targetApplicationBundleID
{
  self.targetApplicationBundleID = targetApplicationBundleID;
  return self;
}

- (instancetype)withTargetApplicationPath:(NSString *)targetApplicationPath
{
  self.targetApplicationPath = targetApplicationPath;
  return self;
}

- (instancetype)saveAs:(NSString *)savePath
{
  self.savePath = savePath;
  return self;
}

- (FBTestConfiguration *)buildWithError:(NSError **)error
{
  if (self.savePath) {
    NSAssert(self.fileManager, @"fileManager is required to save test configuration");
    XCTestConfiguration *testConfiguration = [objc_lookUpClass("XCTestConfiguration") new];
    testConfiguration.sessionIdentifier = self.sessionIdentifier;
    testConfiguration.testBundleURL = (self.testBundlePath ? [NSURL fileURLWithPath:self.testBundlePath] : nil);
    testConfiguration.treatMissingBaselinesAsFailures = NO;
    testConfiguration.productModuleName = self.moduleName;
    testConfiguration.reportResultsToIDE = YES;
    testConfiguration.pathToXcodeReportingSocket = nil;
    testConfiguration.testsMustRunOnMainThread = self.shouldInitializeForUITesting;
    testConfiguration.initializeForUITesting = self.shouldInitializeForUITesting;
    testConfiguration.testsToSkip = self.testsToSkip;
    testConfiguration.testsToRun = self.testsToRun;
    testConfiguration.targetApplicationPath = self.targetApplicationPath;
    testConfiguration.targetApplicationBundleID = self.targetApplicationBundleID;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:testConfiguration];
    if (![self.fileManager writeData:data toFile:self.savePath options:NSDataWritingAtomic error:error]) {
      return nil;
    }
  }

  FBTestConfiguration *configuration = [FBTestConfiguration new];
  configuration.sessionIdentifier = self.sessionIdentifier;
  configuration.testBundlePath = self.testBundlePath;
  configuration.moduleName = self.moduleName;
  configuration.path = self.savePath;
  configuration.shouldInitializeForUITesting = self.shouldInitializeForUITesting;
  return configuration;
}

@end
