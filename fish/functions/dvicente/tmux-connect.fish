function tmux-connect -d "Pick or attach a tmux workspace, local or on claw"
    # Work repos live directly under ~/Projects; personal ones are nested one
    # level deeper, so "work" deliberately starts one directory up.
    set -l workspace_names work personal
    set -l workspace_dirs $HOME/Projects $HOME/Projects/Personal

    # Ghostty runs `command` through a login shell before config is sourced, so
    # a bare `tmux` is not on PATH yet when spawning a window.
    set -l tmux_bin /opt/homebrew/bin/tmux
    set -l remote_host claw

    argparse --name=tmux-connect h/help w/window l/local -- $argv
    or return 2

    if set -q _flag_help
        echo "usage: tmux-connect [-w|--window] [-l|--local] [{"(string join '|' $workspace_names)"}]"
        echo
        echo "  With no workspace, opens a picker listing every live session on"
        echo "  this Mac and on $remote_host, plus the workspaces you can start."
        echo "  -w  open a new Ghostty window pinned to it (local only)"
        echo "  -l  skip the remote lookup (no SSH round-trip)"
        return 0
    end

    # ---- no argument: the landing page ------------------------------------
    if test (count $argv) -eq 0
        set -l choice (_tmux_connect_pick $remote_host (set -q _flag_local; and echo 1; or echo 0))
        or return 1
        test -z "$choice"; and return 1

        # Rows are "<host>\t<session>"; anything else is a start-a-new-one row.
        set -l parts (string split \t -- $choice)
        set -l host $parts[1]
        set -l session $parts[2]

        if test "$host" = "$remote_host"
            exec ssh -t $remote_host "tmux-connect $session"
        end
        set argv $session
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

function _tmux_connect_pick -d "fzf picker over local and remote tmux sessions"
    set -l remote_host $argv[1]
    set -l skip_remote $argv[2]
    set -l rows

    # Live local sessions. Deliberately no fzf --preview: a preview that shells
    # out per keystroke would fire an SSH round-trip for every remote row.
    # Everything worth knowing is already on the row.
    for line in (tmux list-sessions -F '#{session_name}|#{session_windows}|#{?session_attached,attached,}' 2>/dev/null)
        set -l f (string split '|' -- $line)
        set -a rows (printf '%s\t%s\t● %-6s %-10s %s windows %s' \
            local $f[1] local $f[1] $f[2] $f[3])
    end

    # Live remote sessions. Failure here is silent and non-fatal: the picker is
    # still useful with only local rows when claw is unreachable or you are offline.
    if test "$skip_remote" != 1
        for line in (ssh -o ConnectTimeout=4 -o BatchMode=yes $remote_host \
                        'tmux list-sessions -F "#{session_name}|#{session_windows}|#{?session_attached,attached,}"' 2>/dev/null)
            set -l f (string split '|' -- $line)
            set -a rows (printf '%s\t%s\t● %-6s %-10s %s windows %s' \
                $remote_host $f[1] $remote_host $f[1] $f[2] $f[3])
        end
    end

    # Startable workspaces that are not already live, so the picker doubles as
    # the way to create one.
    for host in local $remote_host
        for ws in work personal
            set -l already 0
            for r in $rows
                set -l rf (string split \t -- $r)
                if test "$rf[1]" = "$host" -a "$rf[2]" = "$ws"
                    set already 1
                end
            end
            test "$already" = 1; and continue
            test "$host" = "$remote_host" -a "$skip_remote" = 1; and continue
            set -a rows (printf '%s\t%s\t+ %-6s %-10s start' $host $ws $host $ws)
        end
    end

    if test (count $rows) -eq 0
        echo "tmux-connect: nothing to pick" >&2
        return 1
    end

    # Show only the third field; return the first two.
    printf '%s\n' $rows \
        | fzf --with-nth=3.. --delimiter=\t \
              --height=40% --reverse --border \
              --prompt='session > ' \
              --header='enter attach · ● live · + start' \
        | string replace -r '\t[^\t]*$' ''
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
