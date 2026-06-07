#include "battery.h"
#include "calendar.h"
#include "cpu.h"
#include "memory.h"
#include "network.h"
#include "smc.h"
#include "temperature.h"
#include "power.h"
#include "sketchybar.h"

struct cpu         g_cpu;
struct memory      g_memory;
struct network     g_network;
struct temperature g_temperature;
struct power       g_power;
struct battery     g_battery;
struct calendar    g_calendar;

void handler(env env) {
  char *name = env_get_value_for_key(env, "NAME");

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
  } else if (strcmp(name, "battery") == 0) {
    battery_update(&g_battery);
    if (strlen(g_battery.command) > 0)
      sketchybar(g_battery.command);
  } else if (strcmp(name, "calendar") == 0) {
    calendar_update(&g_calendar);
    if (strlen(g_calendar.command) > 0)
      sketchybar(g_calendar.command);
  }
}

int main(int argc, char **argv) {
  cpu_init(&g_cpu);
  memory_init(&g_memory);
  network_init(&g_network);
  smc_init();
  temperature_init(&g_temperature);
  power_init(&g_power);
  battery_init(&g_battery);
  calendar_init(&g_calendar);

  if (argc < 2) {
    printf("Usage: helper \"<bootstrap name>\"\n");
    exit(1);
  }

  event_server_begin(handler, argv[1]);
  return 0;
}
