#!/bin/sh

set -eu

selection=$(
  sesh list --icons --hide-duplicates |
    fzf \
      --ansi \
      --scheme=default \
      --tiebreak=begin,length,index \
      --nth=2.. \
      --layout=reverse \
      --prompt='> ' \
      --preview='sesh preview {}' \
      --preview-window='right:55%:wrap'
) || exit 0

[ -n "$selection" ] || exit 0
exec sesh connect "$selection"
