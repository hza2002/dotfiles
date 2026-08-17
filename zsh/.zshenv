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
