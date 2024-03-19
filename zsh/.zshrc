# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

########################## 🔽 NET 🔽 ###########################
function proxy_clash() {
  export https_proxy=http://127.0.0.1:7890 
  export http_proxy=http://127.0.0.1:7890 
  export all_proxy=socks5://127.0.0.1:7890
  git config --global http.proxy "127.0.0.1:7890" # git 代理
  git config --global https.proxy "127.0.0.1:7890" # git 代理
}

function proxy_v2ray() {
  export http_proxy=http://127.0.0.1:1087
  export https_proxy=http://127.0.0.1:1087
  export ALL_PROXY=socks5://127.0.0.1:1080
  git config --global http.proxy "127.0.0.1:1087" # git 代理
  git config --global https.proxy "127.0.0.1:1087" # git 代理
}

proxy_clash
########################## 🔼 NET 🔼 ###########################

########################## 🔽 ENV 🔽 ###########################
if [[ $TMUX != "" ]] then
    export TERM="tmux-256color"
else
    export TERM="xterm-256color"
fi
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
    export HOMEBREW_BOTTLE_DOMAIN=https://mirrors.ustc.edu.cn/homebrew-bottles
    export JAVA_HOME=$(/usr/libexec/java_home) # Path to Java
    export MATLAB_ROOT=/Applications/MATLAB_R2022b_Beta.app
    export SDKMAN_DIR="$HOME/.sdkman"
    [[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
fi
########################## 🔼 ENV 🔼 ###########################

########################## 🔽 PATH 🔽 ##########################
if [[ "$(uname)" == "Linux" ]]; then # Ubuntu/Linux-specific environment variable settings
    export PATH="$HOME/bin:/usr/local/bin:$PATH"
    export PATH="$HOME/.local/bin:$PATH"
    export PATH="$PATH:/usr/local/go/bin"
    export PATH="$PATH:$HOME/go/bin"
    export PATH="$HOME/.emacs.d/bin:$PATH"
    export PATH="$PATH:$HOME/.local/share/coursier/bin" # coursier install directory
    export PATH="$PATH:$HOME/julia-1.9.2/bin"
    # export PATH=/usr/local/cuda-12.2/bin${PATH:+:${PATH}}
    export PATH=/usr/local/cuda-11.8/bin${PATH:+:${PATH}}
elif [[ "$(uname)" == "Darwin" ]]; then # macOS-specific environment variable settings
    export PATH="$HOME/.local/bin:$PATH"
    export PATH="$HOME/Qt/5.15.2/clang_64/bin:$PATH"
    export PATH="/opt/homebrew/opt/tcl-tk/bin:$PATH"
    export PATH="/opt/homebrew/opt/bison/bin:$PATH"
    export PATH="/opt/homebrew/opt/curl/bin:$PATH"
    export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
    export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"
    export PATH="/opt/homebrew/opt/llvm/bin:$PATH"
    export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
    export PATH="/opt/homebrew/opt/openssl@3/bin:$PATH"
    export PATH="$HOME/.emacs.d/bin:$PATH"
    export PATH="$MATLAB_ROOT/bin:$PATH"
    export PATH="$PATH:$HOME/.rvm/bin"
    export PATH="/Applications/gtkwave.app/Contents/Resources/bin/:$PATH"
    export PATH=$PATH:/usr/local/mysql/bin
    export PATH=$PATH:$HOME/.spicetify
fi
########################## 🔼 PATH 🔼 ##########################

########################## 🔽 PERL 🔽 ##########################
if [[ "$(uname)" == "Linux" ]]; then # Ubuntu/Linux-specific environment variable settings
    PATH="$HOME/perl5/bin${PATH:+:${PATH}}"; export PATH;
    PERL5LIB="$HOME/perl5/lib/perl5${PERL5LIB:+:${PERL5LIB}}"; export PERL5LIB;
    PERL_LOCAL_LIB_ROOT="$HOME/perl5${PERL_LOCAL_LIB_ROOT:+:${PERL_LOCAL_LIB_ROOT}}"; export PERL_LOCAL_LIB_ROOT;
    PERL_MB_OPT="--install_base \"$HOME/perl5\""; export PERL_MB_OPT;
    PERL_MM_OPT="INSTALL_BASE=$HOME/perl5"; export PERL_MM_OPT;
fi
########################## 🔼 PERL 🔼 ##########################

########################## 🔽 NVM 🔽 ###########################
export NVM_DIR="$HOME/.nvm"
if [[ "$(uname)" == "Linux" ]]; then # Ubuntu/Linux-specific environment variable settings
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
elif [[ "$(uname)" == "Darwin" ]]; then # macOS-specific environment variable settings
    [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm
    [ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion
fi
########################## 🔼 NVM 🔼 ##########################

########################## 🔽 OH MY ZSH 🔽 #####################
export ZSH=$HOME/.oh-my-zsh # Path to your oh-my-zsh installation.
POWERLEVEL9K_MODE="nerdfont-complete"
ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(
  1password
  adb aliases aws
  colored-man-pages command-not-found
  docker docker-compose dotnet
  extract
  fasd fzf-tab fd
  gcloud gem gh git gitignore golang gradle
  httpie
  mvn
  node npm nvm
  perl pip python
  ripgrep rust rvm
  safe-paste 
  themes
  zsh-vi-mode z zsh-autosuggestions zsh-syntax-highlighting
)
fpath+=${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions/src
source $ZSH/oh-my-zsh.sh
source ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
########################## 🔼 OH MY ZSH 🔼 #####################

########################## 🔽 LOAD OTHER CONFIGS 🔽 ############
eval $(thefuck --alias) # thefuck
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh # To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"
[[ $TERM == "dumb" ]] && unsetopt zle && PS1='$ ' && return # 解决emacs zsh颜色问题
source "$HOME/.config/op/plugins.sh" # Enable 1Password ability
[ -f ~/.inshellisense/key-bindings.zsh ] && source ~/.inshellisense/key-bindings.zsh
# To start the agent daemon automatically
if [ "$SSH_AUTH_SOCK" = "" -a -x /usr/bin/ssh-agent ]; then
  eval `/usr/bin/ssh-agent` > /dev/null
fi
# Ensure ssh key is added
ssh-add ~/.ssh/id_rsa 2> /dev/null
ssh-add ~/.ssh/id_ed25519 2> /dev/null 
########################## 🔼 LOAD OTHER CONFIGS 🔼 #############

########################## 🔽 ALIAS 🔽 ##########################
## a quick way to get out of current directory ##
alias .....='cd ../../../..'
alias ....='cd ../../..'
alias ...='cd ../..'
alias ..='cd ..'
alias .4='cd ../../../..'
alias .5='cd ../../../../..'
alias cd..='cd ..' 
alias c='clear'
alias cat='bat' # A cat(1) clone with syntax highlighting and Git integration.
alias df='duf'
alias du='dust'
alias ec='env TERM="xterm-direct" emacsclient -t -a ""' # 其中-a表示alternative-editor，用于指定无法连接emacs server时使用的编辑器。空字符串有特殊意义，表示先启动emacs server，再重新连接。
alias sec='sudo env TERM="xterm-direct" emacsclient -t -a ""' # 若只有第一行，执行sudo ec file会找不到命令，因为root用户并没有定义ec别名。因此定义sec，作为ec的sudo版本。
alias find='fd' # A simple, fast and user-friendly alternative to find.
alias ls='lsd' # The next gen file listing command. Backwards compatible with ls.
alias m='tldr' # man
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
    alias r='radian' # let r open radian
    alias rm='trash' # Don't ask. Asking is a lesson learned in blood and tears.
    alias emacs="open -a /Applications/Emacs.app/ $1"
fi
########################## 🔼 ALIAS 🔼 ##########################

########################## 🔽 FUNCTION 🔽 #######################
# Timing With Curl (https://susam.net/blog/timing-with-curl.html)
function reqtime(){
  command curl -s -o /dev/null -L -w "time_namelookup: %{time_namelookup}\ntime_connect: %{time_connect}\ntime_appconnect: %{time_appconnect}\ntime_pretransfer: %{time_pretransfer}\ntime_redirect: %{time_redirect}\ntime_starttransfer: %{time_starttransfer}\ntime_total: %{time_total}\n" "https://""$@"
  #    time_namelookup: took from the start until the name resolving was completed.
  #       time_connect: took from the start until the TCP connect to the remote host (or proxy) was completed.
  #    time_appconnect: took from the start until the SSL/SSH/etc connect/handshake to the remote host was completed. (Added in 7.19.0)
  #   time_pretransfer: took from the start until the file transfer was just about to begin. This includes all pre-transfer commands and negotiations that are specific to the particular protocol(s) involved.
  #      time_redirect: took for all redirection steps include name lookup, connect, pretransfer and transfer before the final transaction was started. time_redirect shows the complete execution time for multiple redirections. (Added in 7.12.3)
  # time_starttransfer: took from the start until the first byte was just about to be transferred. This includes time_pretransfer and also the time the server needed to calculate the result.
  #         time_total: The total time, in seconds, that the full operation lasted. The time will be displayed with millisecond resolution.
}

# ssh choose local or remote raspberry
function raspberry() {
  if [[ "$(uname)" == "Linux" ]]; then # Ubuntu/Linux-specific environment variable settings
    current_network_name=$(nmcli -t -f active,ssid dev wifi show | grep SSID | awk '{print $2}' | tr -d '\n') # 当前所在网络名称
  elif [[ "$(uname)" == "Darwin" ]]; then # macOS-specific environment variable settings
    current_network_name=$(networksetup -getairportnetwork en0 | awk -F' ' '{print $4}' | tr -d '\n') # 当前所在网络名称
  fi
  local_network_name="home" # 局域网网络名称
  success_command="ssh localraspberry" # 要执行的命令，如果Ping成功
  failure_command="ssh remoteraspberry" # 要执行的命令，如果Ping失败
  # 使用ping命令来检测是否可以Ping通地址
  if [ "$current_network_name" = "$local_network_name" ]; then
    # 如果Ping成功，则执行成功命令
    eval "$success_command"
  else
    # 如果Ping失败，则执行失败命令
    eval "$failure_command"
  fi
}

# neovide server
function nvd() {
  if [[ "$(uname)" == "Linux" ]]; then # Ubuntu/Linux-specific environment variable settings
    if [[ $# -eq 0 ]]; then
      command lvim --headless --listen localhost:5678 > /dev/null 2>&1 &
    else
      command lvim "$@" --headless --listen localhost:5678 > /dev/null 2>&1 &
    fi
  elif [[ "$(uname)" == "Darwin" ]]; then # macOS-specific environment variable settings
    command neovide --frame buttonless --server=localhost:5678
  fi
}

if [[ "$(uname)" == "Linux" ]]; then # Ubuntu/Linux-specific environment variable settings
  # Spark LLM from  iFLY TEK
  function spk() {
    command python3 ~/repo/spark/run.py "$@"
  }
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
    success_command="ssh localubuntu" # 要执行的命令，如果Ping成功
    failure_command="ssh remoteubuntu" # 要执行的命令，如果Ping失败
    # 使用ping命令来检测是否可以Ping通地址
    if [ "$current_network_name" = "$local_network_name" ]; then
      # 如果Ping成功，则执行成功命令
      eval "$success_command"
    else
      # 如果Ping失败，则执行失败命令
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
