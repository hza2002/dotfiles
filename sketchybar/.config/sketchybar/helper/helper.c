#include "battery.h"
#include "calendar.h"
#include "cpu.h"
#include "fan.h"
#include "memory.h"
#include "network.h"
#include "smc.h"
#include "temperature.h"
#include "power.h"
#include "sketchybar.h"
#include <signal.h>
#include <string.h>

struct cpu         g_cpu;
struct memory      g_memory;
struct network     g_network;
struct temperature g_temperature;
struct power       g_power;
struct fan         g_fan;
struct battery     g_battery;
struct calendar    g_calendar;

static volatile sig_atomic_t g_last_signal = 0;

static void handle_signal(int sig) {
  g_last_signal = sig;
  const char msg[] = "sketchybar helper received signal\n";
  (void)write(STDERR_FILENO, msg, sizeof(msg) - 1);
  _exit(128 + sig);
}

static void log_exit(void) {
  if (g_last_signal == 0) helper_log("exiting normally");
}

void handler(env env) {
  if (!env) {
    helper_log("handler called with null env");
    return;
  }
  char *name = env_get_value_for_key(env, "NAME");
  if (!name || name[0] == '\0') return;

  if (strcmp(name, "cpu") == 0) {
    cpu_update(&g_cpu);
    if (strlen(g_cpu.command) > 0)
      sketchybar(g_cpu.command);
  } else if (strcmp(name, "mem") == 0) {
    memory_update(&g_memory);
    if (strlen(g_memory.command) > 0)
      sketchybar(g_memory.command);
  } else if (strcmp(name, "network_up") == 0) {
    network_update(&g_network);
    if (strlen(g_network.command) > 0)
      sketchybar(g_network.command);
  } else if (strcmp(name, "temp") == 0) {
    temperature_update(&g_temperature);
    if (strlen(g_temperature.command) > 0)
      sketchybar(g_temperature.command);
  } else if (strcmp(name, "power") == 0) {
    power_update(&g_power);
    if (strlen(g_power.command) > 0)
      sketchybar(g_power.command);
  } else if (strcmp(name, "fan") == 0) {
    fan_update(&g_fan);
    if (strlen(g_fan.command) > 0)
      sketchybar(g_fan.command);
  } else if (strcmp(name, "battery") == 0) {
    battery_update(&g_battery);
    if (strlen(g_battery.command) > 0)
      sketchybar(g_battery.command);
  } else if (strcmp(name, "calendar") == 0) {
    calendar_update(&g_calendar);
    if (strlen(g_calendar.command) > 0)
      sketchybar(g_calendar.command);
  } else {
    helper_log("unknown event name='%s'", name);
  }
}

int main(int argc, char **argv) {
  atexit(log_exit);
  signal(SIGTERM, handle_signal);
  signal(SIGINT, handle_signal);
  signal(SIGHUP, handle_signal);

  if (argc < 2) {
    helper_log("missing bootstrap name");
    printf("Usage: helper \"<bootstrap name>\"\n");
    exit(1);
  }

  helper_log("starting bootstrap=%s", argv[1]);
  cpu_init(&g_cpu);
  memory_init(&g_memory);
  network_init(&g_network);
  if (!smc_init()) helper_log("smc_init failed");
  temperature_init(&g_temperature);
  power_init(&g_power);
  fan_init(&g_fan);
  battery_init(&g_battery);
  calendar_init(&g_calendar);

  event_server_begin(handler, argv[1]);
  return 0;
}
