FZF_DEFAULT_OPTS='--no-height --no-reverse'
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
