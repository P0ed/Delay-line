#import <AudioToolbox/AudioToolbox.h>

typedef struct {
	const uint8_t *const data;
	int const rows;
	int const cols;
} UIFT;

@interface DelayUnit : AUAudioUnit
- (UIFT)ft;
@end
