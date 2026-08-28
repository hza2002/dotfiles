########################## 🔽 ENV 🔽 ###########################
# EDITOR / ZSH_OS / project *_HOME live in .zshenv (visible to all shells).
# brew shellenv / PATH live in .zprofile (login-time, inherited by tmux).
export GPG_TTY=$(tty) # interactive-only: tty has no meaning in scripts
# Ask pinentry-smart for the terminal (curses) UI over SSH/tmux; gpg forwards
# PINENTRY_USER_DATA to the pinentry program. GUI is used otherwise.
if [[ -n "$SSH_TTY" || -n "$SSH_CONNECTION" || -n "$TMUX" ]]; then
  export PINENTRY_USER_DATA=curses
fi
########################## 🔼 ENV 🔼 ###########################

########################## 🔽 OH MY ZSH 🔽 #####################
export ZSH="$HOME/.oh-my-zsh" # Path to oh-my-zsh installation.
ZSH_CACHE_DIR="${ZSH_CACHE_DIR:-$ZSH/cache}"
export ZSH_COMPDUMP="$ZSH_CACHE_DIR/.zcompdump-$HOST-$ZSH_VERSION"
typeset -U fpath
typeset +x FPATH # Function lookup is shell-local; do not duplicate it in nested shells.
plugins=( # https://github.com/ohmyzsh/ohmyzsh/wiki/Plugins
  # Silent
  colored-man-pages command-not-found shell-proxy
  # Commands
  extract
  # Disabled commands: copypath perms qrcode
  # Shortcut
  fancy-ctrl-z sudo thefuck tldr
  # Disabled aliases: aliases common-aliases
  git rust zoxide
  # Custom
  autoupdate fzf-tab you-should-use
  zsh-lazyload zsh-vi-mode zsh-abbr zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search
)
fpath+="${ZSH_CUSTOM:-"$ZSH/custom"}/plugins/zsh-completions/src" # https://github.com/zsh-users/zsh-completions/issues/603
zvm_after_init_commands+=( # zvm resets plugin bindings during deferred initialization.
  "source $HOME/.config/fzf/fzfrc.sh"
  'zvm_bindkey viins " " abbr-expand-and-insert'
  'zvm_bindkey viins "^ " magic-space'
)
source $ZSH/oh-my-zsh.sh
typeset -U fpath
########################## 🔼 OH MY ZSH 🔼 #####################

########################## 🔽 BIND KEY 🔽 ######################
function bindkey_zsh_vim() { bindkey -M vicmd $1 $2 && bindkey -M viins $1 $2 }
bindkey_zsh_vim "\e[A" history-substring-search-up # zsh-history-substring-search: Up arrow
bindkey_zsh_vim "\e[B" history-substring-search-down # zsh-history-substring-search: Down arrow
bindkey_zsh_vim "^Z" fancy-ctrl-z # fancy-ctrl-z
bindkey_zsh_vim "\es" sudo-command-line # sudo: alt-s
bindkey_zsh_vim "\ef" fuck-command-line # the fuck: alt-f
bindkey_zsh_vim "\em" tldr-command-line # tldr: alt-m
########################## 🔼 BIND KEY 🔼 ######################

########################## 🔽 NET 🔽 ###########################
# Clash TUN handles traffic by default. Run `proxy enable` only as a manual fallback.
HOST_IP="http://127.0.0.1"
SHELLPROXY_URL="$HOST_IP:7890"
SHELLPROXY_NO_PROXY="localhost,127.0.0.1"
########################## 🔼 NET 🔼 ###########################

