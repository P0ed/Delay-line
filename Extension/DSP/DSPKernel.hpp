#pragma once

#import <AudioToolbox/AudioToolbox.h>
#import <algorithm>
#import <vector>
#import <span>

#import "Extension-Swift.h"
#import "ParameterAddresses.h"

class DSPKernel {
private:
	AUHostMusicalContextBlock musicalContextBlock;

	float *line = nullptr;
	AUEventSampleTime offset = 0;
	AUEventSampleTime readOffset = 48000;
	AUAudioFrameCount length = 0;

	double sampleRate = 48000;
	AUValue hold = 0;
	AUValue zone = 0;
	AUValue feedback = 0;

	bool bypassed = false;

	AUAudioFrameCount maxFrames = 1024;
	float *buf = new float[maxFrames];

	void write(const float *samples, AUAudioFrameCount cnt) {
		offset = offset + this->offset;
		for (auto i = offset; i < offset + cnt; ++i) line[i % length] = samples[i % length];
		this->offset = (this->offset + cnt) % length;
	}

	float sampleAt(AUEventSampleTime idx) { return line[(idx + offset + readOffset) % length]; }

public:
	void initialize(int inputChannelCount, int outputChannelCount, double samplesPerSecond) {
		sampleRate = samplesPerSecond;
		length = int(samplesPerSecond * 4);
		line = new float[length];
		offset = 0;
	}
	void deInitialize() {
		delete[] line;
		line = nullptr;
		delete[] buf;
		buf = nullptr;
	}

	AUValue getParameter(AUParameterAddress address) {
		switch (address) {
			case ParameterAddress::hold: return hold;
			case ParameterAddress::feedback: return feedback;
			default: return 0;
		}
	}
	void setParameter(AUParameterAddress address, AUValue value) {
		switch (address) {
			case ParameterAddress::hold: hold = value; return;
			case ParameterAddress::feedback: feedback = value; return;
		}
	}

	bool isBypassed() { return bypassed; }
	void setBypass(bool shouldBypass) { bypassed = shouldBypass; }
	AUAudioFrameCount maximumFramesToRender() const { return maxFrames; }
	void setMaximumFramesToRender(const AUAudioFrameCount &frames) {
		maxFrames = frames;
		delete[] buf;
		buf = new float[maxFrames];
	}
	void setMusicalContextBlock(AUHostMusicalContextBlock block) { musicalContextBlock = block; }

	void process(std::span<float const*> in, std::span<float *> out, AUEventSampleTime startTime, AUAudioFrameCount cnt) {
		if (bypassed) {
			for (auto channel = 0; channel < in.size(); ++channel) {
				std::copy_n(in[channel], cnt, out[channel]);
			}
		} else {
			for (auto channel = 0; channel < in.size(); ++channel) {

				for (auto idx = 0; idx < cnt; ++idx)
					out[channel][idx] = sampleAt(idx);

				if (!channel) {
					if (hold) {
						offset += cnt;
					} else {
						for (auto idx = 0; idx < cnt; ++idx)
							buf[idx] = sampleAt(idx) + in[channel][idx] * feedback;
						write(buf, cnt);
					}
				}
			}
		}
	}

	void handleOneEvent(AUEventSampleTime now, AURenderEvent const *event) {
		if (event->head.eventType == AURenderEventParameter) handleParameterEvent(now, event->parameter);
	}
	void handleParameterEvent(AUEventSampleTime now, AUParameterEvent const& parameterEvent) {}
};
