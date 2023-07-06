@import MetalKit;

@interface AAPLRenderer : NSObject<MTKViewDelegate>

- (nonnull instancetype)initWithDevice:(nonnull id <MTLDevice>)device format:(MTLPixelFormat)format;

@end
