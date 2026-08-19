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
  zsh-lazyload zsh-vi-mode zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search
)
fpath+="${ZSH_CUSTOM:-"$ZSH/custom"}/plugins/zsh-completions/src" # https://github.com/zsh-users/zsh-completions/issues/603
zvm_after_init_commands+=("source $HOME/.config/fzf/fzfrc.sh") # zvm and fzf conflict
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

########################## 🔽 ALIAS 🔽 ##########################
alias c='printf "\e[H\e[2J"' # Sends control characters Esc-C to the console which resets the terminal
alias cat='bat' # A cat(1) clone with syntax highlighting and Git integration.
alias df='duf'
alias du='dust'
alias find='fd' # A simple, fast and user-friendly alternative to find.
alias ls='lsd' # The next gen file listing command. Backwards compatible with ls.
alias lg='lazygit'
alias ld='lazydocker'
alias make='make -j10' # 并行make
alias mkdir='mkdir -pv'
alias nn='nvim'
alias ping='ping -c 5' # Stop after sending count ECHO_REQUEST packets #
alias ps='procs' # A modern replacement for ps written in Rust.
if [[ "$ZSH_OS" == "Linux" ]]; then # Ubuntu/Linux settings
  alias update='sudo apt update && sudo apt upgrade -y'
  alias rm='trash-put' # Don't ask. Asking is a lesson learned in blood and tears.
elif [[ "$ZSH_OS" == "Darwin" ]]; then # macOS settings
  alias update='brew update && brew upgrade && brew cleanup'
  alias rm="$HOMEBREW_PREFIX/opt/macos-trash/bin/trash" # Don't ask. Asking is a lesson learned in blood and tears.
fi
########################## 🔼 ALIAS 🔼 ##########################

########################## 🔽 AGENT SANDBOX 🔽 ##################
if [[ "$ZSH_OS" == "Darwin" ]]; then # macOS settings
  export SANDBOX_AGENT_PROFILE="$HOME/.config/sandbox-exec/agent.sb"

  function safe() {
    "$HOME/.config/sandbox-exec/run-sandboxed.sh" "$@"
  }

  function claude() {
    local workdir_arg=()
    if [[ "${1:-}" == --workdir=* ]]; then
      workdir_arg=("$1")
      shift
    elif [[ "${1:-}" == --workdir && -n "${2:-}" ]]; then
      workdir_arg=("$1" "$2")
      shift 2
    fi
    safe "${workdir_arg[@]}" claude --dangerously-skip-permissions "$@"
  }

  function codex() {
    local workdir_arg=()
    if [[ "${1:-}" == --workdir=* ]]; then
      workdir_arg=("$1")
      shift
    elif [[ "${1:-}" == --workdir && -n "${2:-}" ]]; then
      workdir_arg=("$1" "$2")
      shift 2
    fi
    safe "${workdir_arg[@]}" codex --dangerously-bypass-approvals-and-sandbox "$@"
  }
fi
########################## 🔼 AGENT SANDBOX 🔼 ##################

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
