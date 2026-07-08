# direnv export for non-interactive shells (primarily Claude Code subagents)
eval "$(direnv export zsh 2>/dev/null)"

# 1Password service account token for the `op` CLI, used by the 1password-secrets
# skill (and everything reading secrets through it). Kept in a 0600 file rather
# than inline here. Sourced for every zsh (incl. non-interactive skill scripts)
# so `op read` works without a Touch ID prompt.
if [ -r "$HOME/.config/op/service-account-token" ]; then
    export OP_SERVICE_ACCOUNT_TOKEN="$(cat "$HOME/.config/op/service-account-token")"
fi
