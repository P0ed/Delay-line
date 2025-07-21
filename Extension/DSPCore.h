#import <Accelerate/Accelerate.h>
#import <AudioToolbox/AUParameters.h>
#import <os/lock.h>

static os_unfair_lock lock = OS_UNFAIR_LOCK_INIT;

static const int LineLength = 48000;
static const int DSPCoreMaxFrames = 4096;

static const int UIFTWidth = 256;
static const int UIFTHeight = 2048;

typedef struct { const uint8_t *const data; } UIFT;

typedef struct {
	double sampleRate;
	float buffer[DSPCoreMaxFrames];

	float ax[DSPCoreMaxFrames];
	float bx[DSPCoreMaxFrames];
	float cx[DSPCoreMaxFrames];
	float dx[DSPCoreMaxFrames];

	float rms[UIFTHeight];
	float ftWindow[UIFTWidth * 4];

	vDSP_DFT_Setup ftSetup;
	uint8_t ft[UIFTHeight * UIFTWidth];
	int ftHead;
	char ftDirty[UIFTHeight];

	float line[LineLength];
	int lineHead;

	AUValue hold;
	AUValue speed;
	AUValue targetSpeed;
} DSPCore;

typedef NS_ENUM(AUParameterAddress, ParameterAddress) {
	ParameterAddressHold,
	ParameterAddressSpeed
};

void DSPCoreInit(DSPCore *k, double samplesPerSecond);
void DSPCoreDeinit(DSPCore *k);
AUValue DSPCoreGetParameter(DSPCore *k, AUParameterAddress address);
void DSPCoreSetParameter(DSPCore *k, AUParameterAddress address, AUValue value);
void DSPCoreProcess(DSPCore *k, const float *input, float *output, AUEventSampleTime startTime, int cnt);
