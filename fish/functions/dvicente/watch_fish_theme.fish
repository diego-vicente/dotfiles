function watch_fish_theme -d "Watch for changes in the theme"
    dark-notify | while read -a line
        set_fish_theme $line
    end
end
