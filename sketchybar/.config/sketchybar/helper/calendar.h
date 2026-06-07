#pragma once
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define CALENDAR_STATE_PATH "/tmp/sketchybar-calendar-precision"

struct calendar {
  char command[256];
};

static inline void calendar_init(struct calendar *c) {
  c->command[0] = '\0';
}

static inline void calendar_update(struct calendar *c) {
  bool seconds = false;
  FILE *f = fopen(CALENDAR_STATE_PATH, "r");
  if (f) {
    char buf[8] = {0};
    if (fgets(buf, sizeof(buf), f) && strcmp(buf, "second\n") == 0)
      seconds = true;
    fclose(f);
  }

  time_t now = time(NULL);
  struct tm *tm = localtime(&now);

  char date_str[16];
  strftime(date_str, sizeof(date_str), "%a %d. %b", tm);

  char time_str[16];
  strftime(time_str, sizeof(time_str), seconds ? "%H:%M:%S" : "%H:%M", tm);

  snprintf(c->command, sizeof(c->command),
           "--set calendar icon=\"%s\" label=\"%s\"",
           date_str, time_str);
}
