#pragma once
#include <mach/mach.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/sysctl.h>

struct memory {
  host_t    host;
  uint64_t  total_pages;
  vm_size_t page_size;
  char      command[256];
};

static inline void memory_init(struct memory *mem) {
  mem->host = mach_host_self();

  host_basic_info_data_t basic_info;
  mach_msg_type_number_t count = HOST_BASIC_INFO_COUNT;
  host_info(mem->host, HOST_BASIC_INFO, (host_info_t)&basic_info, &count);
  host_page_size(mem->host, &mem->page_size);
  mem->total_pages = basic_info.max_mem / mem->page_size;

  snprintf(mem->command, sizeof(mem->command), "");
}

static inline void memory_update(struct memory *mem) {
  // wired + compressor physical pages (one kernel call, no fork)
  mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;
  vm_statistics64_data_t vm_stat;
  if (host_statistics64(mem->host, HOST_VM_INFO64,
                        (host_info64_t)&vm_stat, &count) != KERN_SUCCESS) return;

  // swap used (one sysctl, microsecond-level)
  struct xsw_usage swap = {0};
  size_t swap_size = sizeof(swap);
  sysctlbyname("vm.swapusage", &swap, &swap_size, NULL, 0);
  uint64_t swap_pages = swap.xsu_used / mem->page_size;

  uint64_t pressure_pages = vm_stat.wire_count
                           + vm_stat.compressor_page_count
                           + swap_pages;

  int pressure = (int)(100.0 * (double)pressure_pages / (double)mem->total_pages + 0.5);

  // 7-tier HARD-only gradient. Rescaled low — 32GB+ M1 Max idles ~20%.
  const char *color;
  if      (pressure >= 85) color = getenv("PURPLE_HARD");
  else if (pressure >= 70) color = getenv("RED_HARD");
  else if (pressure >= 50) color = getenv("ORANGE_HARD");
  else if (pressure >= 30) color = getenv("YELLOW_HARD");
  else if (pressure >= 15) color = getenv("GREEN_HARD");
  else if (pressure >= 5)  color = getenv("AQUA_HARD");
  else                     color = getenv("BLUE_HARD");

  if (!color || color[0] == '\0') color = "0xffffffff";

  snprintf(mem->command, sizeof(mem->command),
           "--set mem label=%d%% background.color=%s",
           pressure, color);
}
