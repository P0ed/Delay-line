#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

@interface DelayUnit : AUAudioUnit
@property (nonnull, readonly, nonatomic) uint32_t *ft;
@end
