
OUTPUT ?= helper
SOURCES := helper.c thermal_state.m
HEADERS := battery.h calendar.h cpu.h fan.h memory.h network.h smc.h temperature.h thermal_state.h power.h sketchybar.h

.PHONY: helper
helper: $(SOURCES) $(HEADERS)
	clang -std=c99 -O3 -Wall -Wextra -Werror \
	  -framework IOKit -framework CoreFoundation -framework Foundation \
	  $(SOURCES) -o "$(OUTPUT).new"
	mv -f "$(OUTPUT).new" "$(OUTPUT)"
