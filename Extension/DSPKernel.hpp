#pragma once

#import <AudioToolbox/AudioToolbox.h>
#import <Accelerate/Accelerate.h>
#import <os/lock.h>

#import "ParameterAddresses.h"
#import "Buffer.hpp"

static os_unfair_lock lock = OS_UNFAIR_LOCK_INIT;

const int maxFrames = 4096;
const int ftWidth = 256;
const int ftHeight = 1024;

struct DSPKernel {
public:
	char ft[ftHeight * ftWidth];
	int ftOffset = 0;
private:
	Buffer line = Buffer();
	float ax[maxFrames], bx[maxFrames], cx[maxFrames], dx[maxFrames];

	float rms[ftHeight];
	float ftWindow[ftWidth * 4];
	char ftDirty[ftHeight];
	vDSP_DFT_Setup ftSetup = NULL;
	double sampleRate = 48000;

	AUValue hold = 0;
	AUValue speed = 1;
	AUValue targetSpeed = 1;
public:
	void initialize(int inputChannelCount, int outputChannelCount, double samplesPerSecond) {
		sampleRate = samplesPerSecond;
		vDSP_vclr(ax, 1, maxFrames);
		vDSP_vclr(bx, 1, maxFrames);
		vDSP_vclr(cx, 1, maxFrames);
		vDSP_vclr(dx, 1, maxFrames);
		vDSP_vclr(rms, 1, ftHeight);
		memset(ft, 0, sizeof(ft));
		memset(ftDirty, 0, sizeof(ftDirty));

		vDSP_hann_window(ftWindow, ftWidth * 4, 0);
		ftSetup = vDSP_DFT_zrop_CreateSetup(NULL, ftWidth * 4, vDSP_DFT_FORWARD);
	}
	void deInitialize() {
		vDSP_DFT_DestroySetup(ftSetup);
	}

	AUValue getParameter(AUParameterAddress address) {
		switch (address) {
			case ParameterAddressHold: return hold;
			case ParameterAddressSpeed: return targetSpeed;
			default: return 0;
		}
	}
	void setParameter(AUParameterAddress address, AUValue value) {
		switch (address) {
			case ParameterAddressHold: hold = value; return;
			case ParameterAddressSpeed: targetSpeed = value; return;
		}
	}

	void process(const float *in, float *out, AUEventSampleTime startTime, int cnt) {
		speed += (targetSpeed - speed) * cnt / sampleRate * 4;
		if (abs(targetSpeed - speed) < 0.02) speed = targetSpeed;
		speed = fmin(fmax(speed, 0), 4);
		if (speed < 0.025) return vDSP_vclr(out, 1, cnt);

		const int lineCnt = speed * cnt;
		if (lineCnt == cnt) {
			line.read(out, cnt);
			if (!hold) line.write(in, cnt);
		} else {
			line.read(ax, lineCnt);
			float x0 = 0, x1 = ((float)lineCnt - 1) / ((float)cnt - 1);
			vDSP_vramp(&x0, &x1, bx, 1, cnt);
			vDSP_vqint(ax, bx, 1, out, 1, cnt, lineCnt);

			if (!hold) {
				float x0 = 0, x1 = ((float)cnt - 1) / ((float)lineCnt - 1);
				vDSP_vramp(&x0, &x1, bx, 1, lineCnt);
				vDSP_vqint(in, bx, 1, ax, 1, lineCnt, cnt);
				line.write(ax, lineCnt);
			}
		}

		updateFT(lineCnt);
		line.move(lineCnt);

		ftOffset = line.offset * ftHeight / line.length;
	}

private:
	void updateFT(int cnt) {
		if (!hold) for (int i = 0; i < cnt; ++i) {
			int idx = (i + line.offset) % line.length;
			ftDirty[ftHeight * idx / line.length % ftHeight] = 1;
		}

		if (!os_unfair_lock_trylock(&lock)) return;

		for (int i = 0; i < ftHeight; ++i) if (ftDirty[i]) {
			float *data = line.data + (line.length - ftWidth * 4) * i / (ftHeight - 1);
			vDSP_vmul(data, 1, ftWindow, 1, ax, 1, ftWidth * 4);
			vDSP_rmsqv(ax, 1, rms + i, ftWidth * 4);
			vDSP_vclr(bx, 1, ftWidth * 4);
			vDSP_DFT_Execute(ftSetup, ax, bx, cx, dx);

			DSPSplitComplex cdx = { cx, dx };
			vDSP_zvmags(&cdx, 1, ax, 1, ftWidth);
			vvsqrtf(ax, ax, &ftWidth);

			float max = 0;
			vDSP_maxv(ax, 1, &max, ftWidth);
			float scale = fmin(fmax(rms[i] * 24, 0), 1) * 255 / max;
			vDSP_vsmul(ax, 1, &scale, ax, 1, ftWidth);
			vDSP_vfixu8(ax, 1, (uint8_t *)ft + ftWidth * i, 1, ftWidth);

			ftDirty[i] = 0;
		}

		os_unfair_lock_unlock(&lock);
	}
};
