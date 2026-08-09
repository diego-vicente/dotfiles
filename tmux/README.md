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

```fish
tmux-connect personal        # attach here, or switch session if already in tmux
tmux-connect work
tmux-connect -w work         # open a new Ghostty window pinned to it
```

Defined in `fish/functions/dvicente/tmux-connect.fish`, with completions.
Idempotent (`new-session -A`), so re-running attaches instead of forking a
duplicate. The session is always created detached first, so it exists even if
the GUI step fails and the phone can attach with no Ghostty window ever open.

`-w` uses Ghostty 1.3's AppleScript API — `ghostty +new-window` is GTK/Linux
only and is not planned for the macOS CLI.

macOS owns window geometry and Spaces; tmux owns persistence. Don't make tmux a
window manager.

## Keys

Two leaders, one per device:

| Device | Press | Byte | tmux slot |
|---|---|---|---|
| Mac (Ghostty) | `cmd+;` | `0x1c` | `prefix` = `C-\` |
| iPhone (rootshell) | `Ctrl` then `b` | `0x02` | `prefix2` = `C-b` |

macOS never transmits Cmd to the terminal, so `cmd+;` cannot be a tmux binding
at all — Ghostty catches the chord and injects the byte. Quick terminal moved
to `cmd+'` to free it.

`C-b` exists for the phone: rootshell's on-screen keys are a fixed set and its
keybind config isn't reachable on iPhone, so the prefix has to be something the
toolbar can already type. It's also tmux's stock prefix, so every doc applies
unmodified. Cost: `C-b` (backward-char) is gone in fish everywhere.

**Not `C-Space`.** That's NUL (`0x00`) — iOS swallows it as the system
input-language switcher ([rootshell #227](https://github.com/kitknox/rootshell/issues/227)),
and it's the one byte with known delivery flakiness inside a `text:` action.

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
| `prefix` `C-\` | last session (i.e. `cmd+;` twice) |
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

## Appearance (light/dark)

**No `appearance-sync` handler, on purpose.** Both layers switch on their own:

- **Ghostty** does it natively: `theme = light:catppuccin-latte.conf,dark:catppuccin-mocha.conf`.
  It re-reads on the macOS appearance toggle and repaints live.
- **tmux** uses **ANSI 0-15 and `default` only** — never 256-palette indices,
  never hex. Terminals theme 0-15 themselves, so the bar simply inherits
  whatever palette the *client* has.

That second rule is what makes this work everywhere a handler couldn't:

| Where | How it follows |
|---|---|
| Ghostty on the Mac | Ghostty repaints, tmux inherits |
| SSH into claw | server has no appearance of its own; it inherits the client's |
| rootshell on the phone | rootshell's own day/night theme, tmux inherits |

A handler would have had to know the appearance of a *remote* client, which is
not knowable from a headless box. Inheriting is the only correct answer.

Latte and mocha define completely different ANSI 0-15 palettes, so this really
does track — it isn't a fudge.

The laptop accents `colour4` (blue); claw accents `colour1` (red). Both stay
theme-relative, so they're distinguishable without being fixed colours.

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
