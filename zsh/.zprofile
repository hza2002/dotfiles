# Loaded once per login shell, after .zshenv and BEFORE .zshrc.
# PATH and one-time session setup live here so anything launched from this
# session (tmux server, scripts spawned by GUI apps, ssh, etc.) inherits them.

########################## 🔽 BREW 🔽 ##########################
if [[ "$ZSH_OS" == "Darwin" ]]; then
  # 换清华源
  # export HOMEBREW_API_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api"
  # export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"
  # export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
  # export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git"
  # export HOMEBREW_PIP_INDEX_URL="https://pypi.tuna.tsinghua.edu.cn/simple"
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
  if [[ -n "${HOMEBREW_PREFIX:-}" ]]; then
    fpath=("${HOMEBREW_PREFIX}/share/zsh/functions" $fpath)
    typeset -U fpath
  fi
fi
########################## 🔼 BREW 🔼 ##########################

########################## 🔽 PATH 🔽 ##########################
[[ -r "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env" # Rust

if [[ "$ZSH_OS" == "Linux" ]]; then
  export PATH="$PATH:$HOME/bin:/usr/local/bin"
  export PATH="$PATH:$HOME/.local/bin"
  export PATH="$PATH:/usr/local/go/bin"
  export PATH="$PATH:$HOME/julia-1.9.2/bin"
  export PATH="$PATH:$HOME/.fnm"
  export PATH="$PATH:$HOME/.jenv/bin"
  export PATH="$PATH:/snap/bin"
  # cuda
  export PATH=${PATH}:/usr/local/cuda/bin
  export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/usr/local/cuda/lib64
  # Zephyr SDK (installed for zmk)
  [[ -r "$HOME/zephyr-sdk-0.15.0/environment-setup-x86_64-pokysdk-linux" ]] && \
    source "$HOME/zephyr-sdk-0.15.0/environment-setup-x86_64-pokysdk-linux"
elif [[ "$ZSH_OS" == "Darwin" ]]; then
  export PATH="$PATH:$HOME/.local/bin"
  export PATH="$PATH:$HOME/Library/Application Support/JetBrains/Toolbox/scripts" # JetBrains Toolbox
  export PATH="$PATH:$HOME/repo/scripts" # my custom scripts
fi
typeset -U path
########################## 🔼 PATH 🔼 ##########################
