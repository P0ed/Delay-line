#pragma once

#include <AudioToolbox/AUParameters.h>

#ifdef __cplusplus
namespace ParameterAddress {
#endif

typedef NS_ENUM(AUParameterAddress, ParameterAddress) {
	hold,
	speed
};

#ifdef __cplusplus
}
#endif
