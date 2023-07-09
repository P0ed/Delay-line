#pragma once

#import <AudioToolbox/AudioToolbox.h>
#import <algorithm>
#import <Accelerate/Accelerate.h>
#import <os/lock.h>

#import "Extension-Swift.h"
#import "ParameterAddresses.h"
#import "Buffer.hpp"

static os_unfair_lock lock = OS_UNFAIR_LOCK_INIT;
static const float zero = 0;
static const float one = 1;
const int ftWidth = 256;
const int ftHeight = 1024;

class DSPKernel {
private:
	Buffer line = Buffer();
	float *ax, *bx, *cx, *dx;

	char *ftDirty;
	vDSP_DFT_Setup ftSetup = NULL;

	const int maxFrames = 1024;
	double sampleRate = 48000;

	AUValue hold = 0;
	AUValue speed = 1;
	AUValue targetSpeed = 1;

public:
	char *ft;
	int ftOffset = 0;

	void initialize(int inputChannelCount, int outputChannelCount, double samplesPerSecond) {
		sampleRate = samplesPerSecond;
		line.allocate(samplesPerSecond * 2);

		ax = new float[maxFrames * 4];
		bx = ax + maxFrames;
		cx = bx + maxFrames;
		dx = cx + maxFrames;

		ft = new char[ftWidth * ftHeight];
		ftDirty = new char[ftHeight];
		ftSetup = vDSP_DFT_zrop_CreateSetup(NULL, ftWidth * 4, vDSP_DFT_FORWARD);
	}
	void deInitialize() {
		line.deallocate();
		delete[] ax;
		delete[] ft;
		delete[] ftDirty;
		vDSP_DFT_DestroySetup(ftSetup);
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

	void process(AudioBufferList *in, AudioBufferList *out, AUEventSampleTime startTime, int cnt) {
		const float *const in0 = (float *)in->mBuffers[0].mData;
		float *const out0 = (float *)out->mBuffers[0].mData;

		speed += (targetSpeed - speed) * cnt / sampleRate * 2;
		if (abs(targetSpeed - speed) < 0.01) speed = targetSpeed;

		const int lineCnt = speed * cnt;
		if (lineCnt < 32) return vDSP_vclr(out0, 1, cnt);

		if (speed == 1 && targetSpeed == 1) {
			line.read(out0, cnt);
			if (!hold) line.write(in0, cnt);
		} else {
			line.read(bx, lineCnt);
			float x = speed;
			vDSP_vramp(&zero, &x, ax, 1, cnt);
			vDSP_vqint(bx, ax, 1, out0, 1, cnt, lineCnt);

			if (!hold) {
				float x = speed * cnt / lineCnt;
				vDSP_vramp(&zero, &x, ax, 1, lineCnt);
				vDSP_vqint(in0, ax, 1, bx, 1, lineCnt, cnt);
				line.write(bx, lineCnt);
			}
		}

		updateFT(lineCnt);
		line.move(lineCnt);
	}

private:
	void updateFT(int cnt) {
		if (!hold) for (int i = 0; i < cnt; ++i) {
			int idx = (i + line.offset) % line.length;
			ftDirty[ftHeight * idx / line.length % ftHeight] = 1;
		}

		ftOffset = line.offset * ftHeight / line.length;

		if (!os_unfair_lock_trylock(&lock)) return;

		for (int i = 0; i < ftHeight; ++i) if (ftDirty[i]) {
			vDSP_vsmul(line.data + line.length * i / ftHeight, 1, &one, ax, 1, ftWidth * 2);
			vDSP_vclr(bx, 1, ftWidth * 2);
			vDSP_DFT_Execute(ftSetup, ax, bx, cx, dx);

			vDSP_vclr(ax, 1, ftWidth * 2);
			DSPSplitComplex t = { cx, dx };
			vDSP_zaspec(&t, ax, ftWidth * 2);

			for (int i = 0; i < ftWidth; ++i) bx[i] = sin(M_PI_2 * i / ftWidth) * ftWidth;
			vDSP_vlint(ax, bx, 1, ax, 1, ftWidth, ftWidth);
			for (int i = 0; i < ftWidth; ++i) ax[i] = sqrt(ax[i]);

			float x = 0;
			vDSP_maxv(ax, 1, &x, ftWidth);
			x = 255 / x;
			vDSP_vsmul(ax, 1, &x, ax, 1, ftWidth);

			vDSP_vfixu8(ax, 1, (uint8_t *)ft + ftWidth * i, 1, ftWidth);

			ftDirty[i] = 0;
		}

		os_unfair_lock_unlock(&lock);
	}
};
