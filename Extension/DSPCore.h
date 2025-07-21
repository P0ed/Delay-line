#import <AudioToolbox/AudioToolbox.h>
#import <Accelerate/Accelerate.h>
#import <os/lock.h>
#import "ParameterAddresses.h"

static os_unfair_lock lock = OS_UNFAIR_LOCK_INIT;

static const int LineLength = 48000;
static const int DSPCoreMaxFrames = 4096;
static const int FTWidth = 256;
static const int FTHeight = 2048;

typedef struct {
	float buffer[DSPCoreMaxFrames];
	uint8_t ft[FTHeight * FTWidth];
	int ftOffset;
	float line[LineLength];
	int lineOffset;
	float ax[DSPCoreMaxFrames], bx[DSPCoreMaxFrames], cx[DSPCoreMaxFrames], dx[DSPCoreMaxFrames];
	float rms[FTHeight];
	float ftWindow[FTWidth * 4];
	char ftDirty[FTHeight];
	vDSP_DFT_Setup ftSetup;
	double sampleRate;

	AUValue hold;
	AUValue speed;
	AUValue targetSpeed;
} DSPCore;

void DSPCoreInit(DSPCore *k, int inputChannelCount, int outputChannelCount, double samplesPerSecond) {
	k->sampleRate = samplesPerSecond;
	vDSP_hann_window(k->ftWindow, FTWidth * 4, 0);
	k->ftOffset = 0;
	k->ftSetup = vDSP_DFT_zrop_CreateSetup(NULL, FTWidth * 4, vDSP_DFT_FORWARD);
	k->hold = 0;
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
		int idx = (i + k->lineOffset) % LineLength;
		k->ftDirty[FTHeight * idx / LineLength % FTHeight] = 1;
	}

	if (!os_unfair_lock_trylock(&lock)) return;

	for (int i = 0; i < FTHeight; ++i) if (k->ftDirty[i]) {
		float *data = k->line + (LineLength - FTWidth * 4) * i / (FTHeight - 1);
		vDSP_vmul(data, 1, k->ftWindow, 1, k->ax, 1, FTWidth * 4);
		vDSP_rmsqv(k->ax, 1, k->rms + i, FTWidth * 4);
		vDSP_vclr(k->bx, 1, FTWidth * 4);
		vDSP_DFT_Execute(k->ftSetup, k->ax, k->bx, k->cx, k->dx);

		DSPSplitComplex cdx = { k->cx, k->dx };
		vDSP_zvmags(&cdx, 1, k->ax, 1, FTWidth);
		vvsqrtf(k->ax, k->ax, &FTWidth);

		float max = 0;
		vDSP_maxv(k->ax, 1, &max, FTWidth);
		float scale = fmin(fmax(k->rms[i] * 24, 0), 1) * 255 / max;
		vDSP_vsmul(k->ax, 1, &scale, k->ax, 1, FTWidth);
		vDSP_vfixu8(k->ax, 1, (uint8_t *)k->ft + FTWidth * i, 1, FTWidth);

		k->ftDirty[i] = 0;
	}

	os_unfair_lock_unlock(&lock);
}

static void DSPCoreMove(DSPCore *k, int dx) {
	k->lineOffset = (k->lineOffset + dx) % LineLength;
}

static void DSPCoreRead(DSPCore *k, float *data, int length) {
	for (int i = 0; i < length; ++i) {
		data[i] = k->line[(k->lineOffset + i) % LineLength];
	}
}

static void DSPCoreWrite(DSPCore *k, const float *data, int length) {
	for (int i = 0; i < length; ++i) {
		k->line[(k->lineOffset + i) % LineLength] = data[i];
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

	k->ftOffset = k->lineOffset * FTHeight / LineLength;
}
