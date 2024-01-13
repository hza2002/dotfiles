function brew
    command brew $argv
    if string match --regex 'upgrade|update|outdated' $argv
        sketchybar --trigger brew_update
    end
end

