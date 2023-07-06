@import simd;
@import MetalKit;

#import "AAPLRenderer.h"
#import "AAPLShaderTypes.h"

@implementation AAPLRenderer {
    id<MTLDevice> _device;
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

- (id<MTLTexture>)loadTextureUsing:(float *)data width:(int)width height:(int)height {
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

- (instancetype)initWithMetalKitView:(MTKView *)mtkView {
    self = [super init];
	if (!self) return nil;

	_device = mtkView.device;

	float px[1] = { 0.5 };
	_texture = [self loadTextureUsing:px width:1 height:1];

	// Set up a simple MTLBuffer with vertices which include texture coordinates
	// Pixel positions, Texture coordinates
	static const AAPLVertex quadVertices[] = {
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
	_numVertices = sizeof(quadVertices) / sizeof(AAPLVertex);

	// Load the shaders from the default library
	id<MTLLibrary> defaultLibrary = [_device newDefaultLibrary];
	id<MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertexShader"];
	id<MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"samplingShader"];

	// Set up a descriptor for creating a pipeline state object
	MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
	pipelineStateDescriptor.label = @"Texturing Pipeline";
	pipelineStateDescriptor.vertexFunction = vertexFunction;
	pipelineStateDescriptor.fragmentFunction = fragmentFunction;
	pipelineStateDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat;

	NSError *error;
	_pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&error];

	_commandQueue = _device.newCommandQueue;

    return self;
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
                              atIndex:AAPLVertexInputIndexVertices];

        [renderEncoder setVertexBytes:&_viewportSize
                               length:sizeof(_viewportSize)
                              atIndex:AAPLVertexInputIndexViewportSize];

        // Set the texture object.  The AAPLTextureIndexBaseColor enum value corresponds
        ///  to the 'colorMap' argument in the 'samplingShader' function because its
        //   texture attribute qualifier also uses AAPLTextureIndexBaseColor for its index.
        [renderEncoder setFragmentTexture:_texture
                                  atIndex:AAPLTextureIndexBaseColor];

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

@end
