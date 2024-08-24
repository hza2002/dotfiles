########################## 🔽 ENV 🔽 ###########################
export EDITOR='lvim'
export LANG=en_US.UTF-8 
if [[ "$(uname)" == "Linux" ]]; then # Ubuntu/Linux-specific environment variable settings
  # ysyx
  export AM_HOME="$HOME/repo/ysyx-workbench/abstract-machine"
  export NEMU_HOME="$HOME/repo/ysyx-workbench/nemu"
  export NPC_HOME="$HOME/repo/ysyx-workbench/npc"
  export NVBOARD_HOME="$HOME/repo/ysyx-workbench/nvboard"
  source $HOME/zephyr-sdk-0.15.0/environment-setup-x86_64-pokysdk-linux #  Zephyr SDK, installed for zmk
elif [[ "$(uname)" == "Darwin" ]]; then # macOS-specific environment variable settings
  export HISTCONTROL='ignoreboth:erasedups' # https://serverfault.com/questions/48769/avoid-to-keep-command-in-history
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
if [[ "$(uname)" == "Linux" ]]; then # Ubuntu/Linux-specific environment variable settings
  export PATH="$HOME/bin:/usr/local/bin:$PATH"
  export PATH="$HOME/.local/bin:$PATH"
  export PATH="$PATH:/usr/local/go/bin"
  export PATH="$PATH:$HOME/go/bin"
  export PATH="$PATH:$HOME/.local/share/coursier/bin" # coursier install directory
  export PATH="$PATH:$HOME/julia-1.9.2/bin"
  # export PATH=/usr/local/cuda-12.2/bin${PATH:+:${PATH}}
  export PATH=/usr/local/cuda-11.8/bin${PATH:+:${PATH}}
elif [[ "$(uname)" == "Darwin" ]]; then # macOS-specific environment variable settings
  export PATH="$HOME/.local/bin:$PATH"
  export PATH="$PATH:$HOME/Library/Application Support/JetBrains/Toolbox/scripts" # JetBrains Toolbox
  . "$HOME/.cargo/env" # Rust
fi
########################## 🔼 PATH 🔼 ##########################

########################## 🔽 OH MY ZSH 🔽 #####################
export ZSH="$HOME/.oh-my-zsh" # Path to your oh-my-zsh installation.
export ZSH_COMPDUMP="ZSH_CACHE_DIR/.zcompdump-$HOST"
plugins=( # https://github.com/ohmyzsh/ohmyzsh/wiki/Plugins
  # Silent
  command-not-found shell-proxy
  # Commands
  copypath extract perms qrcode
  # Shortcut
  fancy-ctrl-z sudo thefuck tldr
  # Aliases
  aliases common-aliases 
  brew docker-compose git golang rust ssh zoxide 
  # Custom
  autoupdate fzf-tab you-should-use
  zsh-autosuggestions zsh-syntax-highlighting zsh-vi-mode zsh-history-substring-search
)
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
SHELLPROXY_URL="http://127.0.0.1:7890"
SHELLPROXY_NO_PROXY="localhost,127.0.0.1"
proxy enable
########################## 🔼 NET 🔼 ###########################

########################## 🔽 LOAD OTHER CONFIGS 🔽 ############
eval "$(starship init zsh)" # Customizable prompt for any shell
source <(fzf --zsh) # Set up fzf key bindings and fuzzy completion
eval "$(fnm env --use-on-cd --shell zsh)" # fnm: Fast and simple Node.js version manager
eval "$(jenv init -)" # jenv: Manage your Java environment
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
alias ra='ranger'
alias mysudo='sudo -E env "PATH=$PATH"'
if [[ "$(uname)" == "Linux" ]]; then # Ubuntu/Linux-specific environment variable settings
  alias update='sudo apt update && sudo apt upgrade -y'
  alias rm='trash-put' # Don't ask. Asking is a lesson learned in blood and tears.
elif [[ "$(uname)" == "Darwin" ]]; then # macOS-specific environment variable settings
  alias update='brew update && brew upgrade'
  alias rm='trash' # Don't ask. Asking is a lesson learned in blood and tears.
fi
########################## 🔼 ALIAS 🔼 ##########################

########################## 🔽 FUNCTION 🔽 #######################
if [[ "$(uname)" == "Linux" ]]; then # Ubuntu/Linux-specific environment variable settings
elif [[ "$(uname)" == "Darwin" ]]; then # macOS-specific environment variable settings
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
    local_network_name="swu" # 局域网网络名称
    success_command="ssh localubuntu" # 要执行的命令，如果同个局域网内
    failure_command="ssh remoteubuntu" # 要执行的命令，如果不在同个局域网内
    if [ "$current_network_name" = "$local_network_name" ]; then
      eval "$success_command"
    else
      eval "$failure_command"
    fi
  }
fi
########################## 🔼 FUNCTION 🔼 #######################

########################## 🔽 CONDA 🔽 ########################
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$("$HOME/miniconda3/bin/conda" 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
  eval "$__conda_setup"
else
  if [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
    . "$HOME/miniconda3/etc/profile.d/conda.sh"
  else
    export PATH="$HOME/miniconda3/bin:$PATH"
  fi
fi
unset __conda_setup
########################## 🔼 CONDA 🔼 #########################
