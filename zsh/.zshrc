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
export ZSH_COMPDUMP="$ZSH_CACHE_DIR/.zcompdump-$HOST"
plugins=( # https://github.com/ohmyzsh/ohmyzsh/wiki/Plugins
  # Silent
  colored-man-pages command-not-found shell-proxy
  # Commands
  extract
  # Disabled commands: copypath perms qrcode
  # Shortcut
  fancy-ctrl-z sudo thefuck tldr
  # Aliases
  common-aliases
  # Disabled aliases: aliases
  git rust zoxide
  # Custom
  autoupdate fzf-tab you-should-use iterm2-shell-integration
  zsh-lazyload zsh-vi-mode zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search
)
fpath+="${ZSH_CUSTOM:-"$ZSH/custom"}/plugins/zsh-completions/src" # https://github.com/zsh-users/zsh-completions/issues/603
zvm_after_init_commands+=("source $HOME/.config/fzf/fzfrc.sh") # zvm and fzf conflict
source $ZSH/oh-my-zsh.sh
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
# export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
#if [[ $(grep -i Microsoft /proc/version) ]]; then
#  HOST_IP=$(cat /etc/resolv.conf | grep "nameserver" | cut -f 2 -d " ")
#fi
HOST_IP="http://127.0.0.1"
SHELLPROXY_URL="$HOST_IP:7890"
SHELLPROXY_NO_PROXY="localhost,127.0.0.1"
if [[ "$ZSH_OS" == "Darwin" ]]; then
  proxy enable
fi
########################## 🔼 NET 🔼 ###########################

########################## 🔽 LOAD OTHER CONFIGS 🔽 ############
setopt HIST_IGNORE_ALL_DUPS # Remove duplicate older commands
setopt HIST_IGNORE_SPACE    # Remove commands with leading space
setopt EXTENDED_HISTORY     # Record timestamps in .zsh_history
setopt INC_APPEND_HISTORY_TIME  # Record command execution duration
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
if (( $+commands[mole] )) && output="$(mole completion zsh 2>/dev/null)"; then eval "$output"; fi # Mole shell completion
(( $+commands[jj] )) && source <(COMPLETE=zsh jj) # Jujutsu
(( $+commands[starship] )) && eval "$(starship init zsh)" # Customizable prompt for any shell
(( $+commands[codex] )) && eval "$(codex completion zsh)" # OpenAI Codex Completion
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
# eval "$(fnm env --use-on-cd --shell zsh)"
lazyload fnm node npm npx pnpm corepack nvim -- 'eval "$(fnm env --use-on-cd --shell zsh)"' # fnm: Fast and simple Node.js version manager
lazyload jenv java javac jar javadoc jshell gradle mvn ant -- '_init_jenv' # jenv: Manage the Java toolchain on demand.
lazyload conda python3 pip3 python pip -- 'eval "$("$HOME/miniconda3/bin/conda" 'shell.zsh' 'hook' 2> /dev/null)"'
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
alias pip='pip3'
alias ps='procs' # A modern replacement for ps written in Rust.
alias python='python3'
alias mysudo='sudo -E env "PATH=$PATH"'
if [[ "$ZSH_OS" == "Linux" ]]; then # Ubuntu/Linux settings
  alias update='sudo apt update && sudo apt upgrade -y'
  alias rm='trash-put' # Don't ask. Asking is a lesson learned in blood and tears.
elif [[ "$ZSH_OS" == "Darwin" ]]; then # macOS settings
  alias update='brew update && brew upgrade && brew cleanup'
  alias rm='trash' # Don't ask. Asking is a lesson learned in blood and tears.
  alias cdx='open "codex://new?path=$(pwd)"' # open codex app
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
  rm -f -- "$tmp"
}

if [[ "$ZSH_OS" == "Linux" ]]; then # Ubuntu/Linux settings
elif [[ "$ZSH_OS" == "Darwin" ]]; then # macOS settings
  # Add yabai to sudoers
  function suyabai () {
    SHA256=$(shasum -a 256 $(brew --prefix)/bin/yabai | awk "{print \$1;}")
    if [ -f "/private/etc/sudoers.d/yabai" ]; then
      sudo sed -i '' -e 's/sha256:[[:alnum:]]*/sha256:'${SHA256}'/' /private/etc/sudoers.d/yabai
    else
      echo "sudoers file does not exist yet"
    fi
  }

  # 通用的 ssh 命令选择函数
  function ssh_connect() {
    local target=$1
    local current_network_name=$(networksetup -getairportnetwork en0 | awk -F' ' '{print $4}' | tr -d '\n')
    local local_network_name="CU_2613-5G" # 局域网网络名称

    local local_host="l${target}" # 本地目标
    local remote_host="r${target}" # 远程目标

    # 判断当前网络，并执行相应的命令
    if [ "$current_network_name" = "$local_network_name" ]; then
      ssh "$local_host"
    else
      ssh "$remote_host"
    fi
  }

  # 具体的快捷方式
  function ubt() { ssh_connect "ubt"; }
  function wsl() { ssh_connect "wsl"; }
fi
########################## 🔼 FUNCTION 🔼 #######################
