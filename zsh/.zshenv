# Loaded for every zsh invocation (interactive, non-interactive, scripts, GUI).
# Keep this minimal: env vars only. Do NOT set PATH here — macOS /etc/zprofile
# runs path_helper later and will reorder it. PATH belongs in .zprofile.

export EDITOR='nvim'
# Guarded so child shells inherit parent's value and skip the uname fork.
: ${ZSH_OS:=$(uname -s)}
export ZSH_OS

# Project paths used by build scripts (must be visible to non-interactive shells)
if [[ -f /proc/version && $(grep -i Microsoft /proc/version) ]]; then # WSL
  export NPC_HOME="$HOME/repo/ysyx-workbench/npc"
  export NVBOARD_HOME="$HOME/repo/ysyx-workbench/nvboard"
elif [[ "$ZSH_OS" == "Linux" ]]; then
  export AM_HOME="$HOME/repo/ysyx-workbench/abstract-machine"
  export NEMU_HOME="$HOME/repo/ysyx-workbench/nemu"
  export NPC_HOME="$HOME/repo/ysyx-workbench/npc"
  export NVBOARD_HOME="$HOME/repo/ysyx-workbench/nvboard"
fi
