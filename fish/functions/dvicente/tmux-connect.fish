function tmux-connect -d "Attach a tmux workspace, or pick one with a gum menu"
    # Work repos live directly under ~/Projects; personal ones are nested one
    # level deeper, so "work" deliberately starts one directory up.
    set -l workspace_names work personal
    set -l workspace_dirs $HOME/Projects $HOME/Projects/Personal

    # Ghostty runs `command` through a login shell before config is sourced, so
    # a bare `tmux` is not on PATH yet when spawning a window.
    set -l tmux_bin /opt/homebrew/bin/tmux

    argparse --name=tmux-connect h/help w/window -- $argv
    or return 2

    if set -q _flag_help
        echo "usage: tmux-connect [-w|--window] [{"(string join '|' $workspace_names)"}]"
        echo
        echo "  With no workspace, opens a gum menu over every tmux session and"
        echo "  recent directory that sesh knows about."
        echo "  -w  open a new Ghostty window pinned to it"
        return 0
    end

    # ---- no argument: the landing page ------------------------------------
    if test (count $argv) -eq 0
        _tmux_connect_pick
        return $status
    end

    if test (count $argv) -ne 1
        echo "tmux-connect: one workspace at a time" >&2
        return 2
    end

    set -l workspace $argv[1]
    set -l index (contains -i -- $workspace $workspace_names)
    or begin
        echo "tmux-connect: unknown workspace '$workspace'" >&2
        echo "known: $workspace_names" >&2
        return 2
    end

    set -l workdir $workspace_dirs[$index]
    if not test -d $workdir
        echo "tmux-connect: no such directory: $workdir" >&2
        return 66
    end

    # Always create detached first: the session then exists even if the GUI step
    # fails, and the phone can attach to it with no Ghostty window ever open.
    $tmux_bin new-session -A -d -s $workspace -c $workdir

    if set -q _flag_window
        _tmux_connect_ghostty_window $workspace $workdir "$tmux_bin"
        return $status
    end

    # Nesting tmux inside tmux means every keystroke needs a doubled prefix.
    if set -q TMUX
        $tmux_bin switch-client -t $workspace
    else
        $tmux_bin attach-session -t $workspace
    end
end

function _tmux_connect_pick -d "gum menu over sesh's sessions and recent directories"
    if not command -q sesh
        echo "tmux-connect: sesh not installed (brew install sesh)" >&2
        return 127
    end
    if not command -q gum
        echo "tmux-connect: gum not installed (brew install gum)" >&2
        return 127
    end

    # --icons distinguishes a live tmux session from a zoxide directory at a
    # glance; --no-color keeps the rows plain so gum filters against the text
    # rather than against embedded escape sequences.
    # -d drops duplicates, so a directory that already has a session shows once.
    set -l rows (sesh list --icons --no-color -d 2>/dev/null)
    if test (count $rows) -eq 0
        echo "tmux-connect: sesh returned nothing" >&2
        return 1
    end

    # Colours are ANSI numbers, never hex — same rule as tmux.conf, so the menu
    # follows the terminal between catppuccin latte and mocha instead of being
    # pinned to one of them.
    set -l accent 4
    set -l muted 8

    set -l choice (printf '%s\n' $rows | gum filter \
        --height 16 \
        --prompt "❯ " \
        --indicator "▸" \
        --placeholder "session or directory…" \
        --header "attach or create" \
        --prompt.foreground $accent \
        --indicator.foreground $accent \
        --header.foreground $muted \
        --match.foreground $accent)
    or return 1
    test -z "$choice"; and return 1

    # Strip the leading icon glyph to recover the name sesh expects. sesh itself
    # decides attach-vs-switch based on $TMUX, so this works both inside and
    # outside a session.
    set -l target (string replace -r '^\S+\s+' '' -- $choice)
    sesh connect $target
end

function _tmux_connect_ghostty_window -d "Open a Ghostty window pinned to a tmux workspace"
    set -l workspace $argv[1]
    set -l workdir $argv[2]
    set -l tmux_bin $argv[3]

    # `ghostty +new-window` is GTK/Linux only and is not planned for the macOS
    # CLI, so the AppleScript API added in Ghostty 1.3 is the supported route.
    printf '%s\n' "
        tell application \"Ghostty\"
            activate
            set cfg to new surface configuration
            set command of cfg to \"$tmux_bin new-session -A -s $workspace\"
            set initial working directory of cfg to \"$workdir\"
            set environment variables of cfg to {\"TMUX_WORKSPACE=$workspace\"}
            new window with configuration cfg
        end tell
    " | osascript
end
