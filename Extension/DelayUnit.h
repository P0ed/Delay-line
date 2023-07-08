#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

@interface DelayUnit : AUAudioUnit
- (void)ft:(void (^)(uint32_t const *))access;
@end
