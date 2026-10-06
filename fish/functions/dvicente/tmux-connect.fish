function tmux-connect -d "Attach a tmux session in the work or personal context"
    # Sessions are named <context>/<project>. The prefix is the ONLY grouping
    # mechanism: no separate sockets, no TMUX_TMPDIR.
    #
    # Why not sockets: rootshell's session discovery runs as its own SSH exec
    # channel, which never sees a profile's env or an interactive shell, so it
    # always resolves to the default socket. Isolating by socket would make the
    # phone's native picker permanently blind. Prefixes keep every session
    # visible there AND readable, at the cost of being a convention rather than
    # a wall.
    #
    # Also: TMUX_TMPDIR pointing at a directory that does not exist makes tmux
    # SILENTLY fall back to the default socket. That trap cost an evening.
    set -l contexts work personal
    set -l context_roots $HOME/Projects $HOME/Projects/Personal

    set -l tmux_bin /opt/homebrew/bin/tmux
    set -l default_project main

    argparse --name=tmux-connect h/help w/window -- $argv
    or return 2

    if set -q _flag_help
        echo "usage: tmux-connect [-w|--window] {"(string join '|' $contexts)"} [project]"
        echo
        echo "  tmux-connect work            -> newest work/* session, else work/$default_project"
        echo "  tmux-connect work api        -> session work/api      in ~/Projects/api"
        echo "  tmux-connect personal garden -> session personal/garden"
        echo "  -w  open a new Ghostty window pinned to it"
        return 0
    end

    if test (count $argv) -lt 1 -o (count $argv) -gt 2
        echo "tmux-connect: expected a context and an optional project" >&2
        echo "known contexts: $contexts" >&2
        return 2
    end

    set -l context $argv[1]
    set -l index (contains -i -- $context $contexts)
    or begin
        echo "tmux-connect: unknown context '$context'" >&2
        echo "known: $contexts" >&2
        return 2
    end

    set -l root $context_roots[$index]
    set -l session
    set -l workdir

    # RESTORE BEFORE CHOOSING, or the first command after a reboot wins a race
    # it should not enter. With no server running, `new-session -A` below would
    # START the server, which is what triggers tmux-continuum's auto-restore —
    # in the background. This function would then attach to the session it just
    # invented while the real ones materialise beside it, and the restore would
    # look like it never ran.
    #
    # Doing it here instead: start a bare server, restore synchronously, and
    # only then look at what exists. `start-server` creates no session, so there
    # is nothing for restore to collide with.
    set -l restore $HOME/.tmux/plugins/tmux-resurrect/scripts/restore.sh
    if not $tmux_bin has-session 2>/dev/null; and test -x $restore
        set -l last $HOME/.local/share/tmux/resurrect/last
        test -e $last; or set last $HOME/.tmux/resurrect/last
        if test -e $last
            # -f, not a bare start-server followed by source-file. A server
            # with no sessions exits immediately, because exit-empty defaults
            # to ON and only this config turns it off — so the bare form dies
            # before the source-file lands and the restore has nothing to run
            # against.
            $tmux_bin -f $HOME/.config/tmux/tmux.conf start-server
            $restore >/dev/null 2>&1
        end
    end

    if test (count $argv) -eq 2
        set -l project $argv[2]
        set session "$context/$project"
        set workdir $root
        test -d "$root/$project"; and set workdir "$root/$project"
    else
        # No project named: go to the context's most recently active session
        # rather than inventing one. Creating "<context>/main" when the context
        # already had sessions was just noise.
        set -l existing ($tmux_bin list-sessions \
            -F '#{session_activity} #{session_name}' 2>/dev/null \
            | string match -r "^\\d+ $context/.*" \
            | sort -rn | head -1 | string replace -r '^\\d+ ' '')
        if test -n "$existing"
            set session $existing
            set workdir ($tmux_bin display-message -p -t $session '#{session_path}' 2>/dev/null)
            test -n "$workdir"; or set workdir $root
        else
            set session "$context/$default_project"
            set workdir $root
        end
    end

    # Detached first: the session then exists even if the GUI step fails, and
    # the phone can attach to it with no Ghostty window ever open.
    $tmux_bin new-session -A -d -s $session -c $workdir

    # Not consumed by anything yet: window names fall back to the directory
    # basename, because automatic-rename-format runs with no session bound and
    # cannot read this. Kept because hook-driven naming, which does run with a
    # session, would use it.
    $tmux_bin set -t $session @root $workdir

    if set -q _flag_window
        _tmux_connect_ghostty_window $session $workdir "$tmux_bin"
        return $status
    end

    # Nesting tmux inside tmux means every keystroke needs a doubled prefix.
    if set -q TMUX
        $tmux_bin switch-client -t $session
    else
        $tmux_bin attach-session -t $session
    end
end

function _tmux_connect_ghostty_window -d "Open a Ghostty window pinned to a tmux session"
    set -l session $argv[1]
    set -l workdir $argv[2]
    set -l tmux_bin $argv[3]

    # `ghostty +new-window` is GTK/Linux only and is not planned for the macOS
    # CLI, so the AppleScript API added in Ghostty 1.3 is the supported route.
    printf '%s\n' "
        tell application \"Ghostty\"
            activate
            set cfg to new surface configuration
            set command of cfg to \"$tmux_bin new-session -A -s $session\"
            set initial working directory of cfg to \"$workdir\"
            set environment variables of cfg to {\"TMUX_CONTEXT=$session\"}
            new window with configuration cfg
        end tell
    " | osascript
end
