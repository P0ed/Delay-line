#pragma once

#import <AudioToolbox/AudioToolbox.h>
#import <algorithm>
#import <vector>
#import <span>

#import "Extension-Swift.h"
#import "ParameterAddresses.h"
#import "Buffer.hpp"

class DSPKernel {
private:
	AUHostMusicalContextBlock musicalContextBlock;

	int maxFrames = 1024;

	Buffer buffer = Buffer();
	Buffer line = Buffer();

	double sampleRate = 48000;
	AUValue hold = 0;
	AUValue speed = 1;
	AUValue targetSpeed = 1;

public:
	void initialize(int inputChannelCount, int outputChannelCount, double samplesPerSecond) {
		sampleRate = samplesPerSecond;
		int len = samplesPerSecond * 1;
		line.allocate(len);
		buffer.allocate(len);
	}
	void deInitialize() {
		line.deallocate();
		buffer.deallocate();
	}

	AUValue getParameter(AUParameterAddress address) {
		switch (address) {
			case ParameterAddress::hold: return hold;
			case ParameterAddress::speed: return targetSpeed;
			default: return 0;
		}
	}
	void setParameter(AUParameterAddress address, AUValue value) {
		switch (address) {
			case ParameterAddress::hold: hold = value; return;
			case ParameterAddress::speed: targetSpeed = value; return;
		}
	}

	int maximumFramesToRender() const { return maxFrames; }
	void setMaximumFramesToRender(const int &frames) { maxFrames = frames; }

	void setMusicalContextBlock(AUHostMusicalContextBlock block) { musicalContextBlock = block; }

	void process(std::span<float const*> in, std::span<float *> out, AUEventSampleTime startTime, int cnt) {
		for (int ch = 0; ch < in.size(); ++ch)
			line.read(Buffer(out[ch], cnt));

		for (int ch = 0; ch < in.size(); ++ch) if (!ch) {
			if (!hold) line.write(Buffer((float *)in[ch], cnt));
			line.offset += cnt;
		}

//		if (abs(targetSpeed - speed) > 0.02) speed = targetSpeed;
//		else speed += (targetSpeed - speed) * cnt / sampleRate;
	}

	void handleOneEvent(AUEventSampleTime now, AURenderEvent const *event) {
		if (event->head.eventType == AURenderEventParameter) handleParameterEvent(now, event->parameter);
	}
	void handleParameterEvent(AUEventSampleTime now, AUParameterEvent const& parameterEvent) {}
};
