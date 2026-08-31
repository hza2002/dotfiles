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

int main(void) {
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
  printf("ok - temperature color and icon boundaries\n");
  return 0;
}
