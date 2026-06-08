#pragma once
#include "smc.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Fan RPM widget. Probes F0Ac..F3Ac at startup (Apple Silicon exposes
// these as `flt ` keys, already handled by smc_read_float). Reports the
// average across all detected fans — on healthy M-series machines they
// track each other anyway.
#define FAN_MAX 4

struct fan {
  int  count;
  char keys[FAN_MAX][5];
  char command[160];
};

static inline void fan_init(struct fan *f) {
  f->count = 0;
  f->command[0] = '\0';
  for (int i = 0; i < FAN_MAX; i++) {
    char key[5];
    snprintf(key, sizeof(key), "F%dAc", i);
    float v = 0.f;
    if (smc_read_float(key, &v)) {
      memcpy(f->keys[f->count], key, 5);
      f->count++;
    }
  }
}

static inline void fan_update(struct fan *f) {
  if (f->count == 0) {
    f->command[0] = '\0';
    return;
  }

  int total = 0;
  for (int i = 0; i < f->count; i++) {
    float v = 0.f;
    if (smc_read_float(f->keys[i], &v)) total += (int)(v + 0.5f);
  }
  int avg = total / f->count;

  // 8-tier gradient tuned for M1 Max (idle ~1300, max ~6300). GRAY is
  // reserved for fans literally stopped, so "off" is visually distinct
  // from "low".
  const char *color;
  if      (avg == 0)    color = getenv("GRAY_HARD");
  else if (avg >= 6000) color = getenv("PURPLE_HARD");
  else if (avg >= 5000) color = getenv("RED_HARD");
  else if (avg >= 4000) color = getenv("ORANGE_HARD");
  else if (avg >= 3000) color = getenv("YELLOW_HARD");
  else if (avg >= 2000) color = getenv("GREEN_HARD");
  else if (avg >= 1300) color = getenv("AQUA_HARD");
  else                  color = getenv("BLUE_HARD");
  if (!color || color[0] == '\0') color = "0xffffffff";

  // 3-tier icon: STOP at 0, HIGH once fan ramps up (YELLOW threshold),
  // LOW otherwise.
  const char *icon;
  if      (avg == 0)    icon = getenv("SYS_FAN_STOP");
  else if (avg >= 3000) icon = getenv("SYS_FAN_HIGH");
  else                  icon = getenv("SYS_FAN_LOW");
  if (!icon || icon[0] == '\0') icon = "";

  snprintf(f->command, sizeof(f->command),
           "--set fan icon=%s label=%d background.color=%s",
           icon, avg, color);
}