########################## 🔽 LOAD OTHER CONFIGS 🔽 ############
setopt HIST_IGNORE_ALL_DUPS # Remove duplicate older commands
setopt HIST_IGNORE_SPACE    # Remove commands with leading space
setopt EXTENDED_HISTORY     # Record timestamps in .zsh_history
function _ignore_unknown_command_history() {
  emulate -L zsh
  setopt extended_glob

  local -a words
  # Split the raw history line the same way zsh parses command words.
  words=(${(z)${1%%$'\n'}}) || return 0

  local cmd
  for cmd in "${words[@]}"; do
    [[ "$cmd" == [[:alpha:]_][[:alnum:]_]#=* ]] && continue
    [[ "$cmd" == (builtin|command|exec|noglob|time|sudo|env) ]] && return 0
    # Reject command-not-found typos before they pollute autosuggestions.
    whence -w -- "$cmd" >/dev/null 2>&1
    return $?
  done

  return 0
}
autoload -Uz add-zsh-hook # Load zsh hook registration helper.
add-zsh-hook zshaddhistory _ignore_unknown_command_history # Filter history before saving.
(( $+commands[starship] )) && eval "$(starship init zsh)" # Customizable prompt for any shell
function _init_jenv() {
  eval "$(command jenv init -)"
  functions[_jenv_original]=$functions[jenv]
  function jenv() {
    _jenv_original "$@"
    local exit_code=$?
    [[ "$1" == shell && $exit_code -eq 0 ]] && _jenv_export_hook
    return $exit_code
  }
}
# Direct non-login shells do not read .zprofile, so restore the uv default Python path.
export UV_PYTHON_BIN_DIR="${UV_PYTHON_BIN_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/uv/bin}"
[[ -d "$UV_PYTHON_BIN_DIR" ]] && path=("$UV_PYTHON_BIN_DIR" $path)
typeset -U path
# .zprofile initializes fnm for login shells; nested interactive shells need their own chpwd hook.
if (( $+commands[fnm] && ! $+functions[_fnm_autoload_hook] )); then
  eval "$(fnm env --use-on-cd --shell zsh)"
fi
lazyload jenv java javac jar javadoc jshell gradle mvn ant -- '_init_jenv' # jenv: Manage the Java toolchain on demand.
lazyload conda -- 'eval "$("$HOME/miniconda3/bin/conda" 'shell.zsh' 'hook' 2> /dev/null)"'
########################## 🔼 LOAD OTHER CONFIGS 🔼 #############

########################## 🔽 ABBREVIATION 🔽 ###################
# Dotfile-owned abbreviations are session-only and silent at startup.
abbr -S -f --quieter cat='bat' # Syntax highlighting and Git integration.
abbr -S -f --quieter df='duf'
abbr -S -f --quieter du='dust'
abbr -S -f --quieter find='fd .' # Search recursively; fd still honors ignore rules.
unalias l la ll ls lsa 2>/dev/null # Remove Oh My Zsh list aliases.
abbr -S -f --quieter ls='eza --git --group-directories-first --icons=auto'
abbr -S --quieter ll='eza --long --git --group-directories-first --icons=auto'
abbr -S --quieter la='eza --long --all --git --group-directories-first --icons=auto'
abbr -S --quieter lg='lazygit'
abbr -S --quieter lzd='lazydocker'
abbr -S -f --quieter make='make -j10' # Run up to 10 jobs in parallel.
unalias md 2>/dev/null # Remove Oh My Zsh's mkdir shortcut.
abbr -S --quieter md='mkdir -pv'
abbr -S -f --quieter mkdir='mkdir -pv'
abbr -S --quieter nn='nvim'
abbr -S -f --quieter ping='ping -c 5' # Stop after five replies.
if [[ "$ZSH_OS" == "Linux" ]]; then # Ubuntu/Linux settings
  abbr -S --quieter update='sudo apt update && sudo apt upgrade -y'
elif [[ "$ZSH_OS" == "Darwin" ]]; then # macOS settings
  abbr -S --quieter update='brew update && brew upgrade && brew cleanup'
fi
########################## 🔼 ABBREVIATION 🔼 ###################

########################## 🔽 ALIAS 🔽 ##########################
alias c='printf "\e[H\e[2J"' # Sends control characters Esc-C to the console which resets the terminal
if [[ "$ZSH_OS" == "Linux" ]]; then # Ubuntu/Linux settings
  alias rm='trash-put' # Don't ask. Asking is a lesson learned in blood and tears.
elif [[ "$ZSH_OS" == "Darwin" ]]; then # macOS settings
  alias rm="$HOMEBREW_PREFIX/opt/macos-trash/bin/trash" # Don't ask. Asking is a lesson learned in blood and tears.
fi
########################## 🔼 ALIAS 🔼 ##########################

########################## 🔽 FUNCTION 🔽 #######################
function y() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
  yazi "$@" --cwd-file="$tmp"
  if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
    builtin cd -- "$cwd"
  fi
  /bin/rm -f -- "$tmp"
}

########################## 🔼 FUNCTION 🔼 #######################
