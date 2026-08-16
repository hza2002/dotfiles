# Loaded once per login shell, after .zshenv and BEFORE .zshrc.
# PATH and one-time session setup live here so anything launched from this
# session (tmux server, scripts spawned by GUI apps, ssh, etc.) inherits them.

########################## 🔽 BREW 🔽 ##########################
if [[ "$ZSH_OS" == "Darwin" ]]; then
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

if (( $+commands[uv] )); then
  export UV_PYTHON_BIN_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/uv/bin"
  path=("$UV_PYTHON_BIN_DIR" $path) # uv-managed default Python for humans and agents
fi

if (( $+commands[fnm] )); then
  eval "$(fnm env --use-on-cd --shell zsh)" # Node.js, including non-interactive login shells
fi

if [[ "$ZSH_OS" == "Linux" ]]; then
  for bin_dir in \
    "$HOME/bin" \
    "$HOME/.local/bin" \
    /usr/local/bin \
    /usr/local/go/bin \
    "$HOME/julia-1.9.2/bin" \
    "$HOME/.fnm" \
    "$HOME/.jenv/bin" \
    /snap/bin; do
    [[ -d "$bin_dir" ]] && path+=("$bin_dir")
  done
  # cuda
  [[ -d /usr/local/cuda/bin ]] && path+=(/usr/local/cuda/bin)
  [[ -d /usr/local/cuda/lib64 ]] && export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}/usr/local/cuda/lib64"
  # Zephyr SDK (installed for zmk)
  [[ -r "$HOME/zephyr-sdk-0.15.0/environment-setup-x86_64-pokysdk-linux" ]] && \
    source "$HOME/zephyr-sdk-0.15.0/environment-setup-x86_64-pokysdk-linux"
elif [[ "$ZSH_OS" == "Darwin" ]]; then
  export PATH="$PATH:$HOME/.local/bin"
  [[ -d "$HOME/miniconda3/condabin" ]] && path+=("$HOME/miniconda3/condabin")
  export PATH="$PATH:$HOME/Library/Application Support/JetBrains/Toolbox/scripts" # JetBrains Toolbox
fi
typeset -U path
########################## 🔼 PATH 🔼 ##########################
