/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBSimulatorTerminationStrategy.h"

#import <CoreSimulator/SimDevice.h>
#import <CoreSimulator/SimDeviceSet.h>
#import <CoreSimulator/SimDeviceType.h>
#import <CoreSimulator/SimRuntime.h>

#import <FBControlCore/FBControlCoreLogger.h>

#import <XCTestBootstrap/FBTestManager.h>

#import "FBCoreSimulatorNotifier.h"
#import "FBSimulator+Helpers.h"
#import "FBSimulator+Connection.h"
#import "FBSimulator+Private.h"
#import "FBSimulatorConnection.h"
#import "FBSimulatorConfiguration+CoreSimulator.h"
#import "FBSimulatorConfiguration.h"
#import "FBSimulatorControl.h"
#import "FBSimulatorControlConfiguration.h"
#import "FBSimulatorError.h"
#import "FBSimulatorPredicates.h"
#import "FBSimulatorShutdownStrategy.h"
#import "FBSimulatorProcessFetcher.h"
#import "FBSimulatorSet.h"

@interface FBSimulatorTerminationStrategy ()

@property (nonatomic, weak, readonly) FBSimulatorSet *set;
@property (nonatomic, copy, readonly) FBSimulatorControlConfiguration *configuration;
@property (nonatomic, strong, readonly) FBSimulatorProcessFetcher *processFetcher;
@property (nonatomic, strong, nullable, readonly) id<FBControlCoreLogger> logger;
@property (nonatomic, strong, readonly) FBProcessTerminationStrategy *processTerminationStrategy;

@end

@implementation FBSimulatorTerminationStrategy

#pragma mark Initialization

+ (instancetype)strategyForSet:(FBSimulatorSet *)set
{
  FBProcessTerminationStrategy *processTerminationStrategy = [FBProcessTerminationStrategy strategyWithProcessFetcher:set.processFetcher.processFetcher logger:set.logger];
  return [[self alloc] initWithSet:set configuration:set.configuration processFetcher:set.processFetcher processTerminationStrategy:processTerminationStrategy logger:set.logger];
}

- (instancetype)initWithSet:(FBSimulatorSet *)set configuration:(FBSimulatorControlConfiguration *)configuration processFetcher:(FBSimulatorProcessFetcher *)processFetcher processTerminationStrategy:(FBProcessTerminationStrategy *)processTerminationStrategy logger:(id<FBControlCoreLogger>)logger
{
  NSParameterAssert(processFetcher);
  NSParameterAssert(configuration);
  NSParameterAssert(processTerminationStrategy);

  self = [super init];
  if (!self) {
    return nil;
  }

  _set = set;
  _configuration = configuration;
  _processFetcher = processFetcher;
  _logger = logger;
  _processTerminationStrategy = processTerminationStrategy;

  return self;
}

#pragma mark Public Methods

