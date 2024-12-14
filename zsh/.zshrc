########################## 🔽 ENV 🔽 ###########################
export EDITOR='lvim'
if [[ -f /proc/version && $(grep -i Microsoft /proc/version) ]]; then
  export NPC_HOME="$HOME/repo/ysyx-workbench/npc"
  export NVBOARD_HOME="$HOME/repo/ysyx-workbench/nvboard"
elif [[ "$(uname)" == "Linux" ]]; then # Ubuntu/Linux-specific environment variable settings
  # ysyx
  export AM_HOME="$HOME/repo/ysyx-workbench/abstract-machine"
  export NEMU_HOME="$HOME/repo/ysyx-workbench/nemu"
  export NPC_HOME="$HOME/repo/ysyx-workbench/npc"
  export NVBOARD_HOME="$HOME/repo/ysyx-workbench/nvboard"
  source $HOME/zephyr-sdk-0.15.0/environment-setup-x86_64-pokysdk-linux #  Zephyr SDK, installed for zmk
elif [[ "$(uname)" == "Darwin" ]]; then # macOS-specific environment variable settings
fi
########################## 🔼 ENV 🔼 ###########################

########################## 🔽 BREW 🔽 ##########################
if [[ "$(uname)" == "Darwin" ]]; then # macOS-specific environment variable settings
  # 换清华源
  export HOMEBREW_API_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api"
  export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"
  export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
  export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git"
  export HOMEBREW_PIP_INDEX_URL="https://pypi.tuna.tsinghua.edu.cn/simple"
  # 配置 Homebrew 环境变量
  eval $(/opt/homebrew/bin/brew shellenv) 
  # Shell Completion (https://docs.brew.sh/Shell-Completion#configuring-completions-in-zsh)
  FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
fi
########################## 🔼 BREW 🔼 ##########################

########################## 🔽 PATH 🔽 ##########################
. "$HOME/.cargo/env" # Rust
if [[ "$(uname)" == "Linux" ]]; then # Ubuntu/Linux-specific environment variable settings
  export PATH="$PATH:$HOME/bin:/usr/local/bin"
  export PATH="$PATH:$HOME/.local/bin"
  export PATH="$PATH:/usr/local/go/bin"
  export PATH="$PATH:$HOME/julia-1.9.2/bin"
  export PATH="$PATH:$HOME/.fnm"
  export PATH=/usr/local/cuda-11.8/bin${PATH:+:${PATH}}
elif [[ "$(uname)" == "Darwin" ]]; then # macOS-specific environment variable settings
  export PATH="$PATH:$HOME/.local/bin"
  export PATH="$PATH:$HOME/Library/Application Support/JetBrains/Toolbox/scripts" # JetBrains Toolbox
fi
########################## 🔼 PATH 🔼 ##########################

########################## 🔽 OH MY ZSH 🔽 #####################
export ZSH="$HOME/.oh-my-zsh" # Path to your oh-my-zsh installation.
export ZSH_COMPDUMP="ZSH_CACHE_DIR/.zcompdump-$HOST"
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
eval "$(starship init zsh)" # Customizable prompt for any shell
lazyload fnm node npm npx pnpm -- 'eval "$(fnm env --use-on-cd --shell zsh)"' # fnm: Fast and simple Node.js version manager
lazyload jenv java javac javadoc -- 'eval "$(jenv init -)"' # jenv: Manage your Java environment
lazyload conda python3 pip3 python pip -- 'eval "$("$HOME/miniconda3/bin/conda" 'shell.zsh' 'hook' 2> /dev/null)"'
########################## 🔼 LOAD OTHER CONFIGS 🔼 #############

########################## 🔽 ALIAS 🔽 ##########################
## a quick way to get out of current directory ##
alias c='clear -x' # Clear the screen but keep the terminal's scrollback buffer.
alias cat='bat' # A cat(1) clone with syntax highlighting and Git integration.
alias df='duf'
alias du='dust'
alias find='fd' # A simple, fast and user-friendly alternative to find.
alias ls='lsd' # The next gen file listing command. Backwards compatible with ls.
alias lg='lazygit'
alias ld='lazydocker'
alias make='make -j' # 并行make
alias mkdir='mkdir -pv'
alias nn='lvim' # LunarVim
alias ping='ping -c 5' # Stop after sending count ECHO_REQUEST packets #
alias pip='pip3'
alias ps='procs' # A modern replacement for ps written in Rust.
alias python='python3'
alias mysudo='sudo -E env "PATH=$PATH"'
if [[ "$(uname)" == "Linux" ]]; then # Ubuntu/Linux-specific environment variable settings
  alias ra='ranger'
  alias update='sudo apt update && sudo apt upgrade -y'
  alias rm='trash-put' # Don't ask. Asking is a lesson learned in blood and tears.
elif [[ "$(uname)" == "Darwin" ]]; then # macOS-specific environment variable settings
  alias ra="$HOME/miniconda3/bin/ranger"
  alias update='brew update && brew upgrade'
  alias rm='trash' # Don't ask. Asking is a lesson learned in blood and tears.
fi
########################## 🔼 ALIAS 🔼 ##########################

########################## 🔽 FUNCTION 🔽 #######################
if [[ "$(uname)" == "Linux" ]]; then # Ubuntu/Linux-specific environment variable settings
elif [[ "$(uname)" == "Darwin" ]]; then # macOS-specific environment variable settings
  # add yabai to 
  function suyabai () {
    SHA256=$(shasum -a 256 $(brew --prefix)/bin/yabai | awk "{print \$1;}")
    if [ -f "/private/etc/sudoers.d/yabai" ]; then
      sudo sed -i '' -e 's/sha256:[[:alnum:]]*/sha256:'${SHA256}'/' /private/etc/sudoers.d/yabai
    else
      echo "sudoers file does not exist yet"
    fi
  }

  # update sketchybar after brew commands
  function brew() {
    command brew "$@" 
    if [[ $* =~ "upgrade" ]] || [[ $* =~ "update" ]] || [[ $* =~ "outdated" ]]; then
      sketchybar --trigger brew_update
    fi
  }

  # ssh choose local or remote ubuntu
  function ubuntu() {
    current_network_name=$(networksetup -getairportnetwork en0 | awk -F' ' '{print $4}' | tr -d '\n') # 当前所在网络名称
    local_network_name="按点上网" # 局域网网络名称
    success_command="ssh localubuntu" # 要执行的命令，如果同个局域网内
    failure_command="ssh remoteubuntu" # 要执行的命令，如果不在同个局域网内
    if [ "$current_network_name" = "$local_network_name" ]; then
      eval "$success_command"
    else
      eval "$failure_command"
    fi
  }
  function lwin() { eval "ssh lwin" }
  function rwin() { eval "ssh rwin" }
  function lubt() { eval "ssh lubt" }
  function rubt() { eval "ssh rubt" }
fi
########################## 🔼 FUNCTION 🔼 #######################
