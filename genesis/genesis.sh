#!/usr/bin/env bash
# Set up a new Mac from this repository: install the programs and link the
# configuration. Each step checks its own state first, so the script is safe to
# run again after a failure.
#
# Usage, on the new Mac:
#   git clone https://github.com/diego-vicente/dotfiles.git ~/Projects/Personal/dotfiles
#   ~/Projects/Personal/dotfiles/genesis/genesis.sh
#
# The macOS preferences are a separate step: genesis/macos-defaults.sh.
set -euo pipefail

readonly GENESIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_DIR="$(dirname "$GENESIS_DIR")"
readonly BREWFILE="$GENESIS_DIR/Brewfile"

readonly BREW_PREFIX="/opt/homebrew"
readonly BREW_BIN="$BREW_PREFIX/bin/brew"
readonly BREW_INSTALL_URL="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
readonly CLT_POLL_SECONDS=10

readonly LOCAL_BIN="$HOME/.local/bin"
readonly CLAUDE_INSTALL_URL="https://claude.ai/install.sh"
readonly UV_INSTALL_URL="https://astral.sh/uv/install.sh"
readonly GCLOUD_INSTALL_URL="https://sdk.cloud.google.com"
readonly GCLOUD_DIR="$LOCAL_BIN/google-cloud-sdk"
# Global npm packages, as "binary:package" pairs
readonly NPM_GLOBALS=("carto:@carto/carto-cli" "bw:@bitwarden/cli")

readonly FISH_BIN="$BREW_PREFIX/bin/fish"
readonly SHELLS_FILE="/etc/shells"
readonly FISHER_URL="https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish"

readonly BITWARDEN_EU_SERVER="https://vault.bitwarden.eu"

# Claude Code skills live in the Obsidian vault, which Obsidian Sync restores
readonly VAULT_DIR="$HOME/Projects/Personal/Digital Garden"
readonly SKILLS_SOURCE="$VAULT_DIR/Assets/Claude Code Skills"
readonly SKILLS_LINK="$REPO_DIR/claude/skills"

step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
skip() { printf '    already done: %s\n' "$*"; }

install_command_line_tools() {
  step "Xcode Command Line Tools"
  if xcode-select -p >/dev/null 2>&1; then
    skip "installed at $(xcode-select -p)"
    return
  fi
  xcode-select --install || true
  echo "    Finish the installer dialog. Waiting for it to complete..."
  until xcode-select -p >/dev/null 2>&1; do sleep "$CLT_POLL_SECONDS"; done
}

install_homebrew() {
  step "Homebrew"
  if [[ -x "$BREW_BIN" ]]; then
    skip "$("$BREW_BIN" --version | head -1)"
  else
    # The non-interactive installer needs a cached sudo password
    sudo -v
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL "$BREW_INSTALL_URL")"
  fi
  eval "$("$BREW_BIN" shellenv)"
}

install_bundle() {
  step "Brewfile packages"
  if brew bundle check --file="$BREWFILE" >/dev/null 2>&1; then
    skip "every Brewfile entry is installed"
    return
  fi
  brew bundle install --file="$BREWFILE"
}

# Run a vendor install script when its binary is missing
install_with_vendor_script() {
  local name="$1" binary="$2" url="$3"
  shift 3
  step "$name"
  if [[ -x "$binary" ]]; then
    skip "$binary"
    return
  fi
  curl -fsSL "$url" | bash -s -- "$@"
}

install_vendor_tools() {
  install_with_vendor_script "Claude Code (native installer)" "$LOCAL_BIN/claude" "$CLAUDE_INSTALL_URL"
  install_with_vendor_script "uv (standalone installer)" "$LOCAL_BIN/uv" "$UV_INSTALL_URL"
  install_with_vendor_script "Google Cloud CLI" "$GCLOUD_DIR/bin/gcloud" "$GCLOUD_INSTALL_URL" \
    --disable-prompts --install-dir="$LOCAL_BIN"
}

install_npm_globals() {
  step "Global npm packages"
  local pair binary package
  for pair in "${NPM_GLOBALS[@]}"; do
    binary="${pair%%:*}"
    package="${pair#*:}"
    if command -v "$binary" >/dev/null 2>&1; then
      skip "$package"
    else
      npm install --global "$package"
    fi
  done
}

init_submodules() {
  step "Git submodules"
  # A fresh Mac has no SSH key yet, so fetch the GitHub submodules over HTTPS
  git -C "$REPO_DIR" -c "url.https://github.com/.insteadOf=git@github.com:" \
    submodule update --init --recursive
}

link_dotfiles() {
  step "Configuration links"
  # link-dotfiles.sh links from $PWD, so it must run from the repository root
  (cd "$REPO_DIR" && ./scripts/link-dotfiles.sh)

  if [[ -L "$SKILLS_LINK" ]]; then
    skip "$SKILLS_LINK"
  else
    ln -s "$SKILLS_SOURCE" "$SKILLS_LINK"
    echo "    Linked $SKILLS_LINK. It resolves after Obsidian Sync restores the vault."
  fi
}

set_up_fish() {
  step "fish as the login shell"
  if [[ ! -t 0 ]]; then
    # sudo and chsh read a password from the terminal. Over a plain SSH command
    # there is none, so skip this part and let the other steps run.
    echo "    skipped: no terminal for the password prompt. Run genesis.sh again in a terminal."
  else
    register_fish_as_login_shell
  fi

  step "fish plugins"
  if "$FISH_BIN" -c 'type -q fisher'; then
    skip "fisher is installed"
  else
    # fisher update installs every plugin listed in fish/fish_plugins
    "$FISH_BIN" -c "curl -fsSL $FISHER_URL | source && fisher update"
  fi
}

register_fish_as_login_shell() {
  if grep -qx "$FISH_BIN" "$SHELLS_FILE"; then
    skip "$FISH_BIN is in $SHELLS_FILE"
  else
    echo "$FISH_BIN" | sudo tee -a "$SHELLS_FILE" >/dev/null
  fi
  if [[ "$(dscl . -read "$HOME" UserShell | awk '{print $2}')" == "$FISH_BIN" ]]; then
    skip "login shell is $FISH_BIN"
  else
    chsh -s "$FISH_BIN"
  fi
}

configure_bitwarden_cli() {
  step "Bitwarden CLI region"
  local server
  server="$(bw config server 2>/dev/null || true)"
  if [[ "$server" == "$BITWARDEN_EU_SERVER" ]]; then
    skip "bw points at $BITWARDEN_EU_SERVER"
  else
    bw config server "$BITWARDEN_EU_SERVER"
  fi
}

print_manual_steps() {
  step "Done. Finish these steps by hand:"
  cat <<EOF
  1. Sign in: Bitwarden app, then 'bw login'. Obsidian Sync, into "$VAULT_DIR".
     gh auth login. gcloud auth login. Docker Desktop. Orca.
  2. Atuin: 'atuin login -u dvicente', with the encryption key from Bitwarden.
  3. Claude Code: run genesis/claude-transfer.sh unpack, then 'claude' to log in.
  4. Create or copy an SSH key, then point the remotes back to SSH:
     git -C "$REPO_DIR" remote set-url origin git@github.com:diego-vicente/dotfiles.git
  5. Optional: genesis/macos-defaults.sh for the system preferences.
EOF
}

main() {
  install_command_line_tools
  install_homebrew
  install_bundle
  install_vendor_tools
  install_npm_globals
  init_submodules
  link_dotfiles
  set_up_fish
  configure_bitwarden_cli
  print_manual_steps
}

main "$@"
