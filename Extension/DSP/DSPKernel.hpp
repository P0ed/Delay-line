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

	uint32_t *ft;
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

		ft = new uint32_t[ftWidth * ftHeight];
		ftDirty = new char[ftHeight];
		ftSetup = vDSP_DFT_zrop_CreateSetup(nullptr, ftWidth * 2, vDSP_DFT_FORWARD);
	}
	void deInitialize() {
		line.deallocate();
		delete[] ax;
		delete[] ft;
		delete[] ftDirty;
		vDSP_DFT_DestroySetup(ftSetup);
	}

	uint32_t *getFT() { return ft; }

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

		speed += (targetSpeed - speed) * cnt / sampleRate * 2;
		if (abs(targetSpeed - speed) < 0.01) speed = targetSpeed;

		const int lineCnt = speed * cnt;
		if (lineCnt < 8) return vDSP_vclr(out0, 1, cnt);

		if (speed == 1 && targetSpeed == 1) {
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
		}

		updateFT(lineCnt);
		line.move(lineCnt);
	}

	void updateFT(int cnt) {
		if (!hold) for (int i = 0; i < cnt; ++i) {
			int idx = (i + line.offset) % line.length;
			ftDirty[ftHeight * idx / line.length % ftHeight] = 1;
		}
		for (int i = 0; i < ftHeight; ++i) if (ftDirty[i]) {
			vDSP_vclr(ax, 1, ftWidth * 2);
			vDSP_DFT_Execute(ftSetup, line.data + line.length * i / ftHeight, ax, bx, cx);

			DSPSplitComplex t = { bx, cx };
			vDSP_zaspec(&t, ax, ftWidth);

			float max = 0;
			vDSP_maxv(ax, 1, &max, ftWidth);
			max /= 255;
			vDSP_vsdiv(bx, 1, &max, ax, 1, ftWidth);

			uint32_t *out = ft + ftWidth * i;

			int v = 0xFFFFFFFF;
			vDSP_vfilli(&v, (int *)out, 1, ftWidth);
			vDSP_vfixu8(ax, 1, (uint8_t *)out + 0, 4, ftWidth);
			vDSP_vfixu8(ax, 1, (uint8_t *)out + 1, 4, ftWidth);
			vDSP_vfixu8(ax, 1, (uint8_t *)out + 2, 4, ftWidth);
			ftDirty[i] = 0;
		}
	}
};
