function cursor_prompt -d "Set up a simple prompt when running under Cursor agents"
    if set -q CURSOR_TRACE_ID; or set -q CURSOR_AGENT
        function fish_prompt
            echo ''
        end
        
        function fish_right_prompt
            echo ''
        end
        
        return 0
    else
        return 1
    end
end 