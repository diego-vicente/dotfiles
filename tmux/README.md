# tmux

Ghostty is a display surface. tmux owns sessions, windows, panes and navigation.
Every Ghostty split/tab binding is unbound in `../ghostty/config` so keystrokes
fall through to here.

## Layout

| Level | Maps to | Why |
|---|---|---|
| **session** | `work`, `personal` | A tmux client attaches to exactly one session, so the session *is* the Ghostty-window boundary. Nothing else can pin. |
| **window** | one per repo (`cloud-native`, `garden`, `dotfiles`) | Cheap, named, `alt+N` addressable, survives restore well. |
| **pane** | concurrent processes in one repo — agent / shell / logs | Split only when you must watch two things *at once*. |

Rule: **windows when the work belongs together, panes when you need to see them
simultaneously.** Six 40-column panes is theatre — and it shrinks the agent's
usable width, which visibly degrades Claude Code's TUI.

## Launching

```sh
tmux/bin/tmux-workspace.sh work
tmux/bin/tmux-workspace.sh personal
```

Idempotent (`new-session -A`), so re-running attaches instead of forking a
duplicate. Uses Ghostty 1.3's AppleScript API — `ghostty +new-window` is
GTK/Linux only and Ghostty has said it will not come to the macOS CLI.

To make them real Mac citizens: wrap each in Automator → *Application* → *Run
AppleScript*, save to `~/Applications`, then Dock → Options → **Assign To →
Desktop N** and add to Login Items. macOS owns geometry and Spaces; tmux owns
persistence. Don't make tmux a window manager.

## Keys

Prefix is **`C-Space`** — free in fish, nvim and the Claude Code prompt box,
unlike `C-a` (beginning-of-line) and `C-b` (backward-char).

| Key | Does |
|---|---|
| `prefix` `\|` / `-` | split right / down, in the current pane's cwd |
| `prefix` `h j k l` | move between panes |
| `prefix` `H J K L` | resize (repeatable) |
| `prefix` `z` | zoom pane |
| `prefix` `c` | new window |
| `alt+1..5` | jump to window N (no prefix) |
| `prefix` `Tab` | last window |
| `prefix` `s` | session tree |
| `prefix` `C-Space` | last session |
| `prefix` `r` | reload config |

Session switching is deliberately understated: with two pinned workspaces, a
fast switch key just means the "work" window ends up showing "personal".

## Why these agent settings are not optional

`allow-passthrough on` — without it tmux swallows the OSC sequences Claude Code
uses for notifications and progress.

`extended-keys on` + `terminal-features xterm*:extkeys` — without them
**Shift+Enter is indistinguishable from Enter**, which breaks multi-line
prompting. This is the most common "Claude Code feels worse in tmux" complaint.

`terminal-features *:sync` — DEC mode 2026 synchronized output, which is what
stops Claude Code's flicker.

`bind o send-keys C-o` — Claude uses `C-o` for transcript expansion.

`monitor-bell on` + `bell-action any` — Claude rings the bell on stop and on
permission requests, and Ghostty surfaces it.

## Why the session died from the phone (and what stops it)

Grouped sessions **share windows**. In `tmux -CC` control mode, closing a native
tab sends `kill-window` — not detach — so it deletes that window on the Mac too.
If it was the last window, the session goes, and `exit-empty on` then takes the
whole server. Reproduced directly:

```
kill-session on the grouped session  -> base session survives   ✅
kill-window  on the grouped session  -> "no server running"     ❌
```

Mitigations in `tmux.conf`: `exit-empty off`, `destroy-unattached off`. But the
real fix is behavioural: **detach, don't close the tab.** Check whether rootshell
can be configured to detach on tab close.

`detach-on-destroy` stays **on** on purpose. Turning it off (as most sesh guides
suggest) would make closing the last window of `work` silently hop that Ghostty
window to `personal` — wrong for pinned workspaces.

## Plugins

Three, on purpose. `prefix + I` to install.

- **tpm** — the manager. The only `tmux-plugins/*` repo still actively developed.
- **tmux-sensible** — ~20 lines of boilerplate nobody disagrees with.
- **vim-tmux-navigator** — one set of `C-hjkl` across nvim splits and tmux panes.

Deliberately absent: **tmux-yank** (last release 2018; `set-clipboard on` covers
OSC 52 natively now) and **resurrect/continuum** (for two known sessions, a
LaunchAgent is more reliable — see below).

### Reach for these when the pain actually arrives

| Pain | Reach for |
|---|---|
| "which pane did the agent finish in?" | `monitor-bell` first; then [tmux-notify] or [marmonitor] for live agent state in the status bar |
| "reboot wiped my agent conversations" | resurrect + continuum + [tmux-assistant-resurrect] — read the caveats below |
| "lost scrollback after reboot" | `@resurrect-capture-pane-contents 'on'` (needs resurrect) |
| "12 sessions, can't remember the names" | [sesh] — genuinely the best tool here, but pointless with two |
| "I keep rebuilding the same layout" | `smug` (single Go binary) or a `sesh.toml` |
| "splitting/resizing keys are awkward" | tmux-pain-control |

[tmux-notify]: https://github.com/claude-contrib/claude-extensions/blob/main/plugins/tmux-notify/README.md
[marmonitor]: https://github.com/mjjo16/marmonitor
[tmux-assistant-resurrect]: https://github.com/timvw/tmux-assistant-resurrect
[sesh]: https://github.com/joshmedeski/sesh

**Do not put `claude` in `@resurrect-processes`.** It would relaunch a *fresh*
agent with no conversation — worse than an empty shell, because it looks
restored. `tmux-assistant-resurrect` is the purpose-built answer, but note: it
installs a `SessionStart` hook into `~/.claude/settings.json` and re-launches
agents with `--dangerously-skip-permissions`. Read it before installing. Its own
docs concede in-flight tool calls are lost regardless, and that env capture is
degraded on macOS (no `/proc`).

Also: `tmux-plugins/*` has been frozen since 2024. Nothing is broken — they're
short shell scripts against a stable API — but "maintained" in 2026 means sesh,
tmuxp, smug, tmuxinator.

## Anti-patterns

1. **Nested tmux.** If you tell an agent to run `tmux`, it's already inside
   `$TMUX` — make it use `tmux -t <target>` rather than starting a server.
2. **tmux as a window manager.** Geometry and Spaces belong to macOS.
3. **Unnamed sessions.** Always `new-session -A -s <name>`.
4. **Huge configs.** Add one plugin at a time, when something hurts.

## Agent-addressable panes

Worth adding to `CLAUDE.md` once you run several agents: *"tmux session `work`,
panes addressed `work:<window>.<pane>`."* Agents can then
`tmux capture-pane -p -t work:3.1` and tail a sibling pane deterministically.
