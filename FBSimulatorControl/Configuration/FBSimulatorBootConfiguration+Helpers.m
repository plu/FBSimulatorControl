/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBSimulatorBootConfiguration+Helpers.h"

#import <CoreSimulator/SimDevice.h>
#import <CoreSimulator/SimDeviceSet.h>

#import <FBControlCore/FBControlCore.h>

#import "FBSimulator.h"
#import "FBSimulatorControlConfiguration.h"
#import "FBSimulatorError.h"
#import "FBSimulatorPool.h"
#import "FBSimulatorSet.h"
#import "FBSimulatorScale.h"

@implementation FBSimulatorBootConfiguration (Helpers)

- (NSArray<NSString *> *)xcodeSimulatorApplicationArgumentsForSimulator:(FBSimulator *)simulator error:(NSError **)error
{
  // These arguments are based on the NSUserDefaults that are serialized for the Simulator.app.
  // These can be seen with `defaults read com.apple.iphonesimulator` and has default location of ~/Library/Preferences/com.apple.iphonesimulator.plist
  // NSUserDefaults for any application can be overriden in the NSArgumentDomain:
  // https://developer.apple.com/library/ios/documentation/Cocoa/Conceptual/UserDefaults/AboutPreferenceDomains/AboutPreferenceDomains.html#//apple_ref/doc/uid/10000059i-CH2-96930
  NSMutableArray<NSString *> *arguments = [NSMutableArray arrayWithArray:@[
    @"--args",
    @"-CurrentDeviceUDID", simulator.udid,
    @"-ConnectHardwareKeyboard", @"0",
  ]];
  NSString *scale = self.scale;
  if (scale) {
    [arguments addObjectsFromArray:@[
      [self lastScaleCommandLineSwitchForSimulator:simulator], scale,
    ]];
  }

  NSString *setPath = simulator.set.deviceSet.setPath;
  if (setPath) {
    if (!FBControlCoreGlobalConfiguration.supportsCustomDeviceSets) {
      return [[[FBSimulatorError describe:@"Cannot use custom Device Set on current platform"] inSimulator:simulator] fail:error];
    }
    [arguments addObjectsFromArray:@[@"-DeviceSetPath", setPath]];
  }
  return [arguments copy];
}

- (BOOL)shouldUseDirectLaunch
{
  return (self.options & FBSimulatorBootOptionsEnableDirectLaunch) == FBSimulatorBootOptionsEnableDirectLaunch;
}

- (BOOL)shouldUsePersistentLaunch
{
  return (self.options & FBSimulatorBootOptionsEnablePersistentLaunch) == FBSimulatorBootOptionsEnablePersistentLaunch;
}

- (BOOL)shouldConnectFramebuffer
{
  return self.framebuffer != nil;
}

- (BOOL)shouldLaunchViaWorkspace
{
  return (self.options & FBSimulatorBootOptionsUseNSWorkspace) == FBSimulatorBootOptionsUseNSWorkspace;
}

- (BOOL)shouldConnectBridge
{
  return ((self.options & FBSimulatorBootOptionsConnectBridge) == FBSimulatorBootOptionsConnectBridge) || self.shouldUseDirectLaunch || self.shouldUsePersistentLaunch;
}

#pragma mark Scale

- (NSString *)lastScaleCommandLineSwitchForSimulator:(FBSimulator *)simulator
{
  return [NSString stringWithFormat:@"-SimulatorWindowLastScale-%@", simulator.device.deviceTypeIdentifier];
}

@end
