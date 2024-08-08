function ai -d "Ask an LLM"
    set prompt "\
    Answer the query being as concise as possible.
    Use a brief style with short replies - no yapping.
    "

    set stdin_pipe ""
    if not test -t 0
        # TODO: why is this needed?
        read -l -z local_stdin_pipe
        set stdin_pipe $local_stdin_pipe
    end

    set user_input (
        gum input --placeholder "Write your question..." \
                  --prompt "> " \
                  --width 80
    )

    echo "> $user_input"

    if test -z "$user_input"
        # No input provided by the user
        return
    end

    echo $stdin_pipe | llm -s "$prompt" -m gpt-4-turbo "$user_input"
end
