#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

@interface Unit : AUAudioUnit
- (void)setupParameterTree:(AUParameterTree *)parameterTree;
@end
