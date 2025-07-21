#import "DelayUnit.h"
#import "DSPCore.h"
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
	DSPCore _core;
	uint8_t _uiData[UIFTHeight * UIFTWidth];
}

@synthesize parameterTree = _parameterTree;

- (UIFT)ft {
	os_unfair_lock_lock(&lock);
	int offset = _core.ftHead % UIFTHeight;
	uint8_t *ft = _core.ft;
	for (int i = 0; i < UIFTHeight; ++i) for (int j = 0; j < UIFTWidth; ++j)
		_uiData[i * UIFTWidth + j] = ft[((i + offset) % UIFTHeight) * UIFTWidth + j];
	os_unfair_lock_unlock(&lock);

	return (UIFT){.data = _uiData};
}

- (instancetype)initWithComponentDescription:(AudioComponentDescription)componentDescription options:(AudioComponentInstantiationOptions)options error:(NSError **)outError {
	self = [super initWithComponentDescription:componentDescription options:options error:outError];
	if (!self) return nil;

	AVAudioFormat *const inFmt = [AVAudioFormat.alloc initStandardFormatWithSampleRate:48000 channels:1];
	_inputBus = [AUAudioUnitBus.alloc initWithFormat:inFmt error:nil];

	AVAudioFormat *const outFmt = [AVAudioFormat.alloc initStandardFormatWithSampleRate:48000 channels:2];
	_outputBus = [AUAudioUnitBus.alloc initWithFormat:outFmt error:nil];

	_inputBusArray  = [AUAudioUnitBusArray.alloc initWithAudioUnit:self
														   busType:AUAudioUnitBusTypeInput
															busses:@[_inputBus]];
	_outputBusArray = [AUAudioUnitBusArray.alloc initWithAudioUnit:self
														   busType:AUAudioUnitBusTypeOutput
															busses:@[_outputBus]];

	_parameterTree = AUParameterTree.make;
	__block DSPCore *core = &_core;

	_parameterTree.implementorValueObserver = ^(AUParameter *param, AUValue value) {
		DSPCoreSetParameter(core, param.address, value);
	};
	_parameterTree.implementorValueProvider = ^(AUParameter *param) {
		return DSPCoreGetParameter(core, param.address);
	};
	_parameterTree.implementorStringFromValueCallback = ^(AUParameter *param, const AUValue *__nullable valuePtr) {
		AUValue value = valuePtr == nil ? param.value : *valuePtr;
		return [NSString stringWithFormat:@"%.f", value];
	};

	return self;
}

- (AUAudioFrameCount)maximumFramesToRender { return DSPCoreMaxFrames; }
- (void)setMaximumFramesToRender:(AUAudioFrameCount)maximumFramesToRender {}
- (AUAudioUnitBusArray *)inputBusses { return _inputBusArray; }
- (AUAudioUnitBusArray *)outputBusses { return _outputBusArray; }

- (BOOL)allocateRenderResourcesAndReturnError:(NSError **)outError {
	DSPCoreInit(&_core, _outputBus.format.sampleRate);

	for (AUParameter *param in _parameterTree.allParameters) {
		param.value = DSPCoreGetParameter(&_core, param.address);
	}

	return [super allocateRenderResourcesAndReturnError:outError];
}

- (void)deallocateRenderResources {
	DSPCoreDeinit(&_core);
	[super deallocateRenderResources];
}

- (AUInternalRenderBlock)internalRenderBlock {
	__block DSPCore *core = &_core;

	return ^AUAudioUnitStatus(AudioUnitRenderActionFlags 				*actionFlags,
							  const AudioTimeStamp       				*timestamp,
							  AVAudioFrameCount           				frameCount,
							  NSInteger                   				outputBusNumber,
							  AudioBufferList            				*outputData,
							  const AURenderEvent        				*realtimeEventListHead,
							  AURenderPullInputBlock __unsafe_unretained pullInput) {

		if (frameCount > DSPCoreMaxFrames) return kAudioUnitErr_TooManyFramesToProcess;
		if (!pullInput) return kAudioUnitErr_NoConnection;

		AudioBufferList input = { .mNumberBuffers = 1, .mBuffers = {{
			.mNumberChannels = 1,
			.mDataByteSize = frameCount * sizeof(float),
			.mData = core->buffer
		}}};
		AUAudioUnitStatus err = pullInput(actionFlags, timestamp, frameCount, 0, &input);
		if (err) return err;

		DSPCoreProcess(core,
					   (float *)input.mBuffers[0].mData,
					   (float *)outputData->mBuffers[0].mData,
					   (AUEventSampleTime)timestamp->mSampleTime,
					   frameCount);

		return noErr;
	};
}

@end
