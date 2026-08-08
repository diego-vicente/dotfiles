function tmux-connect -d "Attach to a named tmux workspace (work|personal)"
    # Work repos live directly under ~/Projects; personal ones are nested one
    # level deeper, so "work" deliberately starts one directory up.
    set -l workspace_names work personal
    set -l workspace_dirs $HOME/Projects $HOME/Projects/Personal

    # Ghostty runs `command` through a login shell before config is sourced, so
    # a bare `tmux` is not on PATH yet when spawning a window.
    set -l tmux_bin /opt/homebrew/bin/tmux

    argparse --name=tmux-connect h/help w/window -- $argv
    or return 2

    if set -q _flag_help; or test (count $argv) -ne 1
        echo "usage: tmux-connect [-w|--window] {"(string join '|' $workspace_names)"}"
        echo
        echo "  Attaches in the current terminal, or switches session if already"
        echo "  inside tmux. With -w, opens a new Ghostty window pinned to it."
        test -n "$_flag_help"; and return 0
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
    # Switch the existing client instead.
    if set -q TMUX
        $tmux_bin switch-client -t $workspace
    else
        $tmux_bin attach-session -t $workspace
    end
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
