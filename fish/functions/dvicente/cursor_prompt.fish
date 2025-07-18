function cursor_prompt -d "Set up a simple prompt when running under Cursor agents"
    # Only use minimal prompt for actual Cursor AI agents, not human interactive sessions
    # Check for Cursor environment AND ensure it's not an interactive session
    if set -q CURSOR_TRACE_ID; and not status is-interactive
        # Use an ultra-minimal prompt for maximum performance in Cursor agents
        function fish_prompt
            set -l last_status $status
            
            # Ultra-minimal prompt: just status indication
            if test $last_status -eq 0
                echo '$ '
            else
                echo (set_color red)'$ '(set_color normal)
            end
        end
        
        function fish_right_prompt
            # Empty right prompt for agents - no distractions
        end
        
        return 0
    else
        return 1
    end
end 