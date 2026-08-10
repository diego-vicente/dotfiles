complete -c tmux-connect -f
complete -c tmux-connect -n "not __fish_seen_subcommand_from work personal" \
    -a work -d "Work context (~/Projects)"
complete -c tmux-connect -n "not __fish_seen_subcommand_from work personal" \
    -a personal -d "Personal context (~/Projects/Personal)"
complete -c tmux-connect -n "__fish_seen_subcommand_from work" \
    -a "(command ls ~/Projects 2>/dev/null)" -d Project
complete -c tmux-connect -n "__fish_seen_subcommand_from personal" \
    -a "(command ls ~/Projects/Personal 2>/dev/null)" -d Project
complete -c tmux-connect -s w -l window -d "Open a new Ghostty window pinned to it"
complete -c tmux-connect -s h -l help -d "Show usage"
