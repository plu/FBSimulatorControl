/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBSimulatorVideoRecordingCommands.h"

#import "FBSimulator.h"
#import "FBSimulatorError.h"
#import "FBSimulator+Connection.h"
#import "FBSimulator+Framebuffer.h"
#import "FBFramebuffer.h"
#import "FBSimulatorVideo.h"
#import "FBFramebufferSurface.h"
#import "FBSimulatorBitmapStream.h"

FBTerminationHandleType const FBTerminationTypeHandleVideoStreaming = @"VideoStreaming";

@interface FBSimulatorVideoRecordingCommands ()

@property (nonatomic, weak, readonly) FBSimulator *simulator;

@end

@implementation FBSimulatorVideoRecordingCommands

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

#pragma mark FBVideoRecordingCommands Implementation

- (nullable id<FBVideoRecordingSession>)startRecordingToFile:(NSString *)filePath error:(NSError **)error
{
  NSError *innerError = nil;
  FBSimulatorVideo *video = [self obtainSimulatorVideoWithError:&innerError];
  if (!video) {
    return [FBSimulatorError failWithError:innerError errorOut:error];
  }
  if (![video startRecordingToFile:filePath timeout:FBControlCoreGlobalConfiguration.regularTimeout error:error]) {
    return nil;
  }
  return video;
}

- (BOOL)stopRecordingWithError:(NSError **)error
{
  NSError *innerError = nil;
  FBSimulatorVideo *video = [self obtainSimulatorVideoWithError:&innerError];
  if (!video) {
    return [FBSimulatorError failBoolWithError:innerError errorOut:error];
  }
  return [video stopRecordingWithTimeout:FBControlCoreGlobalConfiguration.regularTimeout error:error];
}

#pragma mark FBSimulatorStreamingCommands

- (nullable FBSimulatorBitmapStream *)createStreamWithError:(NSError **)error
{
  FBFramebufferSurface *surface = [self obtainSurfaceWithError:error];
  if (!surface) {
    return nil;
  }
  return [FBSimulatorBitmapStream streamWithSurface:surface logger:self.simulator.logger];
}

#pragma mark Private

- (FBSimulatorVideo *)obtainSimulatorVideoWithError:(NSError **)error
{
  NSError *innerError = nil;
  FBFramebuffer *framebuffer = [self.simulator framebufferWithError:&innerError];
  if (!framebuffer) {
    return [FBSimulatorError failWithError:innerError errorOut:error];
  }
  FBSimulatorVideo *video = framebuffer.video;
  if (!video) {
    return [[[FBSimulatorError
      describe:@"Simulator Does not have a FBSimulatorVideo instance"]
      inSimulator:self.simulator]
      fail:error];
  }
  return video;
}

- (FBFramebufferSurface *)obtainSurfaceWithError:(NSError **)error
{
  NSError *innerError = nil;
  FBFramebuffer *framebuffer = [self.simulator framebufferWithError:&innerError];
  if (!framebuffer) {
    return [FBSimulatorError failWithError:innerError errorOut:error];
  }
  FBFramebufferSurface *surface = framebuffer.surface;
  if (!surface) {
    return [[FBSimulatorError
      describe:@"Framebuffer does not have a surface"]
      fail:error];
  }
  return surface;
}

@end
