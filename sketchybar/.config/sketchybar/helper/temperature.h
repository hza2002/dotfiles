#pragma once
#include "smc.h"
#include "thermal_state.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <limits.h>
#include <sys/stat.h>
#include <unistd.h>

#define TP_MAX_KEYS   64

// Reports the average of all readable SMC Tp* sensors. Apple does not publish
// the meaning of every Tp* key, so this is a machine-specific temperature
// aggregate, not a package temperature or hottest-core reading. Key names are
// cached in the user's SketchyBar cache directory to avoid enumerating the
// full SMC key set (~2k entries) on each helper start.
struct temperature {
  char tp_keys[TP_MAX_KEYS][5];
  int  tp_count;
  char command[320];
};

static inline FILE *temperature_open_cache(bool writing) {
  const char *home = getenv("HOME");
  char path[PATH_MAX];
  if (!home || home[0] != '/') return NULL;
  int length = snprintf(path, sizeof(path), "%s/Library/Caches/sketchybar", home);
  if (length < 0 || (size_t)length >= sizeof(path)) return NULL;

  // start.sh owns directory creation. Cache failures only skip persistence.
  int dir = open(path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
  if (dir < 0) return NULL;
  struct stat st;
  if (fstat(dir, &st) != 0 || st.st_uid != getuid() || (st.st_mode & 077) != 0) {
    close(dir);
    return NULL;
  }
  int flags = writing ? O_WRONLY | O_CREAT : O_RDONLY;
  int fd = openat(dir, "smc-tp-keys", flags | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC, 0600);
  close(dir);
  if (fd < 0) return NULL;
  if (fstat(fd, &st) != 0 || !S_ISREG(st.st_mode) || st.st_uid != getuid()
      || st.st_nlink != 1
      || (writing && (fchmod(fd, 0600) != 0 || ftruncate(fd, 0) != 0))) {
    close(fd);
    return NULL;
  }
  FILE *f = fdopen(fd, writing ? "w" : "r");
  if (!f) close(fd);
  return f;
}

static inline void temperature_load_cache(struct temperature *t) {
  FILE *f = temperature_open_cache(false);
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
  FILE *f = temperature_open_cache(true);
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

static inline const char *temperature_color_for(int temp) {
  const char *name;
  if      (temp <  0) name = "GRAY_HARD";
  else if (temp >= 90) name = "PURPLE_HARD";
  else if (temp >= 80) name = "RED_HARD";
  else if (temp >= 70) name = "ORANGE_HARD";
  else if (temp >= 55) name = "YELLOW_HARD";
  else if (temp >= 40) name = "GREEN_HARD";
  else if (temp >= 30) name = "AQUA_HARD";
  else                 name = "BLUE_HARD";

  const char *color = getenv(name);
  return color && color[0] != '\0' ? color : "0xffffffff";
}

static inline const char *temperature_icon_for(int temp) {
  const char *name;
  if      (temp >= 80) name = "SYS_TEMP_HIGH";
  else if (temp >= 55) name = "SYS_TEMP_MEDIUM";
  else                 name = "SYS_TEMP_LOW";

  const char *icon = getenv(name);
  return icon && icon[0] != '\0' ? icon : "";
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

  const char *color = temperature_color_for(temp);
  const char *icon = temperature_icon_for(temp);

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
