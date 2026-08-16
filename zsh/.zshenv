# Loaded for every zsh invocation (interactive, non-interactive, scripts, GUI).
# Keep this minimal: env vars only. Do NOT set PATH here — macOS /etc/zprofile
# runs path_helper later and will reorder it. PATH belongs in .zprofile.

export EDITOR='nvim'
if [[ -z "${ZSH_OS:-}" ]]; then
  case "$OSTYPE" in
    darwin*) ZSH_OS=Darwin ;;
    linux*) ZSH_OS=Linux ;;
    *) ZSH_OS="$OSTYPE" ;;
  esac
fi
export ZSH_OS

# Project paths used by build scripts (must be visible to non-interactive shells)
if [[ -n "${WSL_DISTRO_NAME:-}" || -n "${WSL_INTEROP:-}" ]]; then # WSL
  export NPC_HOME="$HOME/repo/ysyx-workbench/npc"
  export NVBOARD_HOME="$HOME/repo/ysyx-workbench/nvboard"
elif [[ "$ZSH_OS" == "Linux" ]]; then
  export AM_HOME="$HOME/repo/ysyx-workbench/abstract-machine"
  export NEMU_HOME="$HOME/repo/ysyx-workbench/nemu"
  export NPC_HOME="$HOME/repo/ysyx-workbench/npc"
  export NVBOARD_HOME="$HOME/repo/ysyx-workbench/nvboard"
fi
