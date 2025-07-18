# Add the local binary directories as the highest priority
fish_add_path --prepend ~/.local/bin ~/Projects/bin

# Add the Homebrew directories
fish_add_path --prepend /opt/homebrew/bin /usr/local/bin

# Set the new curl as default
fish_add_path --prepend /opt/homebrew/opt/curl/bin

# Add the Google Cloud SDK directory
fish_add_path --append ~/.local/bin/google-cloud-sdk/bin

# Add the Rust binary directory
fish_add_path --append ~/.cargo/bin

# Add the Python 3.11 directory
fish_add_path --append /Library/Frameworks/Python.framework/Versions/3.11/bin

# Add the `dvicente` subfolder to the fish functions path
set -a fish_function_path $__fish_config_dir/functions/dvicente

# Configure direnv
direnv hook fish | source

# Configure cargo
source "$HOME/.cargo/env.fish"

# Run the function to set the Cursor prompt when ran by agents, and tide otherwise
cursor_prompt

# Define some alias
alias bat='bat --theme=$(bat_theme)'  # check fish/functions/bat_theme.fish
alias lazygit='LG_CONFIG_FILE=$(lazygit_theme) /opt/homebrew/bin/lazygit'  # check fish/functions/lazygit_theme.fish
alias lg='lazygit'

if status is-interactive
    # Configure the colors to work properly
    set -gx COLORTERM truecolor
    set -gx fish_term24bit 1

    # Disable the greeting
    set -g fish_greeting

    # Configure atuin
    atuin init fish --disable-up-arrow | source

    # Configure fuck
    thefuck --alias | source

    # Configure zoxide
    zoxide init fish | source

    # Set up the vi mode
    fish_vi_key_bindings

    # Set up some alias only for interactive sessions
    alias ls='exa --header --long --git'
    alias la='exa --header --long --git --all'
    alias lst='exa --header --long --git --tree'
    alias lat='exa --header --long --git --tree --all'
    alias tree='exa --tree'
    alias cat='bat'
    alias watch='viddy'
end
