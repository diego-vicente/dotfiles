# fish — dvicente-claw (Debian, headless)
#
# A cropped sibling of ../../fish/config.fish, NOT a copy. The laptop config
# assumes a Mac desktop and would half-fail here, silently: `direnv hook fish |
# source` on a box with no direnv makes every shell print an error, and a
# missing binary in a `| source` pipeline is a broken prompt, not a warning.
#
# Deliberately absent, because none of it exists on this machine:
#   Homebrew paths, cmux, /Applications/*, Cargo, the 1Password service-account
#   token, OBSIDIAN_VAULT_PATH, tide + fisher plugins, and every alias pointing
#   at a tool that isn't installed (eza, bat, viddy, lazygit, zoxide, atuin,
#   thefuck, direnv, uv).
#
# Re-add a block here only once the tool is actually installed on the box.

# ---------------------------------------------------------------------------
# PATH — guarded, so a missing directory never silently pollutes it
# ---------------------------------------------------------------------------
for dir in ~/.local/bin ~/bin ~/.claude/bin
    test -d $dir; and fish_add_path --prepend $dir
end

# Own functions live in a subfolder, same convention as the laptop
set -a fish_function_path $__fish_config_dir/functions

# Claude Code clamps itself to 256 colours whenever $TMUX is set — a defensive
# chalk.level = 2 in src/ink/colorize.ts (clampChalkLevelForTmux), applied
# regardless of whether truecolor actually works. Ours does: tmux negotiates
# RGB with Ghostty and 24-bit escapes pass through byte-identical.
#
# Set OUTSIDE `status is-interactive` and NOT in settings.json: the clamp is
# evaluated at module load, before settings env injection, so settings.json is
# too late, and Claude Code is not always launched from an interactive shell.
#
# Undocumented escape hatch — see anthropics/claude-code#46146. It can vanish
# without a changelog entry; if colours go washed out again, check that first.
set -gx CLAUDE_CODE_TMUX_TRUECOLOR 1

# ---------------------------------------------------------------------------
# Interactive
# ---------------------------------------------------------------------------
if status is-interactive
    fish_default_key_bindings

    # Colour works over SSH into Ghostty and rootshell alike
    set -gx COLORTERM truecolor
    set -gx fish_term24bit 1

    set -g fish_greeting

    # Make it obvious which machine you are on when nested inside the laptop's
    # tmux. The laptop uses tide; installing it here would mean fisher, plugins
    # and a network fetch on a box whose whole job is to be boring.
    function fish_prompt
        set_color brmagenta; echo -n "claw"
        set_color normal;    echo -n ":"
        set_color cyan;      echo -n (prompt_pwd)
        set_color normal;    echo -n " \$ "
    end

    # Portable subset of the laptop's abbreviations — git and python only,
    # since those are the tools that actually exist here.
    abbr -ga gs 'git status --short'
    abbr -ga gsl 'git status'
    abbr -ga gl 'git log --all --graph'
    abbr -ga ga 'git add'
    abbr -ga gap 'git add --patch'
    abbr -ga gc 'git commit'
    abbr -ga gp 'git push'
    abbr -ga gf 'git pull'
    abbr -ga gcl 'git clone'

    abbr -ga p python3
    abbr -ga pm 'python3 -m'
    abbr -ga cl claude
end
