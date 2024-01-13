function nvd
    if test (uname) = "Linux" # Ubuntu/Linux-specific environment variable settings
        if test -z "$argv"
            command lvim --headless --listen localhost:5678 > /dev/null 2>&1 &
        else
            command lvim $argv --headless --listen localhost:5678 > /dev/null 2>&1 &
        end
    else if test (uname) = "Darwin" # macOS-specific environment variable settings
        command neovide --frame buttonless --server=localhost:5678
    end
end
