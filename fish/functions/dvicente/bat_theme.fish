function bat_theme -d "Bat theme depending on the system setting"
    if test $(dark-notify -e) = 'dark'
        echo "Catppuccin Mocha"
    else
        echo "Catppuccin Latte"
    end
end
