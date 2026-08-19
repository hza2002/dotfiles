#pragma once

#include <ifaddrs.h>
#include <net/if.h>
#include <net/if_dl.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/time.h>

struct network {
  uint64_t       prev_in;
  uint64_t       prev_out;
  struct timeval prev_time;
  bool           has_prev;
  char           command[512];
};

static inline bool network_skip_interface(const char *name) {
  return strncmp(name, "lo", 2) == 0
      || strncmp(name, "awdl", 4) == 0
      || strncmp(name, "llw", 3) == 0
      || strncmp(name, "bridge", 6) == 0
      || strncmp(name, "gif", 3) == 0
      || strncmp(name, "stf", 3) == 0
      || strncmp(name, "utun", 4) == 0;
}

static inline bool network_collect_counters(uint64_t *in, uint64_t *out) {
  struct ifaddrs *interfaces = NULL;
  if (getifaddrs(&interfaces) != 0) return false;

  *in = 0;
  *out = 0;

  for (struct ifaddrs *ifa = interfaces; ifa; ifa = ifa->ifa_next) {
    if (!ifa->ifa_addr || !ifa->ifa_data) continue;
    if (ifa->ifa_addr->sa_family != AF_LINK) continue;
    if ((ifa->ifa_flags & IFF_UP) == 0) continue;
    if ((ifa->ifa_flags & IFF_RUNNING) == 0) continue;
    if ((ifa->ifa_flags & IFF_LOOPBACK) != 0) continue;
    if (network_skip_interface(ifa->ifa_name)) continue;

    const struct if_data *data = (const struct if_data *)ifa->ifa_data;
    *in += data->ifi_ibytes;
    *out += data->ifi_obytes;
  }

  freeifaddrs(interfaces);
  return true;
}

static inline double network_elapsed_seconds(struct timeval *start,
                                             struct timeval *end) {
  return (double)(end->tv_sec - start->tv_sec)
       + (double)(end->tv_usec - start->tv_usec) / 1000000.0;
}

static inline void network_format_speed(uint64_t bytes_per_second,
                                        char *value,
                                        size_t value_size,
                                        char *unit,
                                        size_t unit_size) {
  double kbps = (double)bytes_per_second * 8.0 / 1000.0;

  if (kbps < 8.0) {
    snprintf(value, value_size, "%.0f", kbps);
    snprintf(unit, unit_size, "kb/s");
  } else if (kbps < 8000.0) {
    snprintf(value, value_size, "%.0f", kbps / 8.0);
    snprintf(unit, unit_size, "KB/s");
  } else {
    snprintf(value, value_size, "%.1f", kbps / 8000.0);
    snprintf(unit, unit_size, "MB/s");
  }
}

static inline void network_init(struct network *net) {
  net->prev_in = 0;
  net->prev_out = 0;
  net->prev_time = (struct timeval){0};
  net->has_prev = false;
  net->command[0] = '\0';

  // Prime counters so the first tick reports a real rate over the elapsed
  // wall time, rather than showing 0 KB/s for one update_freq cycle.
  if (network_collect_counters(&net->prev_in, &net->prev_out)) {
    gettimeofday(&net->prev_time, NULL);
    net->has_prev = true;
  }
}

static inline void network_update(struct network *net) {
  uint64_t in = 0;
  uint64_t out = 0;
  struct timeval now;

  if (!network_collect_counters(&in, &out)) return;
  gettimeofday(&now, NULL);

  uint64_t in_rate = 0;
  uint64_t out_rate = 0;

  if (net->has_prev) {
    double elapsed = network_elapsed_seconds(&net->prev_time, &now);
    if (elapsed > 0.0) {
      if (in >= net->prev_in) in_rate = (uint64_t)((double)(in - net->prev_in) / elapsed);
      if (out >= net->prev_out) out_rate = (uint64_t)((double)(out - net->prev_out) / elapsed);
    }
  }

  char down_value[16];
  char down_unit[8];
  char up_value[16];
  char up_unit[8];
  network_format_speed(in_rate, down_value, sizeof(down_value), down_unit, sizeof(down_unit));
  network_format_speed(out_rate, up_value, sizeof(up_value), up_unit, sizeof(up_unit));

  snprintf(net->command, sizeof(net->command),
           "--set network_down label=%s icon.highlight=%s "
           "--set network_down_unit label=%s "
           "--set network_up label=%s icon.highlight=%s "
           "--set network_up_unit label=%s",
           down_value, in_rate > 0 ? "on" : "off",
           down_unit,
           up_value, out_rate > 0 ? "on" : "off",
           up_unit);

  net->prev_in = in;
  net->prev_out = out;
  net->prev_time = now;
  net->has_prev = true;
}
