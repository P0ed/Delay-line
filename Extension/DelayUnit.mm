#import "DelayUnit.h"
#import "DSPKernel.hpp"
#import <CoreAudioKit/CoreAudioKit.h>
#import <AVFoundation/AVFoundation.h>
#import <os/lock.h>
#import "Extension-Swift.h"


@interface DelayUnit ()

@property (nonatomic, readwrite) AUParameterTree *parameterTree;
@property AUAudioUnitBusArray *inputBusArray;
@property AUAudioUnitBusArray *outputBusArray;
@property (nonatomic, readonly) AUAudioUnitBus *inputBus;
@property (nonatomic, readonly) AUAudioUnitBus *outputBus;
@property (nonatomic, readonly) AVAudioPCMBuffer *pcmBuffer;
@end

@implementation DelayUnit {
	DSPKernel _kernel;
	uint8_t _uiData[ftHeight * ftWidth];
	float _buffer[maxFrames];
}

@synthesize parameterTree = _parameterTree;

- (UIFT)ft {
	os_unfair_lock_lock(&lock);
	int offset = _kernel.ftOffset % ftHeight;
	uint8_t *ft = _kernel.ft;
	for (int i = 0; i < ftHeight; ++i) for (int j = 0; j < ftWidth; ++j)
		_uiData[i * ftWidth + j] = ft[((i + offset) % ftHeight) * ftWidth + j];
	os_unfair_lock_unlock(&lock);

	return (UIFT){
		.data = _uiData,
		.rows = ftHeight,
		.cols = ftWidth
	};
}

- (instancetype)initWithComponentDescription:(AudioComponentDescription)componentDescription options:(AudioComponentInstantiationOptions)options error:(NSError **)outError {
	self = [super initWithComponentDescription:componentDescription options:options error:outError];
	if (!self) return nil;

	auto const inFmt = [AVAudioFormat.alloc initStandardFormatWithSampleRate:48000 channels:1];
	_inputBus = [AUAudioUnitBus.alloc initWithFormat:inFmt error:nil];

	auto const outFmt = [AVAudioFormat.alloc initStandardFormatWithSampleRate:48000 channels:2];
	_outputBus = [AUAudioUnitBus.alloc initWithFormat:outFmt error:nil];

	_inputBusArray  = [AUAudioUnitBusArray.alloc initWithAudioUnit:self
														   busType:AUAudioUnitBusTypeInput
															busses:@[_inputBus]];
	_outputBusArray = [AUAudioUnitBusArray.alloc initWithAudioUnit:self
														   busType:AUAudioUnitBusTypeOutput
															busses:@[_outputBus]];

	[self setupParameterTree:AUParameterTree.make];

	return self;
}

- (void)setupParameterTree:(AUParameterTree *)parameterTree {
	_parameterTree = parameterTree;

	__block DSPKernel *kernel = &_kernel;

	_parameterTree.implementorValueObserver = ^(AUParameter *param, AUValue value) {
		kernel->setParameter(param.address, value);
	};
	_parameterTree.implementorValueProvider = ^(AUParameter *param) {
		return kernel->getParameter(param.address);
	};
	_parameterTree.implementorStringFromValueCallback = ^(AUParameter *param, const AUValue *__nullable valuePtr) {
		AUValue value = valuePtr == nil ? param.value : *valuePtr;
		return [NSString stringWithFormat:@"%.f", value];
	};
}

// MARK: AUAudioUnit Overrides
- (AUAudioFrameCount)maximumFramesToRender { return maxFrames; }
- (void)setMaximumFramesToRender:(AUAudioFrameCount)maximumFramesToRender {}
- (AUAudioUnitBusArray *)inputBusses { return _inputBusArray; }
- (AUAudioUnitBusArray *)outputBusses { return _outputBusArray; }

- (BOOL)allocateRenderResourcesAndReturnError:(NSError **)outError {
	const auto inputChannelCount = _inputBus.format.channelCount;
	const auto outputChannelCount = _outputBus.format.channelCount;
	_kernel.initialize(inputChannelCount, outputChannelCount, _outputBus.format.sampleRate);
	for (AUParameter *param in _parameterTree.allParameters) param.value = _kernel.getParameter(param.address);

	return [super allocateRenderResourcesAndReturnError:outError];
}

- (void)deallocateRenderResources {
	_kernel.deInitialize();
	[super deallocateRenderResources];
}

- (AUInternalRenderBlock)internalRenderBlock {
	__block DSPKernel *kernel = &_kernel;
	__block float *buffer = _buffer;

	return ^AUAudioUnitStatus(AudioUnitRenderActionFlags 				*actionFlags,
							  const AudioTimeStamp       				*timestamp,
							  AVAudioFrameCount           				frameCount,
							  NSInteger                   				outputBusNumber,
							  AudioBufferList            				*outputData,
							  const AURenderEvent        				*realtimeEventListHead,
							  AURenderPullInputBlock __unsafe_unretained pullInput) {

		if (frameCount > maxFrames) return kAudioUnitErr_TooManyFramesToProcess;
		if (!pullInput) return kAudioUnitErr_NoConnection;

		AudioBufferList input = { .mNumberBuffers = 1, .mBuffers = {{
			.mNumberChannels = 1,
			.mDataByteSize = UInt32(frameCount * sizeof(float)),
			.mData = buffer
		}}};
		AUAudioUnitStatus err = pullInput(actionFlags, timestamp, frameCount, 0, &input);
		if (err) return err;

		AUEventSampleTime now = AUEventSampleTime(timestamp->mSampleTime);
		kernel->process((float *)input.mBuffers[0].mData,
						(float *)outputData->mBuffers[0].mData,
						now,
						frameCount);

		return noErr;
	};
}

@end
