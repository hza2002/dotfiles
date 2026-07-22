#pragma once
#include <mach/mach.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/sysctl.h>

struct memory {
  host_t    host;
  uint64_t  total_pages;
  vm_size_t page_size;
  char      command[1024];
};

enum memory_pressure_level {
  MEMORY_PRESSURE_NORMAL   = 1,
  MEMORY_PRESSURE_WARNING  = 2,
  MEMORY_PRESSURE_CRITICAL = 4,
};

static inline double memory_pages_gib(const struct memory *mem,
                                      uint64_t pages) {
  return (double)pages * (double)mem->page_size / (1024.0 * 1024.0 * 1024.0);
}

static inline void memory_init(struct memory *mem) {
  mem->total_pages = 0;
  mem->page_size = 0;
  mem->command[0] = '\0';
  mem->host = mach_host_self();

  host_basic_info_data_t basic_info;
  mach_msg_type_number_t count = HOST_BASIC_INFO_COUNT;
  if (host_info(mem->host, HOST_BASIC_INFO,
                (host_info_t)&basic_info, &count) != KERN_SUCCESS) return;
  if (host_page_size(mem->host, &mem->page_size) != KERN_SUCCESS ||
      mem->page_size == 0) return;
  mem->total_pages = basic_info.max_mem / mem->page_size;
}

static inline void memory_update(struct memory *mem) {
  mem->command[0] = '\0';
  if (mem->total_pages == 0) return;

  // Physical RAM in use: app/anonymous + wired + compressor, excluding
  // purgeable pages that macOS can reclaim without paging.
  mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;
  vm_statistics64_data_t vm_stat;
  if (host_statistics64(mem->host, HOST_VM_INFO64,
                        (host_info64_t)&vm_stat, &count) != KERN_SUCCESS) return;

  uint64_t app_pages = vm_stat.internal_page_count > vm_stat.purgeable_count
                     ? vm_stat.internal_page_count - vm_stat.purgeable_count
                     : 0;
  uint64_t used_pages = app_pages
                      + vm_stat.wire_count
                      + vm_stat.compressor_page_count;
  if (used_pages > mem->total_pages) used_pages = mem->total_pages;
  int used_percent = (int)(100.0 * (double)used_pages /
                           (double)mem->total_pages + 0.5);

  // Capacity and health are separate signals. Let the kernel's pressure state
  // drive the color and icon instead of inferring health from RAM occupancy.
  int pressure_level = 0;
  size_t pressure_size = sizeof(pressure_level);
  bool pressure_known =
    sysctlbyname("kern.memorystatus_vm_pressure_level", &pressure_level,
                 &pressure_size, NULL, 0) == 0 &&
    pressure_size == sizeof(pressure_level);

  const char *color = getenv("GRAY_HARD");
  const char *pressure_text = "未知";
  bool pressure_high = false;
  if (pressure_known) {
    switch (pressure_level) {
      case MEMORY_PRESSURE_NORMAL:
        color = getenv("GREEN_HARD");
        pressure_text = "正常·无需处理";
        break;
      case MEMORY_PRESSURE_WARNING:
        color = getenv("YELLOW_HARD");
        pressure_text = "偏高·正在回收";
        pressure_high = true;
        break;
      case MEMORY_PRESSURE_CRITICAL:
        color = getenv("RED_HARD");
        pressure_text = "严重·请关闭重负载";
        pressure_high = true;
        break;
      default:
        color = getenv("GRAY_HARD");
        break;
    }
  }

  if (!color || color[0] == '\0') color = "0xffffffff";

  const char *icon = getenv(pressure_high ? "SYS_MEM_HIGH" : "SYS_MEM_LOW");
  if (!icon || icon[0] == '\0') icon = "";

  // Keep the popup breakdown mutually exclusive. speculative_count is already
  // included in both free_count and external_page_count, so remove it from
  // cached pages to avoid double counting.
  uint64_t cached_pages = (uint64_t)vm_stat.external_page_count
                        + vm_stat.purgeable_count;
  cached_pages = cached_pages > vm_stat.speculative_count
               ? cached_pages - vm_stat.speculative_count
               : 0;

  struct xsw_usage swap = {0};
  size_t swap_size = sizeof(swap);
  bool swap_known = sysctlbyname("vm.swapusage", &swap, &swap_size, NULL, 0) == 0
                 && swap_size == sizeof(swap);
  char swap_label[32];
  if (swap_known) {
    snprintf(swap_label, sizeof(swap_label), "%.1fGB",
             (double)swap.xsu_used / (1024.0 * 1024.0 * 1024.0));
  } else {
    snprintf(swap_label, sizeof(swap_label), "未知");
  }

  int written = snprintf(
    mem->command, sizeof(mem->command),
    "--set mem icon=%s label=%d%% background.color=%s "
    "--set mem.pressure label=%s label.color=%s "
    "--set mem.total label=%.0fGB "
    "--set mem.app label=%.1fGB "
    "--set mem.wired label=%.1fGB "
    "--set mem.compressed label=%.1fGB "
    "--set mem.cached label=%.1fGB "
    "--set mem.swap label=%s",
    icon, used_percent, color,
    pressure_text, color,
    memory_pages_gib(mem, mem->total_pages),
    memory_pages_gib(mem, app_pages),
    memory_pages_gib(mem, vm_stat.wire_count),
    memory_pages_gib(mem, vm_stat.compressor_page_count),
    memory_pages_gib(mem, cached_pages),
    swap_label);
  if (written < 0 || (size_t)written >= sizeof(mem->command)) {
    mem->command[0] = '\0';
  }
}
