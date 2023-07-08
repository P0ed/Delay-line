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
	Buffer line = Buffer();

	float *ax, *bx, *cx, *dx;

	float *ft;
	char *ftDirty;
	vDSP_DFT_Setup ftSetup;
	const int ftWidth = 512;
	const int ftHeight = 1024;

	const int maxFrames = 1024;
	double sampleRate = 48000;

	AUValue hold = 0;
	AUValue speed = 1;
	AUValue targetSpeed = 1;

	AUHostMusicalContextBlock musicalContextBlock;

public:
	void initialize(int inputChannelCount, int outputChannelCount, double samplesPerSecond) {
		sampleRate = samplesPerSecond;
		int len = samplesPerSecond * 1;
		line.allocate(len);

		ax = new float[maxFrames * 4];
		bx = ax + maxFrames;
		cx = bx + maxFrames;
		dx = cx + maxFrames;

		ft = new float[ftWidth * ftHeight];
		ftDirty = new char[ftHeight];
//		ftSetup = vDSP_DFT_zrop_CreateSetup(nullptr, ftWidth * 2, vDSP_DFT_FORWARD);
	}
	void deInitialize() {
		line.deallocate();
		delete[] ax;
		delete[] ft;
		delete[] ftDirty;
//		vDSP_DFT_DestroySetup(ftSetup);
	}

	float *getFT() { return ft; }

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

	void setMusicalContextBlock(AUHostMusicalContextBlock block) { musicalContextBlock = block; }

	void process(AudioBufferList *in, AudioBufferList *out, AUEventSampleTime startTime, int cnt) {
		float const *const in0 = (float *)in->mBuffers[0].mData;
		float *const out0 = (float *)out->mBuffers[0].mData;
		const int lineCnt = speed * cnt;

		if (!speed && !targetSpeed) {

		} if (speed == 1 && targetSpeed == 1) {
			line.read(out0, cnt);
			if (!hold) line.write(in0, cnt);
		} else {
			line.read(bx, lineCnt);
			float x0 = 0, x1 = speed;
			vDSP_vramp(&x0, &x1, ax, 1, cnt);
			vDSP_vqint(bx, ax, 1, out0, 1, cnt, lineCnt);

			if (!hold) {
				x0 = 0; x1 = speed * cnt / lineCnt;
				vDSP_vramp(&x0, &x1, ax, 1, lineCnt);
				vDSP_vqint(in0, ax, 1, bx, 1, lineCnt, cnt);
				line.write(bx, lineCnt);
			}

			speed += (targetSpeed - speed) * cnt / sampleRate * 2;
			if (abs(targetSpeed - speed) < 0.01) speed = targetSpeed;
		}

//		if (!hold) for (int i = 0; i < ftHeight; ++i) {
//			int bin = line.length / ftHeight;
//			int b0 = bin * i, b1 = bin * (i + 1) - 1;
//			int x0 = line.offset, x1 = (line.offset + lineCnt) % line.length;
//			ftDirty[i] = (b0 > x0 && b0 <= x1) || (b1 > x0 && b1 <= x1);
//		}

//		for (int i = 0; i < ftHeight; ++i) if (ftDirty[i]) {
//			line.read(ax, ftWidth * 2);
//			vDSP_vclr(bx, 1, ftWidth * 2);
//			vDSP_DFT_Execute(ftSetup, ax, bx, ft + ftWidth * i, bx);
//		}

		line.move(lineCnt);
	}
};
