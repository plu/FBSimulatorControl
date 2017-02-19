/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBFileWriter.h"

#import "FBControlCoreError.h"

@interface FBFileWriter ()

@property (nonatomic, strong, readonly) NSFileHandle *fileHandle;
@property (nonatomic, strong, readonly) dispatch_queue_t writeQueue;

@end

@implementation FBFileWriter

+ (instancetype)writerWithFileHandle:(NSFileHandle *)fileHandle
{
  return [[self alloc] initWithFileHandle:fileHandle];
}

- (instancetype)initWithFileHandle:(NSFileHandle *)fileHandle
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _fileHandle = fileHandle;
  _writeQueue = dispatch_queue_create("com.facebook.fbcontrolcore.fbfilewriter", DISPATCH_QUEUE_SERIAL);

  return self;
}

#pragma mark FBFileDataConsumer Implementation

- (void)consumeData:(NSData *)data
{
  NSFileHandle *fileHandle = self.fileHandle;
  dispatch_async(self.writeQueue, ^{
    [fileHandle writeData:data];
  });
}

- (void)consumeEndOfFile
{
  NSFileHandle *fileHandle = self.fileHandle;
  dispatch_async(self.writeQueue, ^{
    [fileHandle closeFile];
  });
}

@end
