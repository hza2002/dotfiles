#pragma once
#include "smc.h"
#include "thermal_state.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define TP_CACHE_PATH "/tmp/sketchybar-smc-tp-keys"
#define TP_MAX_KEYS   64

// CPU temperature widget. Reports the average of all SMC Tp* sensors
// (performance-core thermal readings) — matches the convention used by
// iStat Menus and stats. Tp key names are cached in /tmp so we only
// enumerate the full SMC key set (~2k entries) once per boot.
struct temperature {
  char tp_keys[TP_MAX_KEYS][5];
  int  tp_count;
  char command[320];
};

static inline void temperature_load_cache(struct temperature *t) {
  FILE *f = fopen(TP_CACHE_PATH, "r");
  if (!f) return;
  char line[32];
  while (t->tp_count < TP_MAX_KEYS && fgets(line, sizeof(line), f)) {
    size_t len = strlen(line);
    while (len > 0 && (line[len - 1] == '\n' || line[len - 1] == '\r')) {
      line[--len] = 0;
    }
    if (len == 4) {
      memcpy(t->tp_keys[t->tp_count], line, 4);
      t->tp_keys[t->tp_count][4] = 0;
      t->tp_count++;
    }
  }
  fclose(f);
}

static inline void temperature_save_cache(const struct temperature *t) {
  FILE *f = fopen(TP_CACHE_PATH, "w");
  if (!f) return;
  for (int i = 0; i < t->tp_count; i++) fprintf(f, "%s\n", t->tp_keys[i]);
  fclose(f);
}

static inline void temperature_enumerate(struct temperature *t) {
  t->tp_count = 0;
  uint32_t count = smc_key_count();
  for (uint32_t i = 0; i < count && t->tp_count < TP_MAX_KEYS; i++) {
    char ks[5];
    if (!smc_key_at_index(i, ks)) continue;
    if (ks[0] == 'T' && ks[1] == 'p') {
      memcpy(t->tp_keys[t->tp_count], ks, 5);
      t->tp_count++;
    }
  }
}

static inline void temperature_init(struct temperature *t) {
  t->tp_count = 0;
  t->command[0] = '\0';
  temperature_load_cache(t);
  if (t->tp_count == 0) {
    temperature_enumerate(t);
    if (t->tp_count > 0) temperature_save_cache(t);
  }
}

static inline int temperature_read(const struct temperature *t, int *maximum) {
  double sum = 0;
  int n = 0;
  *maximum = -1;
  for (int i = 0; i < t->tp_count; i++) {
    float v = 0.f;
    if (smc_read_float(t->tp_keys[i], &v) && v > 0.f && v < 150.f) {
      sum += v;
      n++;
      int rounded = (int)(v + 0.5f);
      if (rounded > *maximum) *maximum = rounded;
    }
  }
  return n > 0 ? (int)(sum / n + 0.5) : -1;
}

static inline void temperature_update(struct temperature *t) {
  int maximum = -1;
  int temp = temperature_read(t, &maximum);

  // Cache went stale (firmware/macOS update may have renamed keys).
  if (temp < 0 && t->tp_count > 0) {
    temperature_enumerate(t);
    if (t->tp_count > 0) {
      temperature_save_cache(t);
      temp = temperature_read(t, &maximum);
    }
  }

  // 7-tier HARD-only gradient tuned for M1 Max thermals.
  const char *color;
  if      (temp >= 85) color = getenv("PURPLE_HARD");
  else if (temp >= 75) color = getenv("RED_HARD");
  else if (temp >= 60) color = getenv("ORANGE_HARD");
  else if (temp >= 50) color = getenv("YELLOW_HARD");
  else if (temp >= 40) color = getenv("GREEN_HARD");
  else if (temp >= 25) color = getenv("AQUA_HARD");
  else                 color = getenv("BLUE_HARD");
  if (!color || color[0] == '\0') color = "0xffffffff";

  // 3-tier icon: collapse the 7 color tiers onto LOW (<50) / MEDIUM
  // (50–74) / HIGH (≥75) to match SYS_TEMP_LOW/MEDIUM/HIGH glyphs.
  const char *icon;
  if      (temp >= 75) icon = getenv("SYS_TEMP_HIGH");
  else if (temp >= 50) icon = getenv("SYS_TEMP_MEDIUM");
  else                 icon = getenv("SYS_TEMP_LOW");
  if (!icon || icon[0] == '\0') icon = "";

  if (temp >= 0) {
    snprintf(t->command, sizeof(t->command),
             "--set temp icon=%s label=%d° background.color=%s "
             "--set temp.state label=%s "
             "--set temp.max label=%d°",
             icon, temp, color, thermal_state_text(), maximum);
  } else {
    snprintf(t->command, sizeof(t->command),
             "--set temp icon=%s label=--° background.color=%s "
             "--set temp.state label=%s "
             "--set temp.max label=--°",
             icon, color, thermal_state_text());
  }
}
