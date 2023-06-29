#pragma once

#include <AudioToolbox/AUParameters.h>

#ifdef __cplusplus
namespace ParameterAddress {
#endif

typedef NS_ENUM(AUParameterAddress, ParameterAddress) {
	hold = 0,
    feedback = 1
};

#ifdef __cplusplus
}
#endif
