complete -c tmux-connect -f
complete -c tmux-connect -n "not __fish_seen_subcommand_from work personal" \
    -a work -d "Work workspace (~/Projects)"
complete -c tmux-connect -n "not __fish_seen_subcommand_from work personal" \
    -a personal -d "Personal workspace (~/Projects/Personal)"
complete -c tmux-connect -s w -l window -d "Open a new Ghostty window pinned to it"
complete -c tmux-connect -s l -l local -d "Skip the remote lookup (no SSH round-trip)"
complete -c tmux-connect -s h -l help -d "Show usage"
