#import "DelayUnit.h"

#import <AVFoundation/AVFoundation.h>
#import <CoreAudioKit/CoreAudioKit.h>

#import "BufferedAudioBus.hpp"
#import "AUProcessHelper.hpp"
#import "DSPKernel.hpp"

@interface DelayUnit ()

@property (nonatomic, readwrite) AUParameterTree *parameterTree;
@property AUAudioUnitBusArray *inputBusArray;
@property AUAudioUnitBusArray *outputBusArray;
@property (nonatomic, readonly) AUAudioUnitBus *outputBus;
@end


@implementation DelayUnit {
	DSPKernel _kernel;
	BufferedInputBus _inputBus;
	std::unique_ptr<AUProcessHelper> _processHelper;
}

@synthesize parameterTree = _parameterTree;

- (instancetype)initWithComponentDescription:(AudioComponentDescription)componentDescription options:(AudioComponentInstantiationOptions)options error:(NSError **)outError {
	self = [super initWithComponentDescription:componentDescription options:options error:outError];
	if (!self) return nil;

	AVAudioFormat *format = [AVAudioFormat.alloc initStandardFormatWithSampleRate:48000 channels:2];
	_outputBus = [AUAudioUnitBus.alloc initWithFormat:format error:nil];
	_outputBus.maximumChannelCount = 8;

	_inputBus.init(format, 8);

	_inputBusArray  = [AUAudioUnitBusArray.alloc initWithAudioUnit:self
														   busType:AUAudioUnitBusTypeInput
															busses: @[_inputBus.bus]];
	_outputBusArray = [AUAudioUnitBusArray.alloc initWithAudioUnit:self
														   busType:AUAudioUnitBusTypeOutput
															busses: @[_outputBus]];

	[self setParameterTree:AUParameterTree.make];

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

#pragma mark - AUAudioUnit Overrides
- (AUAudioFrameCount)maximumFramesToRender { return _kernel.maximumFramesToRender(); }
- (void)setMaximumFramesToRender:(AUAudioFrameCount)maximumFramesToRender { _kernel.setMaximumFramesToRender(maximumFramesToRender); }

- (AUAudioUnitBusArray *)inputBusses { return _inputBusArray; }
- (AUAudioUnitBusArray *)outputBusses { return _outputBusArray; }

- (BOOL)allocateRenderResourcesAndReturnError:(NSError **)outError {
	const auto inputChannelCount = [self.inputBusses objectAtIndexedSubscript:0].format.channelCount;
	const auto outputChannelCount = [self.outputBusses objectAtIndexedSubscript:0].format.channelCount;

	if (outputChannelCount != inputChannelCount) {
		if (outError) {
			*outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:kAudioUnitErr_FailedInitialization userInfo:nil];
		}
		self.renderResourcesAllocated = NO;

		return NO;
	}
	_inputBus.allocateRenderResources(self.maximumFramesToRender);
	_kernel.setMusicalContextBlock(self.musicalContextBlock);

	_kernel.initialize(inputChannelCount, outputChannelCount, _outputBus.format.sampleRate);
	for (AUParameter *param in _parameterTree.allParameters) param.value = _kernel.getParameter(param.address);

	_processHelper = std::make_unique<AUProcessHelper>(_kernel, inputChannelCount, outputChannelCount);
	return [super allocateRenderResourcesAndReturnError:outError];
}

- (void)deallocateRenderResources {
	_kernel.deInitialize();
	[super deallocateRenderResources];
}

#pragma mark - AUAudioUnit (AUAudioUnitImplementation)
- (AUInternalRenderBlock)internalRenderBlock {
	__block DSPKernel *kernel = &_kernel;
	__block std::unique_ptr<AUProcessHelper> &processHelper = _processHelper;
	__block BufferedInputBus *input = &_inputBus;

	return ^AUAudioUnitStatus(AudioUnitRenderActionFlags 				*actionFlags,
							  const AudioTimeStamp       				*timestamp,
							  AVAudioFrameCount           				frameCount,
							  NSInteger                   				outputBusNumber,
							  AudioBufferList            				*outputData,
							  const AURenderEvent        				*realtimeEventListHead,
							  AURenderPullInputBlock __unsafe_unretained pullInputBlock) {

		AudioUnitRenderActionFlags pullFlags = 0;

		if (frameCount > kernel->maximumFramesToRender()) return kAudioUnitErr_TooManyFramesToProcess;

		AUAudioUnitStatus err = input->pullInput(&pullFlags, timestamp, frameCount, 0, pullInputBlock);
		if (err != 0) return err;

		processHelper->processWithEvents(input->mutableAudioBufferList, outputData, timestamp, frameCount, realtimeEventListHead);
		return noErr;
	};
}

@end