- (nullable NSArray<FBSimulator *> *)killSimulators:(NSArray<FBSimulator *> *)simulators error:(NSError **)error;
{
  // Confirm that the Simulators belong to the set
  for (FBSimulator *simulator in simulators) {
    if (simulator.set != self.set) {
      return [[[FBSimulatorError
        describeFormat:@"Simulator's set %@ is not %@, cannot delete", simulator.set, self]
        inSimulator:simulator]
        fail:error];
    }
  }

  // It looks like there is a bug with El Capitan, where terminating multiple Applications quickly
  // can result in the dock getting into an inconsistent state displaying icons for terminated Applications.
  //
  // This happens regardless of how the Application was terminated.
  // The process backing the terminated Application is definitely gone, but the dock icon isn't.
  // The Application appears in the Force Quit menu, but cannot ever be quit by conventional means.
  // Attempting to shutdown the Mac will result in hanging (probably because it can't terminate the App).
  //
  // The only remedy is to quit 'launchservicesd' followed by 'Dock.app'.
  // This will clear up the stale state that must exist in the Dock/launchservicesd.
  // Waiting after killing of processes by a short period of time is sufficient to mitigate this issue.
  // Since `-[FBSimDeviceWrapper shutdownWithError:]` will spin the run loop until CoreSimulator confirms that the device is shutdown,
  // this will give a sufficient amount of time between killing Applications.

  [self.logger.debug logFormat:@"Killing %@", [FBCollectionInformation oneLineDescriptionFromArray:simulators atKeyPath:@"shortDescription"]];
  for (FBSimulator *simulator in simulators) {
    // Get some preconditions
    NSError *innerError = nil;
    FBProcessInfo *launchdProcess = simulator.launchdProcess ?: [self.processFetcher launchdProcessForSimDevice:simulator.device];

    // The Simulator Connection for this process should be tidied up first.
    if (![simulator disconnectWithTimeout:FBControlCoreGlobalConfiguration.regularTimeout logger:self.logger error:&innerError]) {
      return [[[[[FBSimulatorError
        describe:@"Could disconnect from Simulator"]
        inSimulator:simulator]
        causedBy:innerError]
        logger:self.logger]
        fail:error];
    }

    // Disconnect any Test Managers connected to the Simulator.
    // If a TestManager Deallocates during the shutdown of a Simulator, the calling thread can deadlock.
    for (FBTestManager *testManager in simulator.resourceSink.testManagers) {
      [testManager disconnect];
      [simulator.eventSink testmanagerDidDisconnect:testManager];
    }

    // Kill the Simulator.app Process first, see documentation in `-[FBSimDeviceWrapper shutdownWithError:]`.
    // This prevents 'Zombie' Simulator.app from existing.
    FBProcessInfo *simulatorProcess = simulator.containerApplication ?: [self.processFetcher simulatorApplicationProcessForSimDevice:simulator.device];
    if (simulatorProcess) {
      [self.logger.debug logFormat:@"Simulator %@ has a Simulator.app Process %@, terminating it now", simulator.shortDescription, simulatorProcess];
      if (![self.processTerminationStrategy killProcess:simulatorProcess error:&innerError]) {
        return [[[[[FBSimulatorError
          describeFormat:@"Could not kill simulator process %@", simulatorProcess]
          inSimulator:simulator]
          causedBy:innerError]
          logger:self.logger]
          fail:error];
      }
      [simulator.eventSink containerApplicationDidTerminate:simulatorProcess expected:YES];
    } else {
      [self.logger.debug logFormat:@"Simulator %@ does not have a running Simulator.app Process", simulator.shortDescription];
    }

    // Shutdown will:
    // 1) Wait for a Simulator launched via Simulator.app to be in a consistent 'Shutdown' state.
    // 2) Shutdown a SimDevice that has been launched directly via. `-[SimDevice bootWithOptions:error]`.
    if (![[FBSimulatorShutdownStrategy strategyWithSimulator:simulator] shutdownWithError:&innerError]) {
      return [[[[[FBSimulatorError
        describe:@"Could not shut down simulator after termination"]
        inSimulator:simulator]
        causedBy:innerError]
        logger:self.logger]
        fail:error];
    }
    if (launchdProcess) {
      [simulator.eventSink simulatorDidTerminate:launchdProcess expected:YES];
    }
  }
  return simulators;
}

- (BOOL)killSpuriousSimulatorsWithError:(NSError **)error
{
  NSPredicate *predicate = [NSCompoundPredicate notPredicateWithSubpredicate:
    [NSCompoundPredicate andPredicateWithSubpredicates:@[
      [FBSimulatorProcessFetcher simulatorsProcessesLaunchedUnderConfiguration:self.configuration],
      [FBSimulatorProcessFetcher simulatorApplicationProcessesLaunchedBySimulatorControl]
    ]
  ]];

  NSError *innerError = nil;
  if (![self killSimulatorProcessesMatchingPredicate:predicate error:&innerError]) {
    return [[[[FBSimulatorError
      describe:@"Could not kill spurious simulators"]
      causedBy:innerError]
      logger:self.logger]
      failBool:error];
  }

  return YES;
}

#pragma mark Private

- (BOOL)killSimulatorProcessesMatchingPredicate:(NSPredicate *)predicate error:(NSError **)error
{
  NSArray *processes = [self.processFetcher.simulatorApplicationProcesses filteredArrayUsingPredicate:predicate];
  for (FBProcessInfo *process in processes) {
    NSParameterAssert(process.processIdentifier > 1);
    if (![self.processTerminationStrategy killProcess:process error:error]) {
      return NO;
    }
    // See comment in `killSimulators:withError:`
    sleep(1);
  }
  return YES;
}

@end
