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
tmux-connect                 # gum menu over every session + recent directory
tmux-connect personal        # attach here, or switch session if already in tmux
tmux-connect -w work         # open a new Ghostty window pinned to it
```

With no argument it's a landing page: [sesh] lists live tmux sessions and
zoxide directories, [gum] renders the menu, and `sesh connect` decides
attach-vs-switch based on `$TMUX`. Icons distinguish a live session from a
directory; `-d` hides duplicates so a directory that already has a session
appears once.

gum's colours are ANSI numbers, never hex — same rule as the status bar, so the
menu tracks latte/mocha with the terminal instead of being pinned to one.

[sesh]: https://github.com/joshmedeski/sesh
[gum]: https://github.com/charmbracelet/gum

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
| `prefix` `t` | new window (`c` also works) |
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
- **tmux** uses **ANSI 0-15 and `default`** for everything *semantic* — never
  256-palette indices. Terminals theme 0-15 themselves, so the glyphs simply
  inherit whatever palette the *client* has.

That rule is what makes this work everywhere a handler couldn't:

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

### Where the rule had to bend, and what it cost

The **pill surface** is the exception, published as hex by `bin/theme-sync.sh`.
ANSI has sixteen *foreground* colours and no surface — no "one step off the
background" shade — and the slots that resemble one sit at opposite ends of the
ramp in the two flavours:

|  | canvas | `colour0` | `colour7` | `colour8` |
|---|---|---|---|---|
| latte | `#eff1f5` | `#5c5f77` | `#acb0be` | `#6c6f85` |
| mocha | `#1e1e2e` | `#45475a` | `#a6adc8` | `#585b70` |

In latte the surfaces are the high indices, in mocha the low ones, so no index
reads as a surface in both. Filling anything therefore needs real hex, and once
filled, the dim text does too — `colour8` *is* a surface shade in mocha and
falls to 1.88 against it.

**The cost is real and worth knowing.** These are session options, one value for
every client attached to that session, so a hex surface can only match *one*
client. When the Mac and the phone share a session, the pills follow the Mac's
appearance on both. The glyphs stayed ANSI and still track per-client, so the
failure is a mismatched fill, not unreadable text. Pin `@theme_flavour` to
`latte` or `mocha` to override detection.

This is the trade that was refused for the *rest* of the config, and it is
refused again for pane borders, which stay ANSI for the same reason.

### The bar's shape

Three filled pills — sessions, windows, modeline — floating on a **transparent**
bar. The empty canvas between them is the separator; nothing is drawn there. A
fill behind everything would put the three groups back on one slab.

The outer two are flush to the screen edge: no cap on the screen-facing side, so
their edge cells carry the pill background and ghostty's `window-padding-color
= extend` samples it and paints the 2pt padding to match. Only the middle pill
is capped both sides and actually floats. Caps are Nerd Font `U+E0B6`/`U+E0B4`
(`@pill_cap_l` / `@pill_cap_r`); swap them for `▐` and `▌` if a client's font
lacks the private-use range — rootshell on the phone is the likely one.

The selected session is a **teal chip** with slanted edges. Teal cannot carry an
accent as text in latte — 2.43 on the pill, 3.31 even on the bare canvas —
because every latte accent except blue, red and mauve sits under 3.0. They are
tuned for text on base, not on a surface. As a fill the same teal reads 3.31
with canvas text on it, and the filled shape does the work the hue could not.

Every boundary between two sessions carries **exactly one** separator, and each
entry draws only the one on its left:

| Case | Glyph | Meaning |
|---|---|---|
| no previous session | nothing | nothing sits to its left |
| previous is the chip | `U+E0BA` | the chip's closing edge |
| this one is the chip | `U+E0BC` | the chip's opening edge |
| anything else | `U+E0BB` | the thin divider |

Four things that bite when editing this:

- **`#[push-default]` is load-bearing.** Every entry ends with `#[default]` to
  drop styling from a name. Without a pushed default that resets to the bar's
  transparent background and punches a canvas hole after each entry.
