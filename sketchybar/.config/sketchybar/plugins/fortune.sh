#!/bin/bash

FORTUNE=$(fortune -s -n 70 | tr -d '\n' | sed 's/--.*//' | sed 's/[[:space:]]*$//')
# FORTUNE=$(quote | tr -d '\n' | sed 's/-.*//' | sed 's/[[:space:]]*$//')

sketchybar --set fortune label="$FORTUNE"
