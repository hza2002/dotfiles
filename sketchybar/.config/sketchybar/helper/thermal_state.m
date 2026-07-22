#import <Foundation/Foundation.h>
#include "thermal_state.h"

const char *thermal_state_text(void) {
  @autoreleasepool {
    switch ([NSProcessInfo processInfo].thermalState) {
      case NSProcessInfoThermalStateNominal:  return "正常";
      case NSProcessInfoThermalStateFair:     return "偏高";
      case NSProcessInfoThermalStateSerious:  return "严重";
      case NSProcessInfoThermalStateCritical: return "临界";
    }
    return "未知";
  }
}
