# server — dvicente-claw

Configs for the GCE box (`dvicente-claw`, Debian 12 bookworm, headless).

These are **cropped siblings** of the laptop configs, not copies, and they are
deliberately **not** wired into `link-dotfiles.sh` — symlinking them into a
Mac's `~/.config` would be actively wrong.

```sh
./server/deploy.sh          # scp + verify
CLAW_HOST=... ./server/deploy.sh
```

| File | Lands at |
|---|---|
| `tmux.conf` | `~/.config/tmux/tmux.conf` |
| `fish/config.fish` | `~/.config/fish/config.fish` |
| `bin/tmux-connect` | `~/bin/tmux-connect` |

## Shell layout

**Login shell stays bash. tmux panes run fish.**

The box is reached by automation that pipes bash syntax over SSH — the handover
skill, and anything doing `ssh claw '<bash>'`. Making fish the login shell
breaks all of it silently. (My own `deploy.sh` had exactly this bug before it
was hardened to force `bash -c`.) So `default-shell` in `tmux.conf` starts fish
where you actually type, and bash stays the automation-facing entry point.

That's why `tmux-connect` is POSIX `sh` here and a fish function on the laptop:
it has to work from either shell.

## Workspaces

Same two names as the laptop, on purpose — one habit, both machines.

```sh
tmux-connect work        # ~/Projects   (CartoDB remotes)
tmux-connect personal    # ~/repos      (clippy-ai-dev remotes)
```

The directories differ from the laptop because the layout does: there is no
`~/Projects/Personal` on this box, and inventing one just to match a path would
be worse than pointing at what actually exists.

## Prefix

**`C-a`, deliberately different from the laptop's `C-\` / `C-b`.**

You'll often reach this box by SSHing from inside the laptop's tmux. The outer
server swallows its own prefix bytes, so a shared prefix would never arrive.
`C-a` is distinct, and it's two taps on the rootshell toolbar.

The status bar is dark red here versus the laptop's default — when you're
nested two tmuxes deep, it must be obvious which one you're typing at.

## What was cropped, and why

| Removed | Reason |
|---|---|
| Homebrew paths, `/Applications/*`, cmux | macOS only |
| tide, fisher plugins, nvm, bass | would need a network fetch on a box whose job is to be boring |
| direnv, cargo, atuin, zoxide, thefuck | not installed; `direnv hook fish \| source` on a box without direnv errors on *every* shell |
| eza/bat/viddy/lazygit aliases | binaries absent |
| 1Password service-account token | not present here |
| `OBSIDIAN_VAULT_PATH`, Obsidian CLI path | laptop concept |
| `pbcopy` in copy-mode | no macOS — OSC 52 sends to the *client* clipboard, which is the only thing that makes sense headless |
| `xterm-ghostty` overrides | `ssh_config` sets `TERM=xterm-256color` for this hop, so the ghostty entry never matches |
| tpm + all plugins | keep an agent box dependency-free |
| `work`/`personal` bindings | those are a two-Ghostty-window concept |

Re-add a block only once the tool is actually installed on the box.

## Versions

- tmux **3.5a** from `bookworm-backports` (Debian ships 3.3a). Upstream is 3.7b;
  going newer means building from source with `libevent-dev`, `libncurses-dev`,
  `bison`, `pkg-config`.
- fish **3.6.0** from bookworm, already listed in `/etc/shells`.

## Networking

On the tailnet as **`gcloud-ai-instance`** (`100.108.1.3`). `~/.ssh/config` has
a `Host claw` block pointing at the MagicDNS name, which `deploy.sh` uses by
default; override with `CLAW_HOST`.

The box also has a **static public IP** (`34.45.78.65`), so unlike the roaming
laptop it was already reachable. Tailscale here buys consistent naming and mesh
with the Mac, not reachability — that public IP still works as a fallback if
the tailnet is down.

The iPhone's rootshell key is in `~/.ssh/authorized_keys`. Entries 1 and 3 of
that file are `# Added by Google`; `google-guest-agent` is currently inactive
and OS Login is unset, so nothing rewrites the file — but if that agent is ever
re-enabled it can rewrite it and drop the key. First thing to suspect if the
phone stops connecting.
