# Add the local binary directories as the highest priority
fish_add_path --prepend ~/.local/bin ~/Projects/bin

# Add Claude Code skill utilities (cnode, etc.)
fish_add_path --append ~/.claude/bin

# Add the snag CLI, which the snag:capture skill calls as a bare command
fish_add_path --append ~/Projects/Personal/snag/bin

# Add the Homebrew directories
fish_add_path --prepend /opt/homebrew/bin /usr/local/bin

# Set the new curl as default
fish_add_path --prepend /opt/homebrew/opt/curl/bin

# When launched inside a cmux pane, ensure cmux's claude wrapper wins over the
# native binary so hooks (session lifecycle, permission UI) reach cmux.
if set -q CMUX_SURFACE_ID
    fish_add_path --prepend /Applications/cmux.app/Contents/Resources/bin
end

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

# Configure cargo, if rustup is installed
if test -r "$HOME/.cargo/env.fish"
    source "$HOME/.cargo/env.fish"
end

# Run the function to set the Cursor prompt when ran by agents, and tide otherwise
cursor_prompt

# Evalute profile.fish
source $__fish_config_dir/profile.fish

# 1Password service account token for the `op` CLI, used by the 1password-secrets
# skill (and everything reading secrets through it). Kept in a 0600 file rather
# than inline here. Lets `op read` work non-interactively, no Touch ID prompt.
if test -r ~/.config/op/service-account-token
    set -gx OP_SERVICE_ACCOUNT_TOKEN (cat ~/.config/op/service-account-token)
end

# Define some alias
# alias bat='bat --theme=$(bat_theme)' # check fish/functions/bat_theme.fish
alias bat='bat --theme="Catppuccin Mocha"'
# lazygit theme follows the system appearance via appearance-sync's lazygit.sh
# handler, which writes ~/.config/lazygit/config.yml; plain lazygit reads it.
alias lg='lazygit'

if status is-interactive
    # Use default (emacs-style) key bindings
    fish_default_key_bindings

    # Configure the colors to work properly
    set -gx COLORTERM truecolor
    set -gx fish_term24bit 1

    # Disable the greeting
    set -g fish_greeting

    # Configure atuin
    atuin init fish --disable-up-arrow | source

    # Configure fuck, if installed. genesis/Brewfile no longer installs it.
    if type -q thefuck
        thefuck --alias | source
    end

    # Configure zoxide
    zoxide init fish | source

    # Set up some alias only for interactive sessions
    alias ls='eza --header --long --git'
    alias la='eza --header --long --git --all'
    alias lst='eza --header --long --git --tree'
    alias lat='eza --header --long --git --tree --all'
    alias tree='eza --tree'
    alias cat='bat'
    alias watch='viddy'

    # Set up some abbreviations
    abbr -ga gs 'git status --short'
    abbr -ga gsl 'git status'
    abbr -ga gl 'git log --all --graph'
    abbr -ga ga 'git add'
    abbr -ga gap 'git add --patch'
    abbr -ga gc 'git commit'
    abbr -ga gp 'git push'
    abbr -ga gf 'git pull'
    abbr -ga gcl 'git clone'

    abbr -ga ua 'uv add'
    abbr -ga ur 'uv run'

    abbr -ga p python
    abbr -ga pm 'python -m'

    abbr -ga gauth 'gcloud auth application-default login'
    abbr -ga cl claude
    abbr -ga ccl carto_claude
    abbr -ga oc opencode
end

# bun
fish_add_path $HOME/.local/bin
fish_add_path $OBSIDIAN_VAULT_PATH/.obsidian/plugins/mcp-tools/bin

# Add the Obsidian CLI
fish_add_path --append /Applications/Obsidian.app/Contents/MacOS

# Claude Code OAuth token, kept out of this tracked file on purpose
set -g CLAUDE_TOKEN_FILE $HOME/.config/claude/oauth-token
if test -r $CLAUDE_TOKEN_FILE
    set -gx CLAUDE_CODE_OAUTH_TOKEN (string trim (cat $CLAUDE_TOKEN_FILE))
end

# Local Claude Agent SDK root for the VS Code Agents window (native/BYOK mode)
set -g CLAUDE_AGENT_SDK_ROOT $HOME/.config/claude/agent-sdk
if test -d $CLAUDE_AGENT_SDK_ROOT/node_modules/@anthropic-ai/claude-agent-sdk
    set -gx VSCODE_AGENT_HOST_CLAUDE_SDK_ROOT $CLAUDE_AGENT_SDK_ROOT
end
