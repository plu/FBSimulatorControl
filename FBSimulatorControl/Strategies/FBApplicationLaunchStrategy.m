/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBApplicationLaunchStrategy.h"

#import <FBControlCore/FBControlCore.h>

#import <CoreSimulator/SimDevice.h>

#import "FBApplicationLaunchStrategy.h"
#import "FBSimulator+Connection.h"
#import "FBSimulator+Helpers.h"
#import "FBSimulator+Private.h"
#import "FBSimulator.h"
#import "FBSimulatorBridge.h"
#import "FBSimulatorConnection.h"
#import "FBSimulatorDiagnostics.h"
#import "FBSimulatorError.h"
#import "FBSimulatorEventSink.h"
#import "FBSimulatorHistory+Queries.h"
#import "FBSimulatorHistory.h"
#import "FBSimulatorDiagnostics.h"
#import "FBSimulatorHistory+Queries.h"
#import "FBSimulatorProcessFetcher.h"
#import "FBProcessLaunchConfiguration+Simulator.h"

@interface FBApplicationLaunchStrategy ()

@property (nonnull, nonatomic, strong, readonly) FBSimulator *simulator;

@end

@interface FBApplicationLaunchStrategy_Bridge : FBApplicationLaunchStrategy

@end

@interface FBApplicationLaunchStrategy_CoreSimulator : FBApplicationLaunchStrategy

@end

@implementation FBApplicationLaunchStrategy

+ (instancetype)withSimulator:(FBSimulator *)simulator useBridge:(BOOL)useBridge;
{
  Class strategyClass = useBridge ? FBApplicationLaunchStrategy_CoreSimulator.class : FBApplicationLaunchStrategy_CoreSimulator.class;
  return [[strategyClass alloc] initWithSimulator:simulator];
}

+ (instancetype)withSimulator:(FBSimulator *)simulator
{
  return [self withSimulator:simulator useBridge:NO];
}

- (instancetype)initWithSimulator:(FBSimulator *)simulator
{
  self = [super init];
  if (!self){
    return nil;
  }

  _simulator = simulator;

  return self;
}

#pragma mark Public

- (FBProcessInfo *)launchApplication:(FBApplicationLaunchConfiguration *)appLaunch error:(NSError **)error
{
  FBSimulator *simulator = self.simulator;
  NSError *innerError = nil;
  FBApplicationDescriptor *application = [simulator installedApplicationWithBundleID:appLaunch.bundleID error:&innerError];
  if (!application) {
    return [[[[FBSimulatorError
      describeFormat:@"App %@ can't be launched as it isn't installed", appLaunch.bundleID]
      causedBy:innerError]
      inSimulator:simulator]
      fail:error];
  }

  // This check confirms that if there's a currently running process for the given Bundle ID it doesn't match one that has been recently launched.
  // Since the Background Modes of a Simulator can cause an Application to be launched independently of our usage of CoreSimulator,
  // it's possible that application processes will come to life before `launchApplication` is called, if it has been previously killed.
  FBProcessInfo *process = [simulator runningApplicationWithBundleID:appLaunch.bundleID error:&innerError];
  if (process && [simulator.history.launchedApplicationProcesses containsObject:process]) {
    return [[[[FBSimulatorError
      describeFormat:@"App %@ can't be launched as is running (%@)", appLaunch.bundleID, process.shortDescription]
      causedBy:innerError]
      inSimulator:simulator]
      fail:error];
  }

  // Make the stdout file.
  FBDiagnostic *stdOutDiagnostic = nil;
  if (![appLaunch createStdOutDiagnosticForSimulator:simulator diagnosticOut:&stdOutDiagnostic error:error]) {
    return nil;
  }
  // Make the stderr file.
  FBDiagnostic *stdErrDiagnostic = nil;
  if (![appLaunch createStdErrDiagnosticForSimulator:simulator diagnosticOut:&stdErrDiagnostic error:error]) {
    return nil;
  }

  // Actually launch the Application, getting the Process Info.
  pid_t processIdentifier = [self launchApplication:appLaunch stdOutPath:stdOutDiagnostic.asPath stdErrPath:stdErrDiagnostic.asPath error:&innerError];
  if (!processIdentifier) {
    return [[[[FBSimulatorError
      describeFormat:@"Failed to launch application %@", appLaunch]
      causedBy:innerError]
      inSimulator:simulator]
      fail:error];
  }

  process = [simulator.processFetcher.processFetcher processInfoFor:processIdentifier timeout:FBControlCoreGlobalConfiguration.regularTimeout];
  if (!process) {
    return [[[[FBSimulatorError
      describeFormat:@"Could not get Process Info for launched application process %d", processIdentifier]
      causedBy:innerError]
      inSimulator:simulator]
      fail:error];
  }
  [simulator.eventSink applicationDidLaunch:appLaunch didStart:process];

  // Report the diagnostics to the event sink.
  if (stdOutDiagnostic) {
    [simulator.eventSink diagnosticAvailable:stdOutDiagnostic];
  }
  if (stdErrDiagnostic) {
    [simulator.eventSink diagnosticAvailable:stdErrDiagnostic];
  }

  return process;
}

- (pid_t)launchApplication:(FBApplicationLaunchConfiguration *)appLaunch stdOutPath:(NSString *)stdOutPath stdErrPath:(NSString *)stdErrPath error:(NSError **)error
{
  NSAssert(NO, @"-[%@ %@] is abstract and should be overridden", NSStringFromClass(self.class), NSStringFromSelector(_cmd));
  return 0;
}

@end

@implementation FBApplicationLaunchStrategy_Bridge

- (pid_t)launchApplication:(FBApplicationLaunchConfiguration *)appLaunch stdOutPath:(NSString *)stdOutPath stdErrPath:(NSString *)stdErrPath error:(NSError **)error
{
  // The Bridge must be connected in order for the launch to work.
  NSError *innerError = nil;
  FBSimulator *simulator = self.simulator;
  FBSimulatorBridge *bridge = [[simulator connectWithError:&innerError] connectToBridge:&innerError];
  if (!bridge) {
    [[[FBSimulatorError
      describeFormat:@"Could not connect bridge to Simulator in order to launch application %@", appLaunch]
      causedBy:innerError]
      failUInt:error];
    return -1;
  }

  // Launch the Application.
  return [bridge
    launch:appLaunch
    stdOutPath:stdErrPath
    stdErrPath:stdOutPath
    error:&innerError];
}

@end

@implementation FBApplicationLaunchStrategy_CoreSimulator

- (pid_t)launchApplication:(FBApplicationLaunchConfiguration *)appLaunch stdOutPath:(NSString *)stdOutPath stdErrPath:(NSString *)stdErrPath error:(NSError **)error
{
  FBSimulator *simulator = self.simulator;
  NSDictionary<NSString *, id> *options = [appLaunch simDeviceLaunchOptionsWithStdOutPath:stdOutPath stdErrPath:stdErrPath];
  return [simulator.device launchApplicationWithID:appLaunch.bundleID options:options error:error];
}

@end
