#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "../helper/temperature.h"

struct temperature_case {
  int temp;
  const char *color;
  const char *icon;
};

static int failures = 0;

static void check_case(const struct temperature_case *test) {
  const char *color = temperature_color_for(test->temp);
  const char *icon = temperature_icon_for(test->temp);

  if (strcmp(color, test->color) != 0) {
    fprintf(stderr, "temperature %d: color %s, expected %s\n",
            test->temp, color, test->color);
    failures++;
  }
  if (strcmp(icon, test->icon) != 0) {
    fprintf(stderr, "temperature %d: icon %s, expected %s\n",
            test->temp, icon, test->icon);
    failures++;
  }
}

static void check_cache(void) {
  struct temperature saved = {.tp_keys = {"Tp01", "Tp02"}, .tp_count = 2};
  struct temperature loaded = {0};
  temperature_save_cache(&saved);
  temperature_load_cache(&loaded);
  if (loaded.tp_count != 2 || strcmp(loaded.tp_keys[1], "Tp02") != 0) failures++;
  saved.tp_count = 1;
  temperature_save_cache(&saved);
  loaded.tp_count = 0;
  temperature_load_cache(&loaded);
  struct stat st;
  if (loaded.tp_count != 1 || stat("smc-tp-keys", &st) != 0
      || st.st_size != 5 || (st.st_mode & 0777) != 0600) failures++;

  rename("smc-tp-keys", "original");
  symlink("original", "smc-tp-keys");
  saved.tp_count = 2;
  temperature_save_cache(&saved);
  loaded.tp_count = 0;
  temperature_load_cache(&loaded);
  if (loaded.tp_count != 0 || stat("original", &st) != 0 || st.st_size != 5) failures++;
  unlink("smc-tp-keys");
  mkfifo("smc-tp-keys", 0600);
  if (temperature_open_cache(false) || temperature_open_cache(true)) failures++;
  unlink("smc-tp-keys");
  if (temperature_open_cache(false)) failures++;
  chmod(".", 0755);
  if (temperature_open_cache(true)) failures++;
  chmod(".", 0700);
}

int main(int argc, char **argv) {
  if (argc != 2 || setenv("HOME", argv[1], 1) != 0) return 1;
  char cache_dir[PATH_MAX];
  snprintf(cache_dir, sizeof(cache_dir), "%s/Library/Caches/sketchybar", argv[1]);
  if (chdir(cache_dir) != 0) return 1;
  check_cache();
  const char *colors[] = {
    "GRAY_HARD", "BLUE_HARD", "AQUA_HARD", "GREEN_HARD",
    "YELLOW_HARD", "ORANGE_HARD", "RED_HARD", "PURPLE_HARD",
  };
  const char *icons[] = {
    "SYS_TEMP_LOW", "SYS_TEMP_MEDIUM", "SYS_TEMP_HIGH",
  };

  for (size_t i = 0; i < sizeof(colors) / sizeof(colors[0]); i++) {
    setenv(colors[i], colors[i], 1);
  }
  for (size_t i = 0; i < sizeof(icons) / sizeof(icons[0]); i++) {
    setenv(icons[i], icons[i], 1);
  }

  const struct temperature_case cases[] = {
    {-1, "GRAY_HARD", "SYS_TEMP_LOW"},
    {0, "BLUE_HARD", "SYS_TEMP_LOW"},
    {29, "BLUE_HARD", "SYS_TEMP_LOW"},
    {30, "AQUA_HARD", "SYS_TEMP_LOW"},
    {39, "AQUA_HARD", "SYS_TEMP_LOW"},
    {40, "GREEN_HARD", "SYS_TEMP_LOW"},
    {54, "GREEN_HARD", "SYS_TEMP_LOW"},
    {55, "YELLOW_HARD", "SYS_TEMP_MEDIUM"},
    {69, "YELLOW_HARD", "SYS_TEMP_MEDIUM"},
    {70, "ORANGE_HARD", "SYS_TEMP_MEDIUM"},
    {79, "ORANGE_HARD", "SYS_TEMP_MEDIUM"},
    {80, "RED_HARD", "SYS_TEMP_HIGH"},
    {89, "RED_HARD", "SYS_TEMP_HIGH"},
    {90, "PURPLE_HARD", "SYS_TEMP_HIGH"},
  };

  for (size_t i = 0; i < sizeof(cases) / sizeof(cases[0]); i++) {
    check_case(&cases[i]);
  }

  if (failures != 0) return 1;
  printf("ok - temperature boundaries and private bounded cache\n");
  return 0;
}
