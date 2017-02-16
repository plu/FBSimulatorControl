// Copyright 2004-present Facebook. All Rights Reserved.

#import "FBFileDataConsumer.h"

#import "FBRunLoopSpinner.h"
#import "FBControlCoreError.h"
#import "FBLineBuffer.h"

@interface FBAwaitableFileDataConsumer ()

@property (nonatomic, strong, readonly) id<FBFileDataConsumer> consumer;
@property (atomic, assign, readwrite) BOOL hasConsumedEOF;

@end

@implementation FBAwaitableFileDataConsumer

+ (instancetype)consumerWithConsumer:(id<FBFileDataConsumer>)consumer
{
  return [[self alloc] initWithConsumer:consumer];
}

- (instancetype)initWithConsumer:(id<FBFileDataConsumer>)consumer
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _consumer = consumer;
  _hasConsumedEOF = NO;

  return self;
}

- (void)consumeData:(NSData *)data
{
  NSAssert(self.hasConsumedEOF == NO, @"Has already consumed End-of-File");
  [self.consumer consumeData:data];
}

- (void)consumeEndOfFile
{
  NSAssert(self.hasConsumedEOF == NO, @"Has already consumed End-of-File");
  self.hasConsumedEOF = YES;
}

- (BOOL)awaitEndOfFileWithTimeout:(NSTimeInterval)timeout error:(NSError **)error
{
  BOOL success = [NSRunLoop.currentRunLoop spinRunLoopWithTimeout:timeout untilTrue:^BOOL{
    return self.hasConsumedEOF;
  }];
  if (!success) {
    return [[FBControlCoreError
      describeFormat:@"Timeout waiting %f seconds for EOF", timeout]
      failBool:error];
  }
  return YES;
}

@end

@interface FBLineFileDataConsumer ()

@property (nonatomic, strong, nullable, readwrite) dispatch_queue_t queue;
@property (nonatomic, copy, nullable, readwrite) void (^consumer)(NSString *);
@property (nonatomic, strong, readwrite) FBLineBuffer *buffer;

@end

@implementation FBLineFileDataConsumer

+ (instancetype)lineReaderWithConsumer:(void (^)(NSString *))consumer
{
  dispatch_queue_t queue = dispatch_queue_create("com.facebook.FBControlCore.LineConsumer", DISPATCH_QUEUE_SERIAL);
  return [[self alloc] initWithQueue:queue consumer:consumer];
}

+ (instancetype)lineReaderWithQueue:(dispatch_queue_t)queue consumer:(void (^)(NSString *))consumer
{
  return [[self alloc] initWithQueue:queue consumer:consumer];
}

- (instancetype)initWithQueue:(dispatch_queue_t)queue consumer:(void (^)(NSString *))consumer
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _queue = queue;
  _consumer = consumer;
  _buffer = [FBLineBuffer new];

  return self;
}

- (void)consumeData:(NSData *)data
{
  @synchronized (self) {
    [self.buffer appendData:data];
    [self dispatchAvailableLines];
  }
}

- (void)consumeEndOfFile
{
  @synchronized (self) {
    [self dispatchAvailableLines];
    dispatch_async(self.queue, ^{
      self.consumer = nil;
      self.queue = nil;
      self.buffer = nil;
    });
  }
}

- (void)dispatchAvailableLines
{
  NSString *line = [self.buffer consumeLineString];
  while (line != nil) {
    void (^consumer)(NSString *) = self.consumer;
    dispatch_async(self.queue, ^{
      consumer(line);
    });
    line = [self.buffer consumeLineString];
  }
}

@end

@interface FBAccumilatingFileDataConsumer ()

@property (nonatomic, strong, nullable, readonly) NSMutableData *mutableData;
@property (nonatomic, copy, nullable, readonly) NSData *finalData;

@end

@implementation FBAccumilatingFileDataConsumer

- (instancetype)init
{
  return [self initWithMutableData:NSMutableData.data];
}

- (instancetype)initWithMutableData:(NSMutableData *)mutableData
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _mutableData = mutableData;
  return self;
}

- (void)consumeData:(NSData *)data
{
  NSAssert(self.finalData == nil, @"Cannot consume data when EOF has been consumed");
  @synchronized (self) {
    [self.mutableData appendData:data];
  }
}

- (void)consumeEndOfFile
{
  NSAssert(self.finalData == nil, @"Cannot consume EOF when EOF has been consumed");
  @synchronized (self) {
    _finalData = [self.mutableData copy];
    _mutableData = nil;
  }
}

- (NSData *)data
{
  @synchronized (self) {
    return self.finalData ?: [self.mutableData copy];
  }
}

@end

@interface FBCompositeFileDataConsumer ()

@property (nonatomic, copy, readonly) NSArray<id<FBFileDataConsumer>> *consumers;

@end

@implementation FBCompositeFileDataConsumer

+ (instancetype)consumerWithConsumers:(NSArray<id<FBFileDataConsumer>> *)consumers
{
  return [[self alloc] initWithConsumers:consumers];
}

- (instancetype)initWithConsumers:(NSArray<id<FBFileDataConsumer>> *)consumers
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _consumers = consumers;
  return self;
}

- (void)consumeData:(NSData *)data
{
  for (id<FBFileDataConsumer> consumer in self.consumers) {
    [consumer consumeData:data];
  }
}

- (void)consumeEndOfFile
{
  for (id<FBFileDataConsumer> consumer in self.consumers) {
    [consumer consumeEndOfFile];
  }
}

@end
