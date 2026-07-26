
OUTPUT ?=
SOURCES := helper.c thermal_state.m
HEADERS := battery.h calendar.h cpu.h fan.h memory.h network.h smc.h temperature.h thermal_state.h power.h sketchybar.h

.PHONY: helper
helper: $(SOURCES) $(HEADERS)
	@test -n "$(OUTPUT)" || { echo "OUTPUT is required; run ./install.sh" >&2; exit 64; }
	clang -std=c99 -O3 -Wall -Wextra -Werror \
	  -framework IOKit -framework CoreFoundation -framework Foundation \
	  $(SOURCES) -o "$(OUTPUT)"
