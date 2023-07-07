#pragma once

#import <AudioToolbox/AudioToolbox.h>
#import <algorithm>
#import <vector>
#import <span>
#import <Accelerate/Accelerate.h>

#import "Extension-Swift.h"
#import "ParameterAddresses.h"
#import "Buffer.hpp"

class DSPKernel {
private:
	AUHostMusicalContextBlock musicalContextBlock;

	int maxFrames = 1024;

	Buffer ax = Buffer();
	Buffer bx = Buffer();
	Buffer cx = Buffer();
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
		ax.allocate(len);
		bx.allocate(len);
		cx.allocate(len);
	}
	void deInitialize() {
		line.deallocate();
		ax.deallocate();
		bx.deallocate();
		cx.deallocate();
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
		Buffer in0 = Buffer((float *)in[0], cnt);
		Buffer out0 = Buffer(out[0], cnt);

		if (!speed && !targetSpeed) {

		} if (speed == 1 && targetSpeed == 1) {
			line.read(out0);
			if (!hold) line.write(in0);
			line.move(cnt);
		} else {
			speed += (targetSpeed - speed) * cnt / sampleRate * 0.5;
			if (abs(targetSpeed - speed) < 0.01) speed = targetSpeed;

			float x0 = 0;
			float x1 = speed;
			int lineCnt = speed * cnt;

			line.read(bx.sub(lineCnt));
			vDSP_vramp(&x0, &x1, ax.data, 1, vDSP_Length(cnt));
			vDSP_vqint(bx.data, ax.data, 1, out0.data, 1, cnt, lineCnt);

			if (!hold) {
				x1 = speed * cnt / lineCnt;
				vDSP_vramp(&x0, &x1, ax.data, 1, vDSP_Length(lineCnt));
				vDSP_vqint(in0.data, ax.data, 1, bx.data, 1, lineCnt, cnt);
				line.write(bx.sub(lineCnt));
			}

			line.move(lineCnt);
		}
	}

	void handleOneEvent(AUEventSampleTime now, AURenderEvent const *event) {
		if (event->head.eventType == AURenderEventParameter) handleParameterEvent(now, event->parameter);
	}
	void handleParameterEvent(AUEventSampleTime now, AUParameterEvent const& parameterEvent) {}
};
