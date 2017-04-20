/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBLogicTestRunner.h"

#import <sys/types.h>
#import <sys/stat.h>

#import <FBControlCore/FBControlCore.h>
#import <FBSimulatorControl/FBSimulatorControl.h>

#import "FBXCTestConfiguration.h"
#import "FBXCTestReporter.h"
#import "FBXCTestError.h"
#import "FBXCTestLogger.h"
#import "FBXCTestShimConfiguration.h"
#import "FBXCTestDestination.h"
#import "FBLogicTestProcess.h"

@interface FBLogicTestRunner ()

@property (nonatomic, strong, nullable, readonly) FBSimulator *simulator;
@property (nonatomic, strong, readonly) FBLogicTestConfiguration *configuration;

@end

@implementation FBLogicTestRunner

+ (instancetype)withSimulator:(nullable FBSimulator *)simulator configuration:(FBLogicTestConfiguration *)configuration
{
  return [[self alloc] initWithSimulator:simulator configuration:configuration];
}

- (instancetype)initWithSimulator:(nullable FBSimulator *)simulator configuration:(FBLogicTestConfiguration *)configuration
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _simulator = simulator;
  _configuration = configuration;

  return self;
}

- (BOOL)runTestsWithError:(NSError **)error
{
  FBSimulator *simulator = self.simulator;

  [self.configuration.reporter didBeginExecutingTestPlan];

  NSString *xctestPath = self.configuration.destination.xctestPath;
  NSString *otestShimPath = simulator ? self.configuration.shims.iOSSimulatorOtestShimPath : self.configuration.shims.macOtestShimPath;

  // The fifo is used by the shim to report events from within the xctest framework.
  NSString *otestShimOutputPath = [self.configuration.workingDirectory stringByAppendingPathComponent:@"shim-output-pipe"];
  if (mkfifo(otestShimOutputPath.UTF8String, S_IWUSR | S_IRUSR) != 0) {
    NSError *posixError = [[NSError alloc] initWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
    return [[[FBXCTestError describeFormat:@"Failed to create a named pipe %@", otestShimOutputPath] causedBy:posixError] failBool:error];
  }

  // The environment requires the shim path and otest-shim path.
  NSMutableDictionary<NSString *, NSString *> *environment = [NSMutableDictionary dictionaryWithDictionary:@{
    @"DYLD_INSERT_LIBRARIES": otestShimPath,
    @"OTEST_SHIM_STDOUT_FILE": otestShimOutputPath,
  }];
  [environment addEntriesFromDictionary:self.configuration.processUnderTestEnvironment];

  // Get the Launch Path and Arguments for the xctest process.
  NSString *testSpecifier = self.configuration.testFilter ?: @"All";
  NSString *launchPath = xctestPath;
  NSArray<NSString *> *arguments = @[@"-XCTest", testSpecifier, self.configuration.testBundlePath];

  // Consumes the test output. Separate Readers are used as consuming an EOF will invalidate the reader.
  NSUUID *uuid = [NSUUID UUID];
  dispatch_queue_t queue = dispatch_get_main_queue();
  id<FBFileConsumer> stdOutReader = [FBLineFileConsumer asynchronousReaderWithQueue:queue consumer:^(NSString *line){
    [self.configuration.reporter testHadOutput:[line stringByAppendingString:@"\n"]];
  }];
  stdOutReader = [self.configuration.logger logConsumptionToFile:stdOutReader outputKind:@"out" udid:uuid];
  id<FBFileConsumer> stdErrReader = [FBLineFileConsumer asynchronousReaderWithQueue:queue consumer:^(NSString *line){
    [self.configuration.reporter testHadOutput:[line stringByAppendingString:@"\n"]];
  }];
  stdErrReader = [self.configuration.logger logConsumptionToFile:stdErrReader outputKind:@"err" udid:uuid];
  // Consumes the shim output.
  id<FBFileConsumer> otestShimLineReader = [FBLineFileConsumer asynchronousReaderWithQueue:queue consumer:^(NSString *line){
    if ([line length] == 0) {
      return;
    }
    NSDictionary *event = [NSJSONSerialization JSONObjectWithData:[line dataUsingEncoding:NSUTF8StringEncoding] options:0 error:error];
    if (event == nil) {
      [self.configuration.logger logFormat:@"Received unexpected output from otest-shim:\n%@", line];
    }
    [self.configuration.reporter handleExternalEvent:event];
  }];
  otestShimLineReader = [self.configuration.logger logConsumptionToFile:otestShimLineReader outputKind:@"shim" udid:uuid];

  FBLogicTestProcess *process = simulator
    ? [FBLogicTestProcess
        simulatorSpawnProcess:simulator
        launchPath:launchPath
        arguments:arguments
        environment:[self.configuration buildEnvironmentWithEntries:environment]
        waitForDebugger:self.configuration.waitForDebugger
        stdOutReader:stdOutReader
        stdErrReader:stdErrReader]
    : [FBLogicTestProcess
        taskProcessWithLaunchPath:launchPath
        arguments:arguments
        environment:[self.configuration buildEnvironmentWithEntries:environment]
        waitForDebugger:self.configuration.waitForDebugger
        stdOutReader:stdOutReader
        stdErrReader:stdErrReader];

  // Start the process
  pid_t pid = [process startWithError:error];
  if (!pid) {
    return NO;
  }

  if (self.configuration.waitForDebugger) {
    [self.configuration.reporter processWaitingForDebuggerWithProcessIdentifier:pid];
    // If wait_for_debugger is passed, the child process receives SIGSTOP after immediately launch.
    // We wait until it receives SIGCONT from an attached debugger.
    waitid(P_PID, (id_t)pid, NULL, WCONTINUED);
    [self.configuration.reporter debuggerAttached];
  }

  // Create a reader of the otest-shim path and start reading it.
  NSError *innerError = nil;
  FBFileReader *otestShimReader = [FBFileReader readerWithFilePath:otestShimOutputPath consumer:otestShimLineReader error:&innerError];
  if (!otestShimReader) {
    [process terminate];
    return [[[FBXCTestError
      describeFormat:@"Failed to open fifo for reading: %@", otestShimOutputPath]
      causedBy:innerError]
      failBool:error];
  }
  if (![otestShimReader startReadingWithError:&innerError]) {
    [process terminate];
    return [[[FBXCTestError
      describeFormat:@"Failed to start reading fifo: %@", otestShimOutputPath]
      causedBy:innerError]
      failBool:error];
  }

  // Wait for the test process to finish.
  if (![process waitForCompletionWithTimeout:self.configuration.testTimeout error:error]) {
    return NO;
  }

  // Fail if we can't close.
  if (![otestShimReader stopReadingWithError:&innerError]) {
    return [[[FBXCTestError
      describeFormat:@"Failed to stop reading fifo: %@", otestShimOutputPath]
      causedBy:innerError]
      failBool:error];
  }

  [self.configuration.reporter didFinishExecutingTestPlan];

  return YES;
}

@end
