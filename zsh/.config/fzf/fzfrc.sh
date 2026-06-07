# Scheme name: Gruvbox dark, medium
# Scheme system: base16
# Scheme author: Dawid Kurek (dawikur@gmail.com), morhetz (https://github.com/morhetz/gruvbox)
# Template author: Tinted Theming (https://github.com/tinted-theming)

_gen_fzf_default_opts() {

local color00='#282828'
local color01='#3c3836'
local color02='#504945'
local color03='#665c54'
local color04='#bdae93'
local color05='#d5c4a1'
local color06='#ebdbb2'
local color07='#fbf1c7'
local color08='#fb4934'
local color09='#fe8019'
local color0A='#fabd2f'
local color0B='#b8bb26'
local color0C='#8ec07c'
local color0D='#83a598'
local color0E='#d3869b'
local color0F='#d65d0e'

FZF_DEFAULT_OPTS='--no-height --no-reverse'
export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS"\
" --color=bg+:$color01,bg:$color00,spinner:$color0C,hl:$color0D"\
" --color=fg:$color04,header:$color0D,info:$color0A,pointer:$color0C"\
" --color=marker:$color0C,fg+:$color06,prompt:$color0A,hl+:$color0D"
}

_gen_fzf_default_opts

export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow'
export FZF_CTRL_T_COMMAND='fd --type f --type l --hidden --follow'
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow'

# Paste the selected files and directories onto the command-line
# --preview '[ -d {} ] && { tree -C {}; } || { bat -n --color=always {}; }'
export FZF_CTRL_T_OPTS="--select-1 --exit-0 
  --preview '$HOME/.config/fzf/fzf-preview.sh {}'
  --bind '?:change-preview-window(down|hidden|)'"
# Paste the selected command from history onto the command-line
export FZF_CTRL_R_OPTS="
  --preview 'echo {} | bat --language=bash --style=plain --color=always --paging=never'
  --preview-window down:3:hidden:wrap
  --bind '?:toggle-preview'"
# export FZF_ALT_C_OPTS=


source <(fzf --zsh)

# Build "history index + age + command" lines from zsh history.
__fzf_history_with_age() {
  fc -rl -i -t '%s' 1 |
    sed -E 's/^ *//' |
    perl -MPOSIX=strftime -ne '
      chomp;
      if (/^\s*([0-9]+)\**\s+([0-9]+)\s+(.*)$/s) {
        $idx = $1;
        $ts = $2;
        $cmd = $3;
        $delta = time - $ts;
        $delta_days = int($delta / 86400);

        if ($delta < 0) { $age = "+" . int((-$delta) / 86400) . "d"; }
        elsif ($delta_days < 1 && $delta < 72000) { $age = strftime("%H:%M", localtime($ts)); }
        elsif ($delta_days == 0) { $age = "1d"; }
        else { $age = $delta_days . "d"; }

        next if $seen{$cmd}++;
        print "$idx $age $cmd\n";
      }
    '
}

# Based on fzf's upstream widget. Only the history list generation differs when EXTENDED_HISTORY is on.
fzf-history-widget() {
  local selected extracted_with_perl=0 extracted_with_age=0
  setopt localoptions noglobsubst noposixbuiltins pipefail no_aliases no_glob no_ksharrays extendedglob 2> /dev/null
  if [[ -o extended_history ]] && zmodload -F zsh/parameter p:commands 2>/dev/null && (( ${+commands[perl]} )); then
    selected="$(__fzf_history_with_age |
      FZF_DEFAULT_OPTS=$(__fzf_defaults "" "--with-nth=2.. --scheme=history --bind=ctrl-r:toggle-sort,alt-r:toggle-raw --wrap-sign '\t↳ ' --highlight-line --multi ${FZF_CTRL_R_OPTS-} --query=${(qqq)LBUFFER}") \
      FZF_DEFAULT_OPTS_FILE='' $(__fzfcmd))"
    extracted_with_age=1
  elif zmodload -F zsh/parameter p:{commands,history} 2>/dev/null && (( ${+commands[perl]} )); then
    selected="$(printf '%s\t%s\000' "${(kv)history[@]}" |
      perl -0 -ne 'if (!$seen{(/^\s*[0-9]+\**\t(.*)/s, $1)}++) { s/\n/\n\t/g; print; }' |
      FZF_DEFAULT_OPTS=$(__fzf_defaults "" "-n2..,.. --scheme=history --bind=ctrl-r:toggle-sort,alt-r:toggle-raw --wrap-sign '\t↳ ' --highlight-line --multi ${FZF_CTRL_R_OPTS-} --query=${(qqq)LBUFFER} --read0") \
      FZF_DEFAULT_OPTS_FILE='' $(__fzfcmd))"
    extracted_with_perl=1
  else
    selected="$(fc -rl 1 | __fzf_exec_awk '{ cmd=$0; sub(/^[ \t]*[0-9]+\**[ \t]+/, "", cmd); if (!seen[cmd]++) print $0 }' |
      FZF_DEFAULT_OPTS=$(__fzf_defaults "" "-n2..,.. --scheme=history --bind=ctrl-r:toggle-sort,alt-r:toggle-raw --wrap-sign '\t↳ ' --highlight-line --multi ${FZF_CTRL_R_OPTS-} --query=${(qqq)LBUFFER}") \
      FZF_DEFAULT_OPTS_FILE='' $(__fzfcmd))"
  fi
  local ret=$?
  local -a cmds
  local -a mbegin mend match
  local line
  if [ -n "$selected" ]; then
    if ((( extracted_with_perl )) && [[ $selected == <->$'\t'* ]]) ||
    ((( extracted_with_age )) && [[ $selected == [[:blank:]]#<->[[:blank:]]##[^[:blank:]]##[[:blank:]]* ]]) ||
    ((( ! extracted_with_perl && ! extracted_with_age )) && [[ $selected == [[:blank:]]#<->(  |\* )* ]]); then
      for line in ${(ps:\n:)selected}; do
        if (( extracted_with_perl )); then
          if [[ $line == (#b)(<->)(#B)$'\t'* ]]; then
            (( ${+history[${match[1]}]} )) && cmds+=("${history[${match[1]}]}")
          fi
        elif (( extracted_with_age )); then
          if [[ $line == [[:blank:]]#(#b)(<->)(#B)[[:blank:]]##[^[:blank:]]##[[:blank:]]* ]]; then
            zle .push-line
            zle vi-fetch-history -n ${match[1]}
            (( ${#BUFFER} )) && cmds+=("${BUFFER}")
            BUFFER=""
            zle .get-line
          fi
        elif [[ $line == [[:blank:]]#(#b)(<->)(#B)(  |\* )* ]]; then
          zle .push-line
          zle vi-fetch-history -n ${match[1]}
          (( ${#BUFFER} )) && cmds+=("${BUFFER}")
          BUFFER=""
          zle .get-line
        fi
      done
      if (( ${#cmds[@]} )); then
        BUFFER="${(pj:\n:)${(@)cmds%%$'\n'#}}"
        CURSOR=${#BUFFER}
      fi
    else
      LBUFFER="$selected"
    fi
  fi
  zle reset-prompt
  return $ret
}
