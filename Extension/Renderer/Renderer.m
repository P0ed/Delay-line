@import simd;
@import MetalKit;

#import "Renderer.h"
#import "ShaderTypes.h"

@implementation Renderer {
    id<MTLDevice> _device;
	MTLPixelFormat _format;
    id<MTLRenderPipelineState> _pipelineState;
    id<MTLCommandQueue> _commandQueue;

    // The Metal texture object
    id<MTLTexture> _texture;

    // The Metal buffer that holds the vertex data.
    id<MTLBuffer> _vertices;

    // The number of vertices in the vertex buffer.
    NSUInteger _numVertices;

    // The current size of the view.
    vector_uint2 _viewportSize;
}

- (nonnull instancetype)initWithDevice:(nonnull id <MTLDevice>)device format:(MTLPixelFormat)format {
    self = [super init];
	if (!self) return nil;

	_device = device;
	_format = format;

	float px[1] = { 0.5 };
	_texture = [self loadTextureUsing:px width:1 height:1];

	// Set up a simple MTLBuffer with vertices which include texture coordinates
	// Pixel positions, Texture coordinates
	static const Vertex quadVertices[] = {
		{ {  250,  -250 },  { 1.f, 1.f } },
		{ { -250,  -250 },  { 0.f, 1.f } },
		{ { -250,   250 },  { 0.f, 0.f } },

		{ {  250,  -250 },  { 1.f, 1.f } },
		{ { -250,   250 },  { 0.f, 0.f } },
		{ {  250,   250 },  { 1.f, 0.f } },
	};

	// Create a vertex buffer, and initialize it with the quadVertices array
	_vertices = [_device newBufferWithBytes:quadVertices
									 length:sizeof(quadVertices)
									options:MTLResourceStorageModeShared];

	// Calculate the number of vertices by dividing the byte length by the size of each vertex
	_numVertices = sizeof(quadVertices) / sizeof(Vertex);

	id<MTLLibrary> defaultLibrary = [_device newDefaultLibrary];
	id<MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertexShader"];
	id<MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"samplingShader"];

	MTLRenderPipelineDescriptor *pipelineStateDescriptor = [MTLRenderPipelineDescriptor.alloc init];
	pipelineStateDescriptor.label = @"Texturing Pipeline";
	pipelineStateDescriptor.vertexFunction = vertexFunction;
	pipelineStateDescriptor.fragmentFunction = fragmentFunction;
	pipelineStateDescriptor.colorAttachments[0].pixelFormat = _format;

	NSError *error;
	_pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&error];

	_commandQueue = _device.newCommandQueue;

    return self;
}

- (void)loadTexture:(void *)data width:(int)width height:(int)height {
	_texture = [self loadTextureUsing:data width:width height:height];
}

- (id<MTLTexture>)loadTextureUsing:(void *)data width:(int)width height:(int)height {
	MTLTextureDescriptor *textureDescriptor = [MTLTextureDescriptor.alloc init];
	textureDescriptor.pixelFormat = MTLPixelFormatR32Float;
	textureDescriptor.width = width;
	textureDescriptor.height = height;

	id<MTLTexture> texture = [_device newTextureWithDescriptor:textureDescriptor];

	NSUInteger bytesPerRow = 4 * width;

	MTLRegion region = {
		{ 0, 0, 0 },			// MTLOrigin
		{width, height, 1}		// MTLSize
	};

	[texture replaceRegion:region
				mipmapLevel:0
				  withBytes:data
				bytesPerRow:bytesPerRow];

	return texture;
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
    _viewportSize.x = size.width;
    _viewportSize.y = size.height;
}

- (void)drawInMTKView:(nonnull MTKView *)view {
    id<MTLCommandBuffer> commandBuffer = _commandQueue.commandBuffer;
    commandBuffer.label = @"MyCommand";

    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;

    if (renderPassDescriptor != nil) {
        id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        renderEncoder.label = @"MyRenderEncoder";

        [renderEncoder setViewport:(MTLViewport){0.0, 0.0, _viewportSize.x, _viewportSize.y, -1.0, 1.0 }];

        [renderEncoder setRenderPipelineState:_pipelineState];

        [renderEncoder setVertexBuffer:_vertices
                                offset:0
                              atIndex:VertexInputIndexVertices];

        [renderEncoder setVertexBytes:&_viewportSize
                               length:sizeof(_viewportSize)
                              atIndex:VertexInputIndexViewportSize];

        // Set the texture object.  The TextureIndexBaseColor enum value corresponds
        ///  to the 'colorMap' argument in the 'samplingShader' function because its
        //   texture attribute qualifier also uses TextureIndexBaseColor for its index.
        [renderEncoder setFragmentTexture:_texture
                                  atIndex:TextureIndexBaseColor];

        // Draw the triangles.
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                          vertexStart:0
                          vertexCount:_numVertices];

        [renderEncoder endEncoding];

        // Schedule a present once the framebuffer is complete using the current drawable
        [commandBuffer presentDrawable:view.currentDrawable];
    }

    // Finalize rendering here & push the command buffer to the GPU
    [commandBuffer commit];
}

+ (UIImage *)img:(uint32_t const *)data {
	CGColorSpaceRef color = CGColorSpaceCreateDeviceRGB();
	CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, data, 512 * 1024 * 4, NULL);

	CGImageRef img = CGImageCreate(512, 1024, 8, 32, 512 * 4, CGColorSpaceCreateDeviceRGB(), kCGBitmapByteOrderDefault | kCGImageAlphaFirst, provider, NULL, false, kCGRenderingIntentDefault);

	CGDataProviderRelease(provider);
	CGColorSpaceRelease(color);

	UIImage *image = [UIImage imageWithCGImage:img];
	CGImageRelease(img);

	return image;
}

@end

