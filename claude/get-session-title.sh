#!/bin/bash

# Script to extract session title from session_id
# Reads JSON from stdin (hook input) and outputs the session title

# Read the JSON input from stdin
INPUT=$(cat)

# Extract session_id and project directory
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id')
PROJECT_DIR=$(echo "$INPUT" | jq -r '.cwd // empty')

# If no cwd in input, try CLAUDE_PROJECT_DIR env var
if [ -z "$PROJECT_DIR" ]; then
    PROJECT_DIR="$CLAUDE_PROJECT_DIR"
fi

# If still no project dir, use current directory
if [ -z "$PROJECT_DIR" ]; then
    PROJECT_DIR=$(pwd)
fi

# Encode project path (replace / and . with -)
# The encoding scheme used by Claude Code replaces both / and . with -
ENCODED_PROJECT=$(echo "$PROJECT_DIR" | sed 's/[\/.\ ]/-/g')

# Path to transcript file
TRANSCRIPT_FILE="$HOME/.claude/projects/$ENCODED_PROJECT/$SESSION_ID.jsonl"

# Extract the last non-warmup summary as the session title
if [ -f "$TRANSCRIPT_FILE" ]; then
    SESSION_TITLE=$(grep '"type":"summary"' "$TRANSCRIPT_FILE" | \
                    grep -v "Warmup" | \
                    tail -1 | \
                    jq -r '.summary // empty')

    # If we found a title, check if it's an internal error message (starts with "API Error: 500")
    if [ -n "$SESSION_TITLE" ] && ! echo "$SESSION_TITLE" | grep -q "^API Error: 500"; then
        echo "$SESSION_TITLE"
    else
        echo "Claude Code"
    fi
else
    # Fallback to basename of project directory if transcript not found
    basename "$PROJECT_DIR"
fi
