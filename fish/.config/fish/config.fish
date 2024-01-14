if status is-interactive
    # Commands to run in interactive sessions can go here
end
################################################################################
# General Settings
################################################################################
fish_config theme choose "Catppuccin Frappe"
proxy_clash
set fish_greeting

################################################################################
# Plugins
################################################################################
zoxide init fish | source # z - A smarter cd command. Supports all major shells. https://github.com/ajeetdsouza/zoxide

################################################################################
# ENV and PATH
################################################################################
if test -n "$TMUX"
    set TERM "tmux-256color"
else
    set TERM "xterm-256color"
end
set -x EDITOR 'lvim'
if test (uname) = "Linux" # Ubuntu/Linux-specific environment variable settings
    # ysyx
    set AM_HOME "$HOME/repo/ysyx-workbench/abstract-machine"
    set NEMU_HOME "$HOME/repo/ysyx-workbench/nemu"
    set NPC_HOME "$HOME/repo/ysyx-workbench/npc"
    set NVBOARD_HOME "$HOME/repo/ysyx-workbench/nvboard"
    # Zephyr SDK, installed for zmk
    source $HOME/zephyr-sdk-0.15.0/environment-setup-x86_64-pokysdk-linux 
else if test (uname) = "Darwin" # macOS-specific environment variable settings
    set HOMEBREW_BOTTLE_DOMAIN 'https://mirrors.ustc.edu.cn/homebrew-bottles'
    set JAVA_HOME (command java -XshowSettings:properties -version 2>&1 | awk '/java.home/ {print $3}') # Path to Java
    set MATLAB_ROOT '/Applications/MATLAB_R2022b_Beta.app'
end

if test (uname) = "Linux" # Ubuntu/Linux-specific environment variable settings
    fish_add_path "$HOME/bin" "/usr/local/bin"
    fish_add_path "$HOME/.local/bin"
    fish_add_path "/usr/local/go/bin"
    fish_add_path "$HOME/go/bin"
    fish_add_path "$HOME/.emacs.d/bin"
    fish_add_path "$HOME/.local/share/coursier/bin" # coursier install directory
    fish_add_path "$HOME/julia-1.9.2/bin"
    # fish_add_path "/usr/local/cuda-12.2/bin"
    fish_add_path "/usr/local/cuda-11.8/bin"
else if test (uname) = "Darwin" # macOS-specific environment variable settings
    fish_add_path "/opt/homebrew/bin"
    fish_add_path "$HOME/.local/bin"
    fish_add_path "$HOME/Qt/5.15.2/clang_64/bin"
    fish_add_path "/opt/homebrew/opt/tcl-tk/bin"
    fish_add_path "/opt/homebrew/opt/bison/bin"
    fish_add_path "/opt/homebrew/opt/curl/bin"
    fish_add_path "/opt/homebrew/opt/ruby/bin"
    fish_add_path "/opt/homebrew/opt/openjdk/bin"
    fish_add_path "/opt/homebrew/opt/llvm/bin"
    fish_add_path "/opt/homebrew/opt/ruby/bin"
    fish_add_path "/opt/homebrew/opt/openssl@3/bin"
    fish_add_path "$HOME/.emacs.d/bin"
    fish_add_path "$MATLAB_ROOT/bin"
    fish_add_path "$HOME/.rvm/bin"
    fish_add_path "/Applications/gtkwave.app/Contents/Resources/bin/"
    fish_add_path "/usr/local/mysql/bin"
    fish_add_path "$HOME/.spicetify"
end

################################################################################
# PERL
################################################################################
if test (uname) = "Linux" # Ubuntu/Linux-specific environment variable settings
    fish_add_path "$HOME/perl5/bin" 
    set -x PERL5LIB "$HOME/perl5/lib/perl5" $PERL5LIB
    set -x PERL_LOCAL_LIB_ROOT "$HOME/perl5" $PERL_LOCAL_LIB_ROOT
    set -x PERL_MB_OPT "--install_base \"$HOME/perl5\"" $PERL_MB_OPT
    set -x PERL_MM_OPT "INSTALL_BASE=$HOME/perl5" $PERL_MM_OPT
end

################################################################################
# CONDA
################################################################################
# !! Contents within this block are managed by 'conda init' !!
if test -f "$HOME/miniconda3/bin/conda"
    eval "$HOME/miniconda3/bin/conda" "shell.fish" "hook" $argv | source
end

################################################################################
# Other configs
################################################################################
thefuck --alias | source

################################################################################
# Alias
################################################################################
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
alias l='ls -lah'
alias ls='lsd' # The next gen file listing command. Backwards compatible with ls.
alias m='tldr' # man
alias mkdir='mkdir -pv'
alias nn='lvim' # LunarVim
alias ping='ping -c 5' # Stop after sending count ECHO_REQUEST packets #
alias pip='pip3'
alias ps='procs' # A modern replacement for ps written in Rust.
alias python='python3'
alias ra='ranger'
alias mysudo='sudo -E env "PATH=$PATH"'
if test (uname) = "Linux" # Ubuntu/Linux-specific environment variable settings
    alias update='sudo apt update && sudo apt upgrade -y'
    alias rm='trash-put' # Don't ask. Asking is a lesson learned in blood and tears.
else if test (uname) = "Darwin" # macOS-specific environment variable settings
    alias update='brew update && brew upgrade'
    alias r='radian' # let r open radian
    alias rm='trash' # Don't ask. Asking is a lesson learned in blood and tears.
    alias emacs="open -a /Applications/Emacs.app/ $1"
end

################################################################################
# Vim mode and Custom bindings
################################################################################
function fish_user_key_bindings
    # Execute this once per mode that emacs bindings should be used in
    fish_default_key_bindings -M insert

    # Then execute the vi-bindings so they take precedence when there's a conflict.
    # Without --no-erase fish_vi_key_bindings will default to
    # resetting all bindings.
    # The argument specifies the initial mode (insert, "default" or visual).
    fish_vi_key_bindings --no-erase insert

    bind --mode insert \e\[13\;2u insert-line-under # Shift+Enter -> insert new line under
end

# Emulates vim's cursor shape behavior
# Set the normal and visual mode cursors to a block
set fish_cursor_default block
# Set the insert mode cursor to a line
set fish_cursor_insert line
# Set the replace mode cursors to an underscore
set fish_cursor_replace_one underscore
set fish_cursor_replace underscore
# Set the external cursor to a line. The external cursor appears when a command is started.
# The cursor shape takes the value of fish_cursor_default when fish_cursor_external is not specified.
set fish_cursor_external line
# The following variable can be used to configure cursor shape in
# visual mode, but due to fish_cursor_default, is redundant here
set fish_cursor_visual block

