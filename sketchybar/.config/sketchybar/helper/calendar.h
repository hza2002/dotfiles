#pragma once
#include <stdio.h>
#include <time.h>

struct calendar {
  char command[256];
};

static inline void calendar_init(struct calendar *c) {
  c->command[0] = '\0';
}

static inline void calendar_update(struct calendar *c) {
  time_t now = time(NULL);
  struct tm *tm = localtime(&now);

  char weekday[8];
  strftime(weekday, sizeof(weekday), "%a", tm);

  char date_str[16];
  snprintf(date_str, sizeof(date_str), "%s %d/%d",
           weekday, tm->tm_mon + 1, tm->tm_mday);

  char time_str[16];
  strftime(time_str, sizeof(time_str), "%H:%M", tm);

  snprintf(c->command, sizeof(c->command),
           "--set calendar icon=\"%s\" label=\"%s\"",
           date_str, time_str);
}
