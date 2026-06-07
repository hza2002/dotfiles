#pragma once
// Battery widget. Reads via IOKit IOPSCopyPowerSourcesInfo (microsecond
// cost) so we no longer fork pmset + awk/grep five times every tick.
#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/ps/IOPSKeys.h>
#include <IOKit/ps/IOPowerSources.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct battery {
  char command[256];
};

static inline void battery_init(struct battery *b) {
  b->command[0] = '\0';
}

static inline int battery_cf_int(CFDictionaryRef d, CFStringRef key, int def) {
  CFNumberRef n = (CFNumberRef)CFDictionaryGetValue(d, key);
  int v = def;
  if (n && CFGetTypeID(n) == CFNumberGetTypeID()) {
    CFNumberGetValue(n, kCFNumberIntType, &v);
  }
  return v;
}

static inline bool battery_cf_bool(CFDictionaryRef d, CFStringRef key) {
  CFBooleanRef b = (CFBooleanRef)CFDictionaryGetValue(d, key);
  return b && CFBooleanGetValue(b);
}

static inline bool battery_cf_str_equal(CFDictionaryRef d, CFStringRef key,
                                        CFStringRef target) {
  CFStringRef s = (CFStringRef)CFDictionaryGetValue(d, key);
  return s && CFStringCompare(s, target, 0) == kCFCompareEqualTo;
}

static inline const char *battery_icon_for(int pct) {
  if (pct >= 90) return getenv("BATTERY_100");
  if (pct >= 60) return getenv("BATTERY_75");
  if (pct >= 40) return getenv("BATTERY_50");
  if (pct >= 20) return getenv("BATTERY_25");
  return getenv("BATTERY_0");
}

// 6-tier HARD-only discharge gradient. BLUE is skipped (full battery
// reads healthy with AQUA).
static inline const char *battery_color_for(int pct) {
  if (pct >= 90) return getenv("AQUA_HARD");
  if (pct >= 70) return getenv("GREEN_HARD");
  if (pct >= 50) return getenv("YELLOW_HARD");
  if (pct >= 20) return getenv("ORANGE_HARD");
  if (pct >= 10) return getenv("RED_HARD");
  return getenv("PURPLE_HARD");
}

static inline void battery_update(struct battery *b) {
  CFTypeRef blob = IOPSCopyPowerSourcesInfo();
  if (!blob) return;
  CFArrayRef list = IOPSCopyPowerSourcesList(blob);
  if (!list) { CFRelease(blob); return; }

  int pct = -1;
  bool charging = false;
  bool on_ac = false;

  CFIndex n = CFArrayGetCount(list);
  for (CFIndex i = 0; i < n; i++) {
    CFDictionaryRef d = IOPSGetPowerSourceDescription(blob,
                          CFArrayGetValueAtIndex(list, i));
    if (!d) continue;
    int cur = battery_cf_int(d, CFSTR(kIOPSCurrentCapacityKey), -1);
    int max = battery_cf_int(d, CFSTR(kIOPSMaxCapacityKey), 100);
    if (cur >= 0 && max > 0) pct = (int)(100.0 * cur / max + 0.5);
    charging = battery_cf_bool(d, CFSTR(kIOPSIsChargingKey));
    on_ac = battery_cf_str_equal(d, CFSTR(kIOPSPowerSourceStateKey),
                                 CFSTR(kIOPSACPowerValue));
    break;
  }

  CFRelease(list);
  CFRelease(blob);

  if (pct < 0) { b->command[0] = '\0'; return; }

  const char *icon;
  const char *color;
  if (charging || on_ac) {
    icon  = getenv("BATTERY_CHARGING");
    color = getenv("AQUA_HARD");
  } else {
    icon  = battery_icon_for(pct);
    color = battery_color_for(pct);
  }
  if (!icon  || !icon[0])  icon  = "?";
  if (!color || !color[0]) color = "0xffffffff";

  // Two-digit width: original shell plugin padded <10% with a leading 0.
  if (pct < 10) {
    snprintf(b->command, sizeof(b->command),
             "--set battery icon=%s icon.color=%s label=0%d%%",
             icon, color, pct);
  } else {
    snprintf(b->command, sizeof(b->command),
             "--set battery icon=%s icon.color=%s label=%d%%",
             icon, color, pct);
  }
}
