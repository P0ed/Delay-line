#import <MetalKit/MetalKit.h>

@interface Renderer : NSObject<MTKViewDelegate>

- (nonnull instancetype)initWithDevice:(nonnull id <MTLDevice>)device format:(MTLPixelFormat)format;
- (void)loadTexture:(nonnull void *)data width:(int)width height:(int)height;
+ (UIImage *_Nonnull)img:(uint32_t const * _Nonnull)data;

@end
