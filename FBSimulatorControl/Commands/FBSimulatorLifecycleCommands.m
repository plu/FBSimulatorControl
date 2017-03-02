/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBSimulatorLifecycleCommands.h"

#import <CoreSimulator/SimDevice.h>

#import <FBControlCore/FBControlCore.h>

#import <SimulatorKit/SimDeviceFramebufferService.h>

#import "FBSimulator+Helpers.h"
#import "FBSimulator.h"
#import "FBSimulatorBootStrategy.h"
#import "FBSimulatorConnection.h"
#import "FBSimulatorConfiguration+CoreSimulator.h"
#import "FBSimulatorConfiguration.h"
#import "FBSimulatorControl.h"
#import "FBSimulatorControlConfiguration.h"
#import "FBSimulatorSubprocessTerminationStrategy.h"
#import "FBSimulatorError.h"
#import "FBSimulatorEventSink.h"
#import "FBSimulatorBootConfiguration.h"
#import "FBSimulatorPool.h"
#import "FBSimulatorTerminationStrategy.h"

@interface FBSimulatorLifecycleCommands ()

@property (nonatomic, weak, readonly) FBSimulator *simulator;

@end

@implementation FBSimulatorLifecycleCommands

+ (instancetype)commandsWithSimulator:(FBSimulator *)simulator
{
  return [[self alloc] initWithSimulator:simulator];
}

- (instancetype)initWithSimulator:(FBSimulator *)simulator
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _simulator = simulator;
  return self;
}

- (BOOL)bootSimulatorWithError:(NSError **)error
{
  return [self bootSimulator:FBSimulatorBootConfiguration.defaultConfiguration error:error];
}

- (BOOL)bootSimulator:(FBSimulatorBootConfiguration *)configuration error:(NSError **)error
{
  return [[FBSimulatorBootStrategy
    strategyWithConfiguration:configuration simulator:self.simulator]
    boot:error];
}

- (BOOL)shutdownSimulatorWithError:(NSError **)error
{
  return [self.simulator.set killSimulator:self.simulator error:error];
}

- (BOOL)openURL:(NSURL *)url error:(NSError **)error
{
  NSParameterAssert(url);
  NSError *innerError = nil;
  if (![self.simulator.device openURL:url error:&innerError]) {
    return [[[FBSimulatorError
      describeFormat:@"Failed to open URL %@ on simulator %@", url, self.simulator]
      causedBy:innerError]
      failBool:error];
  }
  return YES;
}

- (BOOL)terminateSubprocess:(FBProcessInfo *)process error:(NSError **)error
{
  NSParameterAssert(process);
    return [[FBSimulatorSubprocessTerminationStrategy
      strategyWithSimulator:self.simulator]
      terminate:process error:error];
}

@end
