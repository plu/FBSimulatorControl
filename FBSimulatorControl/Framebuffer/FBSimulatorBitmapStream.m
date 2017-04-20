/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBSimulatorBitmapStream.h"

#import <FBControlCore/FBControlCore.h>
#import <IOSurface/IOSurface.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreVideo/CVPixelBufferIOSurface.h>

#import <SimulatorKit/SimDeviceFramebufferService.h>
#import <SimulatorKit/SimDeviceIOPortInterface-Protocol.h>
#import <SimulatorKit/SimDisplayIOSurfaceRenderable-Protocol.h>
#import <SimulatorKit/SimDisplayRenderable-Protocol.h>
#import <SimulatorKit/SimDeviceIOPortInterface-Protocol.h>
#import <SimulatorKit/SimDisplayDescriptorState-Protocol.h>
#import <SimulatorKit/SimDeviceIOPortConsumer-Protocol.h>
#import <SimulatorKit/SimDeviceIOPortDescriptorState-Protocol.h>
#import <SimulatorKit/SimDeviceIOPortInterface-Protocol.h>
#import <SimulatorKit/SimDisplayIOSurfaceRenderable-Protocol.h>
#import <SimulatorKit/SimDisplayRenderable-Protocol.h>

#import "FBSimulatorError.h"

static NSDictionary<NSString *, id> *FBBitmapStreamPixelBufferAttributesFromPixelBuffer(CVPixelBufferRef pixelBuffer);
static NSDictionary<NSString *, id> *FBBitmapStreamPixelBufferAttributesFromPixelBuffer(CVPixelBufferRef pixelBuffer)
{
  size_t width = CVPixelBufferGetWidth(pixelBuffer);
  size_t height = CVPixelBufferGetHeight(pixelBuffer);
  size_t frameSize = CVPixelBufferGetDataSize(pixelBuffer);
  size_t rowSize = CVPixelBufferGetBytesPerRow(pixelBuffer);
  OSType pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);
  NSString *pixelFormatString = (__bridge NSString *) UTCreateStringForOSType(pixelFormat);

  return @{
    @"width" : @(width),
    @"height" : @(height),
    @"row_size" : @(rowSize),
    @"frame_size" : @(frameSize),
    @"format" : pixelFormatString,
  };
}

@interface FBSimulatorBitmapStream ()

@property (nonatomic, weak, readonly) FBFramebufferSurface *surface;
@property (nonatomic, strong, readonly) id<FBControlCoreLogger> logger;

@property (nonatomic, strong, nullable, readwrite) id<FBFileConsumer> consumer;
@property (nonatomic, assign, nullable, readwrite) CVPixelBufferRef pixelBuffer;
@property (nonatomic, copy, nullable, readwrite) NSDictionary<NSString *, id> *pixelBufferAttributes;

@end

@implementation FBSimulatorBitmapStream

+ (instancetype)streamWithSurface:(FBFramebufferSurface *)surface logger:(id<FBControlCoreLogger>)logger
{
  return [[self alloc] initWithSurface:surface logger:logger];
}

- (instancetype)initWithSurface:(FBFramebufferSurface *)surface logger:(id<FBControlCoreLogger>)logger
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _surface = surface;
  _logger = logger;

  return self;
}

#pragma mark Public

- (nullable FBBitmapStreamAttributes *)streamAttributesWithError:(NSError **)error
{
  [self attachConsumerIfNeeded];
  NSDictionary<NSString *, id> *attributes = self.pixelBufferAttributes;
  if (!attributes) {
    return [[FBSimulatorError
      describe:@"Could not obtain stream attributes"]
      fail:error];
  }
  return [[FBBitmapStreamAttributes alloc] initWithAttributes:attributes];
}

- (BOOL)startStreaming:(id<FBFileConsumer>)consumer error:(NSError **)error
{
  if (self.consumer) {
    return [[FBSimulatorError
      describe:@"Cannot start streaming, a consumer is already attached"]
      failBool:error];
  }
  self.consumer = consumer;
  [self attachConsumerIfNeeded];
  return YES;
}

- (BOOL)stopStreamingWithError:(NSError **)error
{
  if (!self.consumer) {
    return [[FBSimulatorError
      describe:@"Cannot stop streaming, no consumer attached"]
      failBool:error];
  }
  if (![self.surface.attachedConsumers containsObject:self]) {
    return [[FBSimulatorError
      describe:@"Cannot stop streaming, is not attached to a surface"]
      failBool:error];
  }
  [self.surface detachConsumer:self];
  return YES;
}

#pragma mark Private

- (void)attachConsumerIfNeeded
{
  if ([self.surface.attachedConsumers containsObject:self]) {
    return;
  }
  [self.surface attachConsumer:self];
}

#pragma mark FBFramebufferRenderableConsumer

- (NSString *)consumerIdentifier
{
  return NSStringFromClass(self.class);
}

- (void)didChangeIOSurface:(nullable IOSurfaceRef)surface
{
  [self mountSurface:surface error:nil];
}

- (void)didReceiveDamageRect:(CGRect)rect
{
  if (!self.pixelBuffer || !self.consumer) {
    return;
  }
  [FBSimulatorBitmapStream writeBitmap:self.pixelBuffer consumer:self.consumer];
}

#pragma mark Private

- (BOOL)mountSurface:(IOSurfaceRef)surface error:(NSError **)error
{
  // Remove the old pixel buffer.
  CVPixelBufferRef oldBuffer = self.pixelBuffer;
  if (oldBuffer) {
    CVPixelBufferRelease(oldBuffer);
  }

  // Make a Buffer from the Surface
  CVPixelBufferRef buffer = NULL;
  CVReturn status = CVPixelBufferCreateWithIOSurface(
    NULL,
    surface,
    NULL,
    &buffer
  );
  if (status != kCVReturnSuccess) {
    return [[FBSimulatorError
      describeFormat:@"Failed to create Pixel Buffer from Surface with errorCode %d", status]
      failBool:error];
  }

  // Get the Attributes
  NSDictionary<NSString *, id> *attributes = FBBitmapStreamPixelBufferAttributesFromPixelBuffer(buffer);
  [self.logger logFormat:@"Mounting Surface with Attributes: %@", attributes];

  // Swap the pixel buffers.
  self.pixelBuffer = buffer;
  self.pixelBufferAttributes = attributes;

  return YES;
}

+ (void)writeBitmap:(CVPixelBufferRef)pixelBuffer consumer:(id<FBFileConsumer>)consumer
{
  CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);

  void *baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer);
  size_t size = CVPixelBufferGetDataSize(pixelBuffer);
  NSData *data = [NSData dataWithBytesNoCopy:baseAddress length:size freeWhenDone:NO];
  [consumer consumeData:data];

  CVPixelBufferUnlockBaseAddress(pixelBuffer,kCVPixelBufferLock_ReadOnly);
}

#pragma mark FBTerminationHandle

- (FBTerminationHandleType)type
{
  return FBTerminationHandleTypeVideoStreaming;
}

- (void)terminate
{
  [self stopStreamingWithError:nil];
}

@end
