function lazygit_theme -d "Lazygit theme depending on the system setting"
    set -l config_dir ~/Projects/Personal/dotfiles/lazygit

    if test $(dark-notify -e) = "dark"
        echo $config_dir/mocha.yml
    else
        echo $config_dir/latte.yml
    end
end
