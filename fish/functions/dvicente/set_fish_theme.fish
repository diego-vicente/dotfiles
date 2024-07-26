function set_fish_theme --argument scheme -d "Set the fish theme based on dark-notify"
    if test "$scheme" = "dark"
        fish_config theme save "Catppuccin Mocha"
    else if test "$scheme" = "light"
        fish_config theme save "Catppuccin Latte"
    end
end
