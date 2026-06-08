#pragma once
#include "smc.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// System input power widget. Reads SMC PSTR (total system power input,
// instantaneous — same source iStat Menus uses for "System Total").
struct power {
  char command[128];
};

static inline void power_init(struct power *p) {
  p->command[0] = '\0';
}

static inline void power_update(struct power *p) {
  float watts = -1.f;
  float v = 0.f;
  if (smc_read_float("PSTR", &v) && v >= 0.f && v < 500.f) watts = v;

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
             "--set power icon=%s label=%.1fW background.color=%s",
             icon, watts, color);
  } else {
    snprintf(p->command, sizeof(p->command),
             "--set power icon=%s label=--W background.color=%s",
             icon, color);
  }
}
