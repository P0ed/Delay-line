#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

typedef struct {
	const char *const data;
	int const rows;
	int const cols;
	int const rowOffset;
} UIFT;

@interface DelayUnit : AUAudioUnit
- (UIFT)ft;
@end
