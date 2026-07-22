#pragma once
#include "smc.h"
#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/ps/IOPSKeys.h>
#include <IOKit/ps/IOPowerSources.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// System input power widget. Reads SMC PSTR (total system power input,
// instantaneous — same source iStat Menus uses for "System Total").
struct power {
  char command[256];
};

static inline void power_init(struct power *p) {
  p->command[0] = '\0';
}

static inline void power_update(struct power *p) {
  float watts = -1.f;
  float v = 0.f;
  if (smc_read_float("PSTR", &v) && v >= 0.f && v < 500.f) watts = v;

  bool source_known = false;
  bool on_external_power = false;
  CFTypeRef snapshot = IOPSCopyPowerSourcesInfo();
  if (snapshot) {
    CFStringRef source = IOPSGetProvidingPowerSourceType(snapshot);
    if (source) {
      source_known = true;
      on_external_power =
        CFStringCompare(source, CFSTR(kIOPMACPowerKey), 0) == kCFCompareEqualTo ||
        CFStringCompare(source, CFSTR(kIOPMUPSPowerKey), 0) == kCFCompareEqualTo;
    }
    CFRelease(snapshot);
  }

  int adapter_watts = -1;
  if (on_external_power) {
    CFDictionaryRef details = IOPSCopyExternalPowerAdapterDetails();
    if (details) {
      CFNumberRef number = (CFNumberRef)CFDictionaryGetValue(
        details, CFSTR(kIOPSPowerAdapterWattsKey));
      if (number && CFGetTypeID(number) == CFNumberGetTypeID()) {
        CFNumberGetValue(number, kCFNumberIntType, &adapter_watts);
      }
      CFRelease(details);
    }
  }

  const char *adapter_icon = "适配器功率";
  char adapter_label[16];
  if (source_known && !on_external_power) {
    adapter_icon = "外部供电";
    snprintf(adapter_label, sizeof(adapter_label), "未连接");
  } else if (adapter_watts > 0) {
    snprintf(adapter_label, sizeof(adapter_label), "%dW", adapter_watts);
  } else {
    snprintf(adapter_label, sizeof(adapter_label), "未知");
  }

  // 7-tier HARD-only gradient tuned for M1 Max + 100W PD adapter.
  const char *color;
  if      (watts >= 100.f) color = getenv("PURPLE_HARD");
  else if (watts >=  80.f) color = getenv("RED_HARD");
  else if (watts >=  50.f) color = getenv("ORANGE_HARD");
  else if (watts >=  25.f) color = getenv("YELLOW_HARD");
  else if (watts >=  10.f) color = getenv("GREEN_HARD");
  else if (watts >=   5.f) color = getenv("AQUA_HARD");
  else                     color = getenv("BLUE_HARD");
  if (!color || color[0] == '\0') color = "0xffffffff";

  // 2-tier icon: HIGH at YELLOW threshold (sustained draw), else LOW.
  const char *icon = getenv(watts >= 25.f ? "SYS_POWER_HIGH" : "SYS_POWER_LOW");
  if (!icon || icon[0] == '\0') icon = "";

  if (watts >= 0.f) {
    snprintf(p->command, sizeof(p->command),
             "--set power icon=%s label=%.1fW background.color=%s "
             "--set power.adapter icon=%s label=%s",
             icon, watts, color, adapter_icon, adapter_label);
  } else {
    snprintf(p->command, sizeof(p->command),
             "--set power icon=%s label=--W background.color=%s "
             "--set power.adapter icon=%s label=%s",
             icon, color, adapter_icon, adapter_label);
  }
}
