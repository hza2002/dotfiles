function brew
    command brew $argv
    if type -q sketchybar; and string match -qr 'upgrade|update|outdated' -- $argv
        sketchybar --trigger brew_update
    end
end

