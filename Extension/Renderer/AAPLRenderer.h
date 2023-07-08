#import <MetalKit/MetalKit.h>

@interface AAPLRenderer : NSObject<MTKViewDelegate>

- (nonnull instancetype)initWithDevice:(nonnull id <MTLDevice>)device format:(MTLPixelFormat)format;
- (void)loadTexture:(nonnull void *)data width:(int)width height:(int)height;
- (UIImage *)img:(void *)data;

@end
