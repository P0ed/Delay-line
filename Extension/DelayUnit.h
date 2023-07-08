#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

@interface DelayUnit : AUAudioUnit
@property (nonnull, readonly, nonatomic) float *ft;
@end