- **`push-default` redefines what `default` means**, so `fg=default` inside a
  pill resolves to the pill's dim foreground, not the terminal's. That is why
  `@style_win_sel` and `@glyph_idle_fg` name `@bar_text` explicitly instead.
- **A style directive cannot colour a space that precedes it.** `@pill_close`
  emits `#[default]` before its padding space for exactly this reason. Putting
  the space first left it on whatever style was current, which stayed hidden
  until a selected session landed last and the space came out teal.
- **A comma inside a `#{?...}` arm ends that arm.** Any style used inside a
  conditional lives in its own option and arrives as a single `#{E:...}` unit.
  Inlining one renders the whole loop empty with no error.

`bin/session-seps.sh` publishes `@sess_prev` and `@sess_next`, because `#{S:}`
cannot see its own previous iteration. Those are facts about the session list
and name no client, so two ghostty windows on one context cannot disagree. The
comparison against `#{client_session}` happens in the format, once per client.
Two ordering traps live here: `#{S:}` walks sessions in **creation** order while
`list-sessions` sorts by name, and a tab is IFS whitespace, so a tab-delimited
`read` collapses an empty field and swaps the first entry's two neighbours.

A half-block stretch row (a second status line painting bar colour across its
top edge, to fake a 1.5-row bar) was built and removed. It worked, but it cost a
whole row of terminal to paint half of one, and the pills separate the groups
without spending any height at all.

### Glyph overshoot

Nerd Fonts draws every **thick** powerline glyph past the edges of its cell, so
two abutting segments never show a hairline seam. Only the ink overshoots.
Measured against a 1000-unit em, where the cell box is `-300 .. 1020`:

| Glyph | Extent | Width | Fits |
|---|---|---|---|
| `ple-forwardslash_separator` | `-300 .. 1020` | 599 | yes |
| `ple-upper_left_triangle` | `-307 .. 1027` | 629 | no |
| `ple-lower_right_triangle` | `-307 .. 1027` | 629 | no |
| `ple-left_half_circle_thick` | `-306 .. 1026` | 636 | no |

Seven units round up to a whole pixel of fringe above and below the pill. No
solid glyph in the font fits the cell, so the fix is to choose **which half is
ink**. `ple-upper_left_triangle` and `ple-lower_right_triangle` are the two
halves of one `/` diagonal and draw the same picture with the colours swapped,
so the closing edge uses the lower-right variant to keep the pill grey in the
ink. Pill grey fringing onto the canvas measures 1.37 and vanishes; the teal it
replaced measured 3.31 and showed as a spike.

The pill caps still fringe. Their ink is the pill grey, so it reads as the pill
being a fraction taller at its two rounded ends.

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

## Agent markers

Five states, rolled up from every pane onto its window and its session by
`claude/bin/tmux-agent-rollup.sh`.

| Glyph | Codepoint | State | Meaning | Colour |
|---|---|---|---|---|
| question in circle | `U+F059` | `blocked` | waiting on a permission decision or a question | `colour3` |
| bang in triangle | `U+F071` | `error` | the turn ended in failure | `colour1` |
| tick in circle | `U+F058` | `finished` | completed, not yet seen | `colour2` |
| tapered ring | `U+F110` | `working` | a turn is running | `colour4` |
| asterisk | `U+F069` | `idle` | a chat is open, nothing is happening | `@bar_text` |

Priority when a window or session rolls up several panes: `blocked` > `error` >
`finished` > `working` > `idle`. **An empty phase is the only thing that means
"no agent here"**, so a plain shell never reads as an idle agent. Any phase that
is neither empty nor `working` displays as `idle`.

`finished` and `error` fall back to `idle` after ten seconds of genuine
attention, measured by `tmux/bin/agent-ack.sh`. `blocked` never clears that way:
seeing a blocked agent does not unblock it. The marker disappears entirely when
the last agent in that window or session ends, because `SessionEnd` clears the
phase.

On the teal chip every glyph drops its hue and takes the chip's text colour.
The latte accents collapse against teal — yellow 1.43, red 1.45, green 1.12,
blue 1.31, against canvas at 3.31 — so the state has to read from the shape
there. That is why the five markers are distinct outlines and not coloured dots.

