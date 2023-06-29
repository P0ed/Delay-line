#pragma once

#import <AudioToolbox/AudioToolbox.h>
#import <algorithm>
#import <vector>
#import <span>

#import "Extension-Swift.h"
#import "ParameterAddresses.h"

class DSPKernel {
public:
    void initialize(int inputChannelCount, int outputChannelCount, double inSampleRate) {
        mSampleRate = inSampleRate;
    }

    void deInitialize() {}

    bool isBypassed() { return mBypassed; }
    void setBypass(bool shouldBypass) { mBypassed = shouldBypass; }

    void setParameter(AUParameterAddress address, AUValue value) {
        switch (address) {
			case ParameterAddress::hold: mHold = value; break;
			case ParameterAddress::gain: mGain = value; break;
        }
    }

    AUValue getParameter(AUParameterAddress address) {
        switch (address) {
			case ParameterAddress::hold: return (AUValue)mHold;
			case ParameterAddress::gain: return (AUValue)mGain;
            default: return 0;
        }
    }

    AUAudioFrameCount maximumFramesToRender() const {
        return mMaxFramesToRender;
    }

    void setMaximumFramesToRender(const AUAudioFrameCount &maxFrames) {
        mMaxFramesToRender = maxFrames;
    }

    void setMusicalContextBlock(AUHostMusicalContextBlock contextBlock) {
        mMusicalContextBlock = contextBlock;
    }

    void process(std::span<float const*> inputBuffers, std::span<float *> outputBuffers, AUEventSampleTime bufferStartTime, AUAudioFrameCount frameCount) {

		if (mBypassed) {
            for (UInt32 channel = 0; channel < inputBuffers.size(); ++channel) {
                std::copy_n(inputBuffers[channel], frameCount, outputBuffers[channel]);
            }
            return;
		} else {
			for (UInt32 channel = 0; channel < inputBuffers.size(); ++channel) {
				for (UInt32 frameIndex = 0; frameIndex < frameCount; ++frameIndex) {
					outputBuffers[channel][frameIndex] = inputBuffers[channel][frameIndex] * mGain;
				}
			}
		}
    }
    
    void handleOneEvent(AUEventSampleTime now, AURenderEvent const *event) {
        switch (event->head.eventType) {
			case AURenderEventParameter: return handleParameterEvent(now, event->parameter);
			default: return;
        }
    }

    void handleParameterEvent(AUEventSampleTime now, AUParameterEvent const& parameterEvent) {}

    AUHostMusicalContextBlock mMusicalContextBlock;

	double mSampleRate = 96000;
	AUValue mHold = 0;
	AUValue mGain = 1;
    bool mBypassed = false;
    AUAudioFrameCount mMaxFramesToRender = 1024;
};
