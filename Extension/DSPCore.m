#import <AudioToolbox/AudioToolbox.h>
#import <Accelerate/Accelerate.h>
#import "DSPCore.h"

void DSPCoreInit(DSPCore *k, double samplesPerSecond) {
	k->sampleRate = samplesPerSecond;
	vDSP_hann_window(k->ftWindow, UIFTWidth * 4, 0);
	k->ftSetup = vDSP_DFT_zrop_CreateSetup(NULL, UIFTWidth * 4, vDSP_DFT_FORWARD);
	k->speed = 1;
	k->targetSpeed = 1;
}

void DSPCoreDeinit(DSPCore *k) {
	vDSP_DFT_DestroySetup(k->ftSetup);
}

AUValue DSPCoreGetParameter(DSPCore *k, AUParameterAddress address) {
	switch (address) {
		case ParameterAddressHold: return k->hold;
		case ParameterAddressSpeed: return k->targetSpeed;
		default: return 0;
	}
}

void DSPCoreSetParameter(DSPCore *k, AUParameterAddress address, AUValue value) {
	switch (address) {
		case ParameterAddressHold: k->hold = !!value; return;
		case ParameterAddressSpeed: k->targetSpeed = fmin(fmax(value, 0), 4); return;
	}
}

static void DSPCoreUpdateFT(DSPCore *k, int cnt) {
	if (!k->hold) for (int i = 0; i < cnt; ++i) {
		int idx = (i + k->lineHead) % LineLength;
		k->ftDirty[UIFTHeight * idx / LineLength % UIFTHeight] = 1;
	}

	if (!os_unfair_lock_trylock(&lock)) return;

	for (int i = 0; i < UIFTHeight; ++i) if (k->ftDirty[i]) {
		float *data = k->line + (LineLength - UIFTWidth * 4) * i / (UIFTHeight - 1);
		vDSP_vmul(data, 1, k->ftWindow, 1, k->ax, 1, UIFTWidth * 4);
		vDSP_rmsqv(k->ax, 1, k->rms + i, UIFTWidth * 4);
		vDSP_vclr(k->bx, 1, UIFTWidth * 4);
		vDSP_DFT_Execute(k->ftSetup, k->ax, k->bx, k->cx, k->dx);

		DSPSplitComplex cdx = { k->cx, k->dx };
		vDSP_zvmags(&cdx, 1, k->ax, 1, UIFTWidth);
		vvsqrtf(k->ax, k->ax, &UIFTWidth);

		float max = 0;
		vDSP_maxv(k->ax, 1, &max, UIFTWidth);
		float scale = fmin(fmax(k->rms[i] * 24, 0), 1) * 255 / max;
		vDSP_vsmul(k->ax, 1, &scale, k->ax, 1, UIFTWidth);
		vDSP_vfixu8(k->ax, 1, (uint8_t *)k->ft + UIFTWidth * i, 1, UIFTWidth);

		k->ftDirty[i] = 0;
	}

	os_unfair_lock_unlock(&lock);
}

static void DSPCoreMove(DSPCore *k, int dx) {
	k->lineHead = (k->lineHead + dx) % LineLength;
}

static void DSPCoreRead(DSPCore *k, float *data, int length) {
	for (int i = 0; i < length; ++i) {
		data[i] = k->line[(k->lineHead + i) % LineLength];
	}
}

static void DSPCoreWrite(DSPCore *k, const float *data, int length) {
	for (int i = 0; i < length; ++i) {
		k->line[(k->lineHead + i) % LineLength] = data[i];
	}
}

void DSPCoreProcess(DSPCore *k, const float *input, float *output, AUEventSampleTime startTime, int cnt) {
	const float ds = k->targetSpeed - k->speed;
	if (ds != 0) {
		const float v = fabsf(ds) < 0.02 ? k->targetSpeed : k->speed + ds * cnt * 4 / k->sampleRate;
		k->speed = fmin(fmax(v, 0), 4);
	}
	if (k->speed < 0.025) return vDSP_vclr(output, 1, cnt);

	const int lineCnt = k->speed * cnt;
	if (lineCnt == cnt) {
		DSPCoreRead(k, output, cnt);
		if (!k->hold) DSPCoreWrite(k, input, cnt);
	} else {
		DSPCoreRead(k, k->ax, lineCnt);
		float x0 = 0, x1 = ((float)lineCnt - 1) / ((float)cnt - 1);
		vDSP_vramp(&x0, &x1, k->bx, 1, cnt);
		vDSP_vqint(k->ax, k->bx, 1, output, 1, cnt, lineCnt);

		if (!k->hold) {
			float x0 = 0, x1 = ((float)cnt - 1) / ((float)lineCnt - 1);
			vDSP_vramp(&x0, &x1, k->bx, 1, lineCnt);
			vDSP_vqint(input, k->bx, 1, k->ax, 1, lineCnt, cnt);
			DSPCoreWrite(k, k->ax, lineCnt);
		}
	}

	DSPCoreUpdateFT(k, lineCnt);
	DSPCoreMove(k, lineCnt);

	k->ftHead = k->lineHead * UIFTHeight / LineLength;
}