Two glyph families are unavailable. Font Awesome's v5 additions are absent from
JetBrainsMono Nerd Font, so robot `U+F544` and brain `U+F5DC` both miss. The
asterisks Claude Code uses for its own spinner (`U+2731`, `U+273B`, `U+273D`)
miss as well, and would fall to macOS substitution at an unpredictable cell
width.

## Agent-addressable panes

Worth adding to `CLAUDE.md` once you run several agents: *"tmux session `work`,
panes addressed `work:<window>.<pane>`."* Agents can then
`tmux capture-pane -p -t work:3.1` and tail a sibling pane deterministically.

## Leftover work

Next session is the status/mode line — readability and looks. Everything below
is open, roughly in priority order.

### Known rough edges

- **Status bar aesthetics** — mostly done; see "The bar's shape" above. Still
  unaddressed: the tier breakpoints (160/120/80), picked from measurement
  rather than taste, and the wide/medium branches in `status-tier.sh` now agree
  exactly, so one of them is arguably redundant.
- **Latte yellow on the pill.** The blocked marker reads 1.70 against surface0,
  down from 2.31 on the bare canvas. It is the weakest glyph in the set and the
  one that matters most. Fixing it properly means making the glyph colours
  theme-aware too, which gives up the ANSI tracking — or picking a different
  hue for `blocked` in latte only.
- **Cap glyphs are private-use codepoints.** They render on the Mac, untested
  in rootshell. If they show as tofu, set `@pill_cap_l`/`@pill_cap_r` to `▐`
  and `▌`.
- **A killed agent leaves its phase behind.** `SessionEnd` clears the phase, so
  a normal exit is clean, but a `SIGKILL` is not. The pane then shows the idle
  asterisk until the pane itself closes, which the `pane-exited` and
  `pane-died` hooks do catch.
- **Theme detection is polled, not pushed.** Ghostty swaps its palette without
  telling tmux, so `theme-sync.sh` runs on attach and on focus-in. Toggling
  appearance while the terminal is focused leaves the bar on the old flavour
  until you focus away and back.
- **`#()` caching lag.** The modeline re-runs on `status-interval` (15s), so
  after a resize the right-hand side keeps the old tier's content for up to
  15s. Lower the interval or accept it.
- **lazygit window names** read `lg ~/P/P/trellis`. The title is not a path by
  our test (it starts with `lg `), so it wins over the basename. Tightening the
  path test to catch `<word> ~/...` would fix it.
- **Relative window paths** (`a/b/c` instead of the basename) need naming
  driven from a hook — `automatic-rename-format` runs with no session bound, so
  `#{session_path}` and session-scoped `@root` are both empty there. `@root` is
  already set per session by `tmux-connect` for exactly this.

### Not started

- **Role-based responsive reflow.** `break-pane`/`join-pane` preserve the
  running process (verified), so a 5-pane layout can become 2 windows on a
  laptop live. Needs a declarative per-project file — tmuxp is the chosen tool,
  nothing written yet.
- **Per-project declarative layouts** (tmuxp), globally gitignored.
- **Deploying the status bar to claw.** `server/tmux.conf` does not source
  `status.conf`, so the agent markers and modeline are laptop-only.
- **Attention state on the phone.** Untested whether the markers read well in
  rootshell.

### Decided, deliberately not done

- **Session isolation by socket / `TMUX_TMPDIR`.** Rejected: rootshell's
  session discovery runs as its own SSH exec channel and always resolves to the
  default socket, so isolation would blind the phone's picker. Prefixes are a
  convention, not a wall, and that was the accepted trade.
- **Restoring live agents** (tmux-resurrect et al). Conversation history can be
  restored via `claude --resume`; a running agent cannot. Not worth the moving
  parts yet.
- **Ghostty 1.4 native `tmux -CC`.** Not close — tracking issue has no
  assignee, the architecture PR was auto-closed, contributor branch last moved
  in April. Do not plan around it.
