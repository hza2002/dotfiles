########################## 🔽 ENV 🔽 ###########################
export EDITOR='lvim'
if [[ -f /proc/version && $(grep -i Microsoft /proc/version) ]]; then # Ubuntu/WSL settings
  export NPC_HOME="$HOME/repo/ysyx-workbench/npc"
  export NVBOARD_HOME="$HOME/repo/ysyx-workbench/nvboard"
elif [[ "$(uname)" == "Linux" ]]; then # Ubuntu/Linux settings
  # ysyx
  export AM_HOME="$HOME/repo/ysyx-workbench/abstract-machine"
  export NEMU_HOME="$HOME/repo/ysyx-workbench/nemu"
  export NPC_HOME="$HOME/repo/ysyx-workbench/npc"
  export NVBOARD_HOME="$HOME/repo/ysyx-workbench/nvboard"
  source $HOME/zephyr-sdk-0.15.0/environment-setup-x86_64-pokysdk-linux #  Zephyr SDK, installed for zmk
elif [[ "$(uname)" == "Darwin" ]]; then # macOS settings
  export GPG_TTY=$(tty)
fi
########################## 🔼 ENV 🔼 ###########################

########################## 🔽 BREW 🔽 ##########################
if [[ "$(uname)" == "Darwin" ]]; then # macOS settings
  # 换清华源
  # export HOMEBREW_API_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api"
  # export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"
  # export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
  # export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git"
  # export HOMEBREW_PIP_INDEX_URL="https://pypi.tuna.tsinghua.edu.cn/simple"
  # 配置 Homebrew 环境变量
  eval $(/opt/homebrew/bin/brew shellenv) 
  # Shell Completion (https://docs.brew.sh/Shell-Completion#configuring-completions-in-zsh)
  FPATH="$/opt/homebrew/share/zsh/site-functions:${FPATH}"
fi
########################## 🔼 BREW 🔼 ##########################

########################## 🔽 PATH 🔽 ##########################
. "$HOME/.cargo/env" # Rust
if [[ "$(uname)" == "Linux" ]]; then # Ubuntu/Linux settings
  export PATH="$PATH:$HOME/bin:/usr/local/bin"
  export PATH="$PATH:$HOME/.local/bin"
  export PATH="$PATH:/usr/local/go/bin"
  export PATH="$PATH:$HOME/julia-1.9.2/bin"
  export PATH="$PATH:$HOME/.fnm"
  export PATH="$PATH:$HOME/.jenv/bin"
  export PATH=/usr/local/cuda-11.8/bin${PATH:+:${PATH}}
elif [[ "$(uname)" == "Darwin" ]]; then # macOS settings
  export PATH="$PATH:$HOME/.local/bin"
  export PATH="$PATH:$HOME/Library/Application Support/JetBrains/Toolbox/scripts" # JetBrains Toolbox
  export PATH="$PATH:$HOME/repo/scripts" # my custom scripts
fi
########################## 🔼 PATH 🔼 ##########################

########################## 🔽 OH MY ZSH 🔽 #####################
export ZSH="$HOME/.oh-my-zsh" # Path to oh-my-zsh installation.
export ZSH_COMPDUMP="$ZSH_CACHE_DIR/.zcompdump-$HOST"
plugins=( # https://github.com/ohmyzsh/ohmyzsh/wiki/Plugins
  # Silent
  colored-man-pages command-not-found shell-proxy
  # Commands
  copypath extract perms qrcode
  # Shortcut
  fancy-ctrl-z sudo thefuck tldr
  # Aliases
  aliases common-aliases 
  brew docker-compose git golang rust ssh zoxide 
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
proxy enable
########################## 🔼 NET 🔼 ###########################

########################## 🔽 LOAD OTHER CONFIGS 🔽 ############
setopt HIST_IGNORE_ALL_DUPS # Remove duplicate older commands
setopt HIST_IGNORE_SPACE    # Remove commands with leading space
setopt EXTENDED_HISTORY      # Record timestamps in .zsh_history
setopt INC_APPEND_HISTORY_TIME  # Record command execution duration
if output="$(mole completion zsh 2>/dev/null)"; then eval "$output"; fi # Mole shell completion
source <(COMPLETE=zsh jj) # Jujutsu
eval "$(starship init zsh)" # Customizable prompt for any shell
eval "$(codex completion zsh)" # OpenAI Codex Completion
source "$HOME/.openclaw/completions/openclaw.zsh" # OpenClaw Completion
# eval "$(fnm env --use-on-cd --shell zsh)"
lazyload fnm node npm npx pnpm -- 'eval "$(fnm env --use-on-cd --shell zsh)"' # fnm: Fast and simple Node.js version manager
lazyload jenv java javac javadoc -- 'eval "$(jenv init -)"' # jenv: Manage your Java environment
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
alias make='make -j32' # 并行make
alias mkdir='mkdir -pv'
alias nn='lvim' # LunarVim
alias ping='ping -c 5' # Stop after sending count ECHO_REQUEST packets #
alias pip='pip3'
alias ps='procs' # A modern replacement for ps written in Rust.
alias python='python3'
alias mysudo='sudo -E env "PATH=$PATH"'
if [[ "$(uname)" == "Linux" ]]; then # Ubuntu/Linux settings
  alias update='sudo apt update && sudo apt upgrade -y'
  alias rm='trash-put' # Don't ask. Asking is a lesson learned in blood and tears.
elif [[ "$(uname)" == "Darwin" ]]; then # macOS settings
  alias update='brew update && brew upgrade && brew cu -a -y && brew cleanup'
  alias rm='trash' # Don't ask. Asking is a lesson learned in blood and tears.
fi
########################## 🔼 ALIAS 🔼 ##########################

########################## 🔽 SAFEHOUSE 🔽 ######################
# Sandbox local AI - github.com/eugene1g/agent-safehouse
function safe() { safehouse "$@" }
# Sandboxed — the default. Just type the command name.
function claude() { safe claude --dangerously-skip-permissions "$@" }
function codex() { safe codex --dangerously-bypass-approvals-and-sandbox "$@" }
########################## 🔼 SAFEHOUSE 🔼 ######################

########################## 🔽 FUNCTION 🔽 #######################
function y() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
  yazi "$@" --cwd-file="$tmp"
  if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
    builtin cd -- "$cwd"
  fi
  rm -f -- "$tmp"
}

if [[ "$(uname)" == "Linux" ]]; then # Ubuntu/Linux settings
elif [[ "$(uname)" == "Darwin" ]]; then # macOS settings
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
    current_network_name=$(networksetup -getairportnetwork en0 | awk -F' ' '{print $4}' | tr -d '\n')
    local_network_name="RhodesIsland" # 局域网网络名称

    local_command="ssh l${target}" # 本地目标
    remote_command="ssh r${target}" # 远程目标

    # 判断当前网络，并执行相应的命令
    if [ "$current_network_name" = "$local_network_name" ]; then
      eval "$local_command"
    else
      eval "$remote_command"
    fi
  }

  # 具体的快捷方式
  function ubt() { ssh_connect "ubt"; }
  function wsl() { ssh_connect "wsl"; }
fi
########################## 🔼 FUNCTION 🔼 #######################
