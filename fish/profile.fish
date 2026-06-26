# profile.fish - System-wide environment variables

# Critical universals
set -qU XDG_CONFIG_HOME; or set -Ux XDG_CONFIG_HOME $HOME/.config
set -qU XDG_DATA_HOME; or set -Ux XDG_DATA_HOME $HOME/.local/share
set -qU XDG_CACHE_HOME; or set -Ux XDG_CACHE_HOME $HOME/.cache

# Usage and tools
set -gx EDITOR hx
set -gx BUN_INSTALL "$HOME/.bun"
set -gx PATH $BUN_INSTALL/bin $PATH

# Claude Code
set -gx CLAUDE_CODE_NO_FLICKER 1

# Cloud configuration
set -gx GOOGLE_CLOUD_PROJECT cartodb-on-gcp-datascience
set -gx GOOGLE_APPLICATION_CREDENTIALS $HOME/.config/gcloud/application_default_credentials.json
