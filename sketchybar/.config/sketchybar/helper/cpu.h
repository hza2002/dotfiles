#pragma once
#include <mach/mach.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct cpu {
  host_t                    host;
  mach_msg_type_number_t    count;
  host_cpu_load_info_data_t load;
  host_cpu_load_info_data_t prev_load;
  bool                      has_prev_load;
  char                      command[96];
};

static inline void cpu_init(struct cpu *cpu) {
  cpu->host         = mach_host_self();
  cpu->count        = HOST_CPU_LOAD_INFO_COUNT;
  cpu->has_prev_load = false;
  cpu->command[0]   = '\0';

  // Prime prev_load so the first cpu_update has a baseline and renders a real
  // percentage on the first tick instead of an empty label.
  if (host_statistics(cpu->host, HOST_CPU_LOAD_INFO,
                      (host_info_t)&cpu->load, &cpu->count) == KERN_SUCCESS) {
    cpu->prev_load = cpu->load;
    cpu->has_prev_load = true;
  }
}

static inline void cpu_update(struct cpu *cpu) {
  kern_return_t error = host_statistics(cpu->host, HOST_CPU_LOAD_INFO,
                                        (host_info_t)&cpu->load, &cpu->count);
  if (error != KERN_SUCCESS) return;

  if (cpu->has_prev_load) {
    uint32_t delta_user   = cpu->load.cpu_ticks[CPU_STATE_USER]
                          - cpu->prev_load.cpu_ticks[CPU_STATE_USER];
    uint32_t delta_system = cpu->load.cpu_ticks[CPU_STATE_SYSTEM]
                          - cpu->prev_load.cpu_ticks[CPU_STATE_SYSTEM];
    uint32_t delta_idle   = cpu->load.cpu_ticks[CPU_STATE_IDLE]
                          - cpu->prev_load.cpu_ticks[CPU_STATE_IDLE];
    uint32_t delta_total  = delta_user + delta_system + delta_idle;

    if (delta_total == 0) { cpu->prev_load = cpu->load; return; }

    double total_perc = (double)(delta_user + delta_system) / (double)delta_total;

    int pct = (int)(total_perc * 100.0 + 0.5);

    // 7-tier HARD-only gradient. SOFT variants are too light against
    // the dark bar background and read as white at a glance.
    const char *color;
    if      (pct >= 90) color = getenv("PURPLE_HARD");
    else if (pct >= 80) color = getenv("RED_HARD");
    else if (pct >= 70) color = getenv("ORANGE_HARD");
    else if (pct >= 50) color = getenv("YELLOW_HARD");
    else if (pct >= 30) color = getenv("GREEN_HARD");
    else if (pct >= 10) color = getenv("AQUA_HARD");
    else                color = getenv("BLUE_HARD");

    if (!color || color[0] == '\0') color = "0xffffffff";

    // 2-tier icon: HIGH at YELLOW threshold (sustained load), else LOW.
    const char *icon = getenv(pct >= 50 ? "SYS_CPU_HIGH" : "SYS_CPU_LOW");
    if (!icon || icon[0] == '\0') icon = "";

    snprintf(cpu->command, sizeof(cpu->command),
             "--set cpu icon=%s label=%d%% background.color=%s",
             icon, pct, color);
  }

  cpu->prev_load    = cpu->load;
  cpu->has_prev_load = true;
}
